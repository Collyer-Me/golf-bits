// Stable client models for course catalog search + detail (matches Edge Function JSON).

import 'tee_label_normalize.dart';

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

  static String coverageTag(String level) {
    return switch (level) {
      CourseCoverageLevel.fullScorecard => 'Full scorecard',
      CourseCoverageLevel.partialScorecard => 'Partial scorecard',
      CourseCoverageLevel.geoOnly => 'Location only',
      CourseCoverageLevel.manual => 'Manual entry',
      _ => '',
    };
  }

  CourseSearchHit copyWith({
    String? subtitle,
    String? coverageLevel,
    double? latitude,
    double? longitude,
    CourseAddress? address,
  }) {
    return CourseSearchHit(
      id: id,
      name: name,
      subtitle: subtitle ?? this.subtitle,
      coverageLevel: coverageLevel ?? this.coverageLevel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
    );
  }

  String get listSubtitle {
    final loc = subtitle != null && subtitle!.trim().isNotEmpty ? subtitle!.trim() : address.displayLine;
    final tag = coverageTag(coverageLevel);
    if (loc.isEmpty) return tag.isEmpty ? '' : tag;
    if (tag.isEmpty) return loc;
    return '$loc · $tag';
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
      subtitle: 'Black Rock, VIC (offline demo)',
      coverageLevel: CourseCoverageLevel.partialScorecard,
      latitude: -37.975,
      longitude: 145.02,
    ),
    CourseSearchHit(
      id: 'b1111111-1111-4111-8111-111111111102',
      name: 'Royal Sydney Golf Club',
      subtitle: 'Rose Bay, NSW (offline demo)',
      coverageLevel: CourseCoverageLevel.partialScorecard,
      latitude: -33.87,
      longitude: 151.265,
    ),
    CourseSearchHit(
      id: 'b1111111-1111-4111-8111-111111111103',
      name: 'Royal Queensland Golf Club',
      subtitle: 'Eagle Farm, QLD (offline demo)',
      coverageLevel: CourseCoverageLevel.partialScorecard,
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
    this.displayLabelOverride,
    this.colorHint,
    this.courseRating,
    this.slopeRating,
    this.ratings = const <String, dynamic>{},
    this.holes = const [],
  });

  final String id;
  final String label;
  final String? displayLabelOverride;
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

  /// Sum of hole yardages where present (tie-break / display).
  int get totalYardageYds {
    var sum = 0;
    for (final h in holes) {
      final y = h.yardageYds;
      if (y != null) sum += y;
    }
    return sum;
  }

  /// At least 18 distinct hole indices (handles sparse provider data better than holes.length alone).
  bool get hasEighteenDistinctHoles =>
      {...holes.map((h) => h.holeNumber)}.length >= 18;

  /// Normalized label for UI (falls back to [label]).
  String get displayLabel => displayLabelOverride ?? label;

  CourseTeeOption copyWith({
    String? label,
    String? displayLabelOverride,
    String? colorHint,
    List<CourseTeeHoleRow>? holes,
  }) {
    return CourseTeeOption(
      id: id,
      label: label ?? this.label,
      displayLabelOverride: displayLabelOverride ?? this.displayLabelOverride,
      colorHint: colorHint ?? this.colorHint,
      courseRating: courseRating,
      slopeRating: slopeRating,
      ratings: ratings,
      holes: holes ?? this.holes,
    );
  }
}

/// Provider-aware tee list: drop empty rows, one tee per color/gender family, friendly labels.
List<CourseTeeOption> prepareTeesForDisplay(List<CourseTeeOption> raw) {
  final nonempty = raw.where((t) => t.holes.isNotEmpty).toList();
  if (nonempty.isEmpty) return const [];

  final metas = nonempty.map((t) => parseProviderTeeLabel(t.label)).toList();
  final byFamily = <String, ({CourseTeeOption tee, ParsedTeeMetadata meta})>{};

  for (var i = 0; i < nonempty.length; i++) {
    final tee = nonempty[i];
    final meta = metas[i];
    final prev = byFamily[meta.familyKey];
    if (prev == null) {
      byFamily[meta.familyKey] = (tee: tee, meta: meta);
      continue;
    }
    if (preferTeeCandidate(
      incumbentHas18: prev.tee.hasEighteenDistinctHoles,
      candidateHas18: tee.hasEighteenDistinctHoles,
      incumbentMeta: prev.meta,
      candidateMeta: meta,
      incumbentYardage: prev.tee.totalYardageYds,
      candidateYardage: tee.totalYardageYds,
      incumbentHoleRows: prev.tee.holes.length,
      candidateHoleRows: tee.holes.length,
    )) {
      byFamily[meta.familyKey] = (tee: tee, meta: meta);
    }
  }

  final gendersInList = byFamily.values
      .map((e) => e.meta.gender)
      .whereType<String>()
      .toSet();
  final showGenderSuffix = gendersInList.length > 1;

  final list = byFamily.values
      .map(
        (e) => e.tee.copyWith(
          displayLabelOverride: teeDisplayLabel(e.meta, showGenderSuffix: showGenderSuffix),
          colorHint: teeColorHintFromMetadata(e.meta, e.tee.colorHint),
        ),
      )
      .toList()
    ..sort((a, b) {
      final ma = parseProviderTeeLabel(a.label);
      final mb = parseProviderTeeLabel(b.label);
      final a18 = a.hasEighteenDistinctHoles;
      final b18 = b.hasEighteenDistinctHoles;
      if (a18 != b18) return a18 ? -1 : 1;
      final metaCmp = compareTeeMetadataForDisplay(ma, mb);
      if (metaCmp != 0) return metaCmp;
      final yd = b.totalYardageYds.compareTo(a.totalYardageYds);
      if (yd != 0) return yd;
      return a.displayLabel.toLowerCase().compareTo(b.displayLabel.toLowerCase());
    });

  return list;
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

  /// Yardage map for the selected tee (`"7"` → 412), omitting holes without data.
  Map<String, int>? holeYardagesForTeeSync(String? courseTeeId) {
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
    final out = <String, int>{};
    for (final h in tee.holes) {
      final yds = h.yardageYds;
      if (yds != null) out['${h.holeNumber}'] = yds;
    }
    return out.isEmpty ? null : out;
  }

  /// Stroke index map for the selected tee (`"7"` → 5).
  Map<String, int>? holeStrokeIndexesForTeeSync(String? courseTeeId) {
    if (tees.isEmpty) return null;

    Map<String, int> fromTee(CourseTeeOption tee) {
      final out = <String, int>{};
      for (final h in tee.holes) {
        final si = h.strokeIndex;
        if (si != null) out['${h.holeNumber}'] = si;
      }
      return out;
    }

    CourseTeeOption? selected;
    if (courseTeeId != null) {
      for (final t in tees) {
        if (t.id == courseTeeId) {
          selected = t;
          break;
        }
      }
    }
    selected ??= tees.first;

    final selectedMap = selected.holes.isEmpty ? <String, int>{} : fromTee(selected);
    if (selectedMap.length >= 9) return selectedMap.isEmpty ? null : selectedMap;

    // Prefer the tee with the most SI rows when the selected tee is sparse.
    var best = selectedMap;
    for (final tee in tees) {
      if (tee.holes.isEmpty) continue;
      final candidate = fromTee(tee);
      if (candidate.length > best.length) best = candidate;
    }
    return best.isEmpty ? null : best;
  }

  factory CourseDetailView.fromDetailJson(Map<String, dynamic> j) {
    final c = j['course'] as Map<String, dynamic>? ?? const {};
    final teeList = prepareTeesForDisplay(
      (j['tees'] as List<dynamic>? ?? const [])
          .map((e) => CourseTeeOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
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

/// Reasons to show next to selected course ([RoundSetupScreen]).
class CourseReadinessSummary {
  const CourseReadinessSummary({
    this.detailUnavailable = false,
    this.requiresGenericTees = false,
    this.expectsScorecardButNoTees = false,
    this.manualOrGeoNote,
  });

  final bool detailUnavailable;
  final bool requiresGenericTees;
  final bool expectsScorecardButNoTees;
  final String? manualOrGeoNote;

  static CourseReadinessSummary fromHitAndDetail({
    required CourseSearchHit hit,
    required CourseDetailView? detail,
    required bool detailFetchSucceeded,
  }) {
    if (!detailFetchSucceeded || detail == null) {
      return const CourseReadinessSummary(detailUnavailable: true);
    }
    final geo = hit.coverageLevel == CourseCoverageLevel.geoOnly;
    final manual = hit.coverageLevel == CourseCoverageLevel.manual;
    if (manual || geo) {
      if (detail.hasTeeMatrix) return const CourseReadinessSummary();
      return CourseReadinessSummary(
        requiresGenericTees: true,
        manualOrGeoNote: manual
            ? 'Manual entry — hole-by-hole scoring uses generic tees until scorecard data exists.'
            : 'Location-only listing — tee boxes stay generic until a scorecard loads for this course.',
      );
    }

    final partialOrFull =
        hit.coverageLevel == CourseCoverageLevel.partialScorecard ||
            hit.coverageLevel == CourseCoverageLevel.fullScorecard;
    final noUsableTees = !detail.hasTeeMatrix;
    if (partialOrFull && noUsableTees) {
      return const CourseReadinessSummary(
        expectsScorecardButNoTees: true,
        requiresGenericTees: true,
      );
    }

    return const CourseReadinessSummary();
  }
}
