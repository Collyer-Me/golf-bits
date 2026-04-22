import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';
import '../models/course_catalog_models.dart';

/// Hybrid catalog: Edge Functions when deployed, PostgREST fallback, offline seeds.
abstract final class CourseCatalogRepository {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Fire-and-forget telemetry (RLS: own rows only).
  static Future<void> logTelemetry(String kind, Map<String, dynamic> payload) async {
    if (!SupabaseEnv.isConfigured) return;
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _client.from('course_data_telemetry').insert({
        'user_id': uid,
        'kind': kind,
        'payload': payload,
      });
    } catch (_) {}
  }

  static Future<List<CourseSearchHit>> searchCourses({
    String query = '',
    bool includeRemote = false,
  }) async {
    if (!SupabaseEnv.isConfigured || _client.auth.currentUser == null) {
      return _localFilter(query);
    }

    try {
      final res = await _client.functions.invoke(
        'search-courses',
        body: {
          'query': query,
          'includeRemote': includeRemote,
          'limit': 25,
        },
      );
      final data = res.data;
      if (data is! Map) {
        await logTelemetry('provider_error', {'stage': 'search', 'reason': 'bad_response_shape'});
        return await _searchDirect(query);
      }
      if (data['error'] != null) {
        await logTelemetry('provider_error', {'stage': 'search', 'message': data['error'].toString()});
        return await _searchDirect(query);
      }
      final list = data['courses'] as List<dynamic>? ?? const [];
      final hits = list.map((e) => CourseSearchHit.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      if (hits.isEmpty && query.trim().isEmpty) {
        return await _searchDirect(query);
      }
      if (hits.isEmpty && query.trim().isNotEmpty) {
        await logTelemetry('search_miss', {'query': query, 'source': 'edge'});
      }
      return hits;
    } catch (e) {
      await logTelemetry('provider_error', {'stage': 'search', 'message': e.toString()});
      return await _searchDirect(query);
    }
  }

  static Future<List<CourseSearchHit>> _searchDirect(String query) async {
    try {
      var q = _client
          .from('courses')
          .select(
            'id,name,subtitle,locality,region,country_code,coverage_level,latitude,longitude,street_line1',
          )
          .order('name')
          .limit(25);

      final t = query.trim();
      if (t.isNotEmpty) {
        final esc = t.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
        final pat = '%$esc%';
        q = q.or('name.ilike.$pat,subtitle.ilike.$pat,locality.ilike.$pat');
      }

      final rows = await q;
      final list = (rows as List<dynamic>)
          .map((row) => _searchHitFromCourseRow(Map<String, dynamic>.from(row as Map)))
          .toList();
      if (list.isEmpty && t.isEmpty) {
        return CourseSearchHit.offlineSeeds;
      }
      if (list.isEmpty && t.isNotEmpty) {
        await logTelemetry('search_miss', {'query': t, 'source': 'direct'});
      }
      return list;
    } catch (_) {
      return _localFilter(query);
    }
  }

  static CourseSearchHit _searchHitFromCourseRow(Map<String, dynamic> row) {
    return CourseSearchHit(
      id: row['id'] as String,
      name: row['name'] as String,
      subtitle: row['subtitle'] as String?,
      coverageLevel: row['coverage_level'] as String? ?? CourseCoverageLevel.geoOnly,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      address: CourseAddress(
        street: row['street_line1'] as String?,
        locality: row['locality'] as String?,
        region: row['region'] as String?,
        countryCode: row['country_code'] as String?,
      ),
    );
  }

  static List<CourseSearchHit> _localFilter(String query) {
    final t = query.trim().toLowerCase();
    if (t.isEmpty) return CourseSearchHit.offlineSeeds;
    return CourseSearchHit.offlineSeeds
        .where(
          (c) => c.name.toLowerCase().contains(t) || (c.subtitle ?? '').toLowerCase().contains(t),
        )
        .toList();
  }

  static Future<CourseDetailView?> getCourseDetail(String courseId) async {
    if (!SupabaseEnv.isConfigured || _client.auth.currentUser == null) {
      return _offlineDetail(courseId);
    }

    try {
      final res = await _client.functions.invoke(
        'get-course-detail',
        body: {'courseId': courseId},
      );
      final data = res.data;
      if (data is! Map) return await _getCourseDetailDirect(courseId);
      if (data['error'] != null) return await _getCourseDetailDirect(courseId);
      return CourseDetailView.fromDetailJson(Map<String, dynamic>.from(data));
    } catch (_) {
      return await _getCourseDetailDirect(courseId);
    }
  }

  static CourseDetailView? _offlineDetail(String courseId) {
    try {
      final hit = CourseSearchHit.offlineSeeds.firstWhere((c) => c.id == courseId);
      return CourseDetailView(
        id: hit.id,
        name: hit.name,
        subtitle: hit.subtitle,
        coverageLevel: hit.coverageLevel,
        latitude: hit.latitude,
        longitude: hit.longitude,
        address: hit.address,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<CourseDetailView?> _getCourseDetailDirect(String courseId) async {
    try {
      final row = await _client
          .from('courses')
          .select('''
            id, name, subtitle, locality, region, country_code, coverage_level, latitude, longitude, street_line1, source, external_ids,
            course_tees (
              id, sort_order, label, color_hint, course_rating, slope_rating, ratings_json,
              course_tee_holes ( hole_number, par, stroke_index, yardage_yds )
            )
          ''')
          .eq('id', courseId)
          .maybeSingle();

      if (row == null) {
        await logTelemetry('search_miss', {'courseId': courseId});
        return _offlineDetail(courseId);
      }

      return _detailFromSupabaseRow(Map<String, dynamic>.from(row));
    } catch (_) {
      return _offlineDetail(courseId);
    }
  }

  static CourseDetailView _detailFromSupabaseRow(Map<String, dynamic> row) {
    final teesRaw = (row['course_tees'] as List<dynamic>? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList()
      ..sort(
        (a, b) => ((a['sort_order'] as num?)?.toInt() ?? 0).compareTo((b['sort_order'] as num?)?.toInt() ?? 0),
      );

    final sortedTees = <CourseTeeOption>[
      for (final m in teesRaw) CourseTeeOption.fromJson(m),
    ];

    return CourseDetailView(
      id: row['id'] as String,
      name: row['name'] as String,
      subtitle: row['subtitle'] as String?,
      coverageLevel: row['coverage_level'] as String? ?? CourseCoverageLevel.geoOnly,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      source: row['source'] as String?,
      externalIds: Map<String, dynamic>.from(row['external_ids'] as Map? ?? const {}),
      address: CourseAddress(
        street: row['street_line1'] as String?,
        locality: row['locality'] as String?,
        region: row['region'] as String?,
        countryCode: row['country_code'] as String?,
      ),
      tees: sortedTees,
    );
  }

  /// Private manual row (`coverage_level = manual`, RLS insert).
  static Future<CourseSearchHit?> createManualPrivateCourse({
    required String name,
    String? subtitle,
  }) async {
    if (!SupabaseEnv.isConfigured) return null;
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    try {
      final sub = subtitle?.trim();
      final row = await _client
          .from('courses')
          .insert({
            'name': trimmed,
            'subtitle': (sub == null || sub.isEmpty) ? null : sub,
            'coverage_level': CourseCoverageLevel.manual,
            'source': 'user',
            'owner_user_id': uid,
            'visibility': 'private',
          })
          .select('id,name,subtitle,locality,region,country_code,coverage_level,latitude,longitude,street_line1')
          .single();

      await logTelemetry('manual_course', {'courseId': row['id'], 'name': trimmed});

      return _searchHitFromCourseRow(Map<String, dynamic>.from(row as Map));
    } catch (_) {
      await logTelemetry('provider_error', {'stage': 'create_manual_course'});
      return null;
    }
  }
}
