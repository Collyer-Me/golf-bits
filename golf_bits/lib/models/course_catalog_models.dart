/// Stable client models for course catalog search + detail (matches Edge Function JSON).

class CourseAddress {
  const CourseAddress({
    this.street,
    this.locality,
    this.region,
    this.countryCode,
  });

  final String? street;
  final String? locality;
  final String? region;
  final String? countryCode;

  String get displayLine {
    final parts = <String>[
      if (locality != null && locality!.trim().isNotEmpty) locality!.trim(),
      if (region != null && region!.trim().isNotEmpty) region!.trim(),
    ];
    return parts.join(', ');
  }

  factory CourseAddress.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const CourseAddress();
    return CourseAddress(
      street: j['street'] as String?,
      locality: j['locality'] as String?,
      region: j['region'] as String?,
      countryCode: j['countryCode'] as String?,
    );
  }
}

/// `coverage_level` from database / API contract.
abstract final class CourseCoverageLevel {
  static const String geoOnly = 'geo_only';
  static const String partialScorecard = 'partial_scorecard';
  static const String fullScorecard = 'full_scorecard';
  static const String manual = 'manual';
}

class CourseSearchHit {
  const CourseSearchHit({
    required this.id,
    required this.name,
    required this.coverageLevel,
    this.subtitle,
    this.latitude,
    this.longitude,
    this.address = const CourseAddress(),
  });

  final String id;
  final String name;
  final String? subtitle;
  final String coverageLevel;
  final double? latitude;
  final double? longitude;
  final CourseAddress address;

  String get listSubtitle {
    if (subtitle != null && subtitle!.trim().isNotEmpty) return subtitle!.trim();
    final a = address.displayLine;
    if (a.isNotEmpty) return a;
    return switch (coverageLevel) {
      CourseCoverageLevel.geoOnly => 'Location only — scorecard not loaded',
      CourseCoverageLevel.manual => 'Manual course',
      CourseCoverageLevel.partialScorecard => 'Partial scorecard',
      _ => '',
    };
  }

  factory CourseSearchHit.fromJson(Map<String, dynamic> j) {
    return CourseSearchHit(
      id: j['id'] as String,
      name: j['name'] as String,
      subtitle: j['subtitle'] as String?,
      coverageLevel: (j['coverageLevel'] ?? CourseCoverageLevel.geoOnly) as String,
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      address: CourseAddress.fromJson(j['address'] as Map<String, dynamic>?),
    );
  }

  /// Seed UUIDs (see `supabase/migrations/20260416240000_course_catalog.sql`) for offline / no-DB.
  static const List<CourseSearchHit> offlineSeeds = [
    CourseSearchHit(
      id: 'b1111111-1111-4111-8111-111111111101',
      name: 'Royal Melbourne Golf Club',
      subtitle: 'Black Rock, VIC',
      coverageLevel: CourseCoverageLevel.fullScorecard,
      latitude: -37.975,
      longitude: 145.02,
    ),
    CourseSearchHit(
      id: 'b1111111-1111-4111-8111-111111111102',
      name: 'Royal Sydney Golf Club',
      subtitle: 'Rose Bay, NSW',
      coverageLevel: CourseCoverageLevel.fullScorecard,
      latitude: -33.87,
      longitude: 151.265,
    ),
    CourseSearchHit(
      id: 'b1111111-1111-4111-8111-111111111103',
      name: 'Royal Queensland Golf Club',
      subtitle: 'Eagle Farm, QLD',
      coverageLevel: CourseCoverageLevel.fullScorecard,
      latitude: -27.425,
      longitude: 153.08,
    ),
  ];
}

/// One hole row for a specific tee (par / SI / yardage can differ by tee).
class CourseTeeHoleRow {
  const CourseTeeHoleRow({
    required this.holeNumber,
    required this.par,
    this.strokeIndex,
    this.yardageYds,
  });

  final int holeNumber;
  final int par;
  final int? strokeIndex;
  final int? yardageYds;

  factory CourseTeeHoleRow.fromJson(Map<String, dynamic> j) {
    return CourseTeeHoleRow.fromRowMap(j);
  }

  /// PostgREST (`snake_case`) or Edge (`camelCase`) row.
  factory CourseTeeHoleRow.fromRowMap(Map<String, dynamic> m) {
    final hn = m['holeNumber'] ?? m['hole_number'];
    final si = m['strokeIndex'] ?? m['stroke_index'];
    final yds = m['yardageYds'] ?? m['yardage_yds'];
    return CourseTeeHoleRow(
      holeNumber: (hn as num).toInt(),
      par: (m['par'] as num).toInt(),
      strokeIndex: si == null ? null : (si as num).toInt(),
      yardageYds: yds == null ? null : (yds as num).toInt(),
    );
  }
}

class CourseTeeOption {
  const CourseTeeOption({
    required this.id,
    required this.label,
    this.colorHint,
    this.courseRating,
    this.slopeRating,
    this.ratings = const <String, dynamic>{},
    this.holes = const [],
  });

  final String id;
  final String label;
  final String? colorHint;
  final double? courseRating;
  final int? slopeRating;
  final Map<String, dynamic> ratings;
  final List<CourseTeeHoleRow> holes;

  factory CourseTeeOption.fromJson(Map<String, dynamic> j) {
    final holeRaw = j['holes'] as List<dynamic>? ?? j['course_tee_holes'] as List<dynamic>? ?? const [];
    final holeList = holeRaw
        .map((e) => CourseTeeHoleRow.fromRowMap(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.holeNumber.compareTo(b.holeNumber));
    return CourseTeeOption(
      id: j['id'] as String,
      label: j['label'] as String,
      colorHint: j['colorHint'] as String? ?? j['color_hint'] as String?,
      courseRating: ((j['courseRating'] ?? j['course_rating']) as num?)?.toDouble(),
      slopeRating: ((j['slopeRating'] ?? j['slope_rating']) as num?)?.toInt(),
      ratings: Map<String, dynamic>.from(
        (j['ratings'] ?? j['ratings_json']) as Map? ?? const {},
      ),
      holes: holeList,
    );
  }
}

class CourseDetailView {
  const CourseDetailView({
    required this.id,
    required this.name,
    required this.coverageLevel,
    this.subtitle,
    this.latitude,
    this.longitude,
    this.source,
    this.externalIds = const {},
    this.address = const CourseAddress(),
    this.tees = const [],
  });

  final String id;
  final String name;
  final String? subtitle;
  final String coverageLevel;
  final double? latitude;
  final double? longitude;
  final String? source;
  final Map<String, dynamic> externalIds;
  final CourseAddress address;
  final List<CourseTeeOption> tees;

  bool get hasTeeMatrix => tees.any((t) => t.holes.isNotEmpty);

  /// Par map for syncing a round row, using the selected tee (or first tee).
  Map<String, int>? holeParsForTeeSync(String? courseTeeId) {
    if (tees.isEmpty) return null;
    CourseTeeOption? tee;
    if (courseTeeId != null) {
      for (final t in tees) {
        if (t.id == courseTeeId) {
          tee = t;
          break;
        }
      }
    }
    tee ??= tees.first;
    if (tee.holes.isEmpty) return null;
    return {for (final h in tee.holes) '${h.holeNumber}': h.par};
  }

  factory CourseDetailView.fromDetailJson(Map<String, dynamic> j) {
    final c = j['course'] as Map<String, dynamic>? ?? const {};
    final teeList = (j['tees'] as List<dynamic>? ?? const [])
        .map((e) => CourseTeeOption.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return CourseDetailView(
      id: c['id'] as String,
      name: c['name'] as String,
      subtitle: c['subtitle'] as String?,
      coverageLevel: (c['coverageLevel'] ?? CourseCoverageLevel.geoOnly) as String,
      latitude: (c['latitude'] as num?)?.toDouble(),
      longitude: (c['longitude'] as num?)?.toDouble(),
      source: c['source'] as String?,
      externalIds: Map<String, dynamic>.from(c['externalIds'] as Map? ?? const {}),
      address: CourseAddress.fromJson(c['address'] as Map<String, dynamic>?),
      tees: teeList,
    );
  }
}
