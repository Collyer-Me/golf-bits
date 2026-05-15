import 'round_session_args.dart';

/// Gross stroke scorecard scope for a round (Bits gameplay is unchanged).
enum StrokeTrackingMode {
  off,
  self,
  all;

  static StrokeTrackingMode fromDb(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'self' => StrokeTrackingMode.self,
      'all' => StrokeTrackingMode.all,
      _ => StrokeTrackingMode.off,
    };
  }

  String toDb() => name;

  String get setupLabel => switch (this) {
        StrokeTrackingMode.off => 'Off',
        StrokeTrackingMode.self => 'Just you',
        StrokeTrackingMode.all => 'All players',
      };

  bool get tracksStrokes => this != StrokeTrackingMode.off;
}

/// Whether [participant] gets stroke entry UI for [mode].
bool strokeTracksParticipant({
  required StrokeTrackingMode mode,
  required RoundParticipant participant,
}) {
  return switch (mode) {
    StrokeTrackingMode.off => false,
    StrokeTrackingMode.self => participant.isYou,
    StrokeTrackingMode.all => true,
  };
}

/// Parse `stroke_by_hole` from Supabase: participant_key → hole string → strokes.
Map<String, Map<int, int>> parseStrokeByHole(dynamic raw) {
  if (raw is! Map) return {};
  final out = <String, Map<int, int>>{};
  for (final entry in raw.entries) {
    final playerKey = entry.key.toString();
    final holesRaw = entry.value;
    if (holesRaw is! Map) continue;
    final holes = <int, int>{};
    for (final h in holesRaw.entries) {
      final holeNum = int.tryParse(h.key.toString());
      final strokes = (h.value as num?)?.toInt() ?? int.tryParse('${h.value}');
      if (holeNum != null && strokes != null && strokes > 0) {
        holes[holeNum] = strokes;
      }
    }
    if (holes.isNotEmpty) out[playerKey] = holes;
  }
  return out;
}

/// Serialize for JSONB storage.
Map<String, dynamic> strokeByHoleToJson(Map<String, Map<int, int>> data) {
  return {
    for (final e in data.entries)
      e.key: {for (final h in e.value.entries) '${h.key}': h.value},
  };
}

Map<String, int> parseGrossByPlayer(dynamic raw) {
  if (raw is! Map) return {};
  return raw.map(
    (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? int.tryParse('$v') ?? 0),
  );
}

/// Sum gross strokes for [playerKey] from per-hole map.
int computeGrossStrokes(Map<int, int> holes) {
  return holes.values.fold<int>(0, (s, n) => s + n);
}

/// Rebuild denormalized totals from nested stroke map.
Map<String, int> computeGrossByPlayer(Map<String, Map<int, int>> strokeByHole) {
  return {
    for (final e in strokeByHole.entries)
      if (e.value.isNotEmpty) e.key: computeGrossStrokes(e.value),
  };
}

/// Par for a hole from `hole_pars` snapshot (`"1"` → 4).
int? parForHole(Map<String, int> holePars, int hole) {
  return holePars['$hole'] ?? holePars[hole.toString()];
}

/// Course par total for holes in [holeOrder] when pars known.
int? courseParForHoles(Map<String, int> holePars, List<int> holeOrder) {
  var sum = 0;
  var any = false;
  for (final h in holeOrder) {
    final p = parForHole(holePars, h);
    if (p == null) return null;
    sum += p;
    any = true;
  }
  return any ? sum : null;
}

/// Label vs par: E, +1, −2, or raw count when par unknown.
String scoreToParLabel({required int strokes, int? par}) {
  if (par == null) return '$strokes';
  final diff = strokes - par;
  if (diff == 0) return 'E';
  if (diff > 0) return '+$diff';
  return '$diff';
}

/// Gross to par for a player across played holes (e.g. "38 (+2)").
String? grossToParLabel({
  required Map<int, int> holes,
  required Map<String, int> holePars,
  required List<int> holeOrder,
}) {
  if (holes.isEmpty) return null;
  var gross = 0;
  var parSum = 0;
  var hasPar = true;
  for (final h in holeOrder) {
    final s = holes[h];
    if (s == null) continue;
    gross += s;
    final p = parForHole(holePars, h);
    if (p == null) {
      hasPar = false;
      break;
    }
    parSum += p;
  }
  if (gross == 0) return null;
  return formatGrossWithToPar(
    gross: gross,
    holePars: holePars,
    holeOrder: holeOrder,
    playerHoles: holes,
  );
}

/// Cleaner gross to par for totals: "82 (+6)" or "38".
/// Gross line for a standings row when scorecard was tracked.
String? grossLabelForStanding({
  required StrokeTrackingMode mode,
  required Map<String, int> grossByPlayer,
  required Map<String, int> holePars,
  required List<int> holeOrder,
  required Map<String, Map<int, int>> strokeByHole,
  String? participantKey,
}) {
  if (!mode.tracksStrokes || participantKey == null) return null;
  final gross = grossByPlayer[participantKey];
  if (gross == null || gross <= 0) return null;
  final holes = strokeByHole[participantKey];
  if (holes == null || holes.isEmpty) return 'Gross $gross';
  return 'Gross ${formatGrossWithToPar(
    gross: gross,
    holePars: holePars,
    holeOrder: holeOrder,
    playerHoles: holes,
  )}';
}

String formatGrossWithToPar({
  required int gross,
  required Map<String, int> holePars,
  required List<int> holeOrder,
  required Map<int, int> playerHoles,
}) {
  var parSum = 0;
  var hasAllPars = true;
  for (final h in holeOrder) {
    if (!playerHoles.containsKey(h)) continue;
    final p = parForHole(holePars, h);
    if (p == null) {
      hasAllPars = false;
      break;
    }
    parSum += p;
  }
  if (!hasAllPars || parSum == 0) return '$gross';
  final diff = gross - parSum;
  if (diff == 0) return '$gross (E)';
  if (diff > 0) return '$gross (+$diff)';
  return '$gross ($diff)';
}
