// Repeatable provider tee_name → display label + filter metadata (GolfCourseAPI / USGA-style).

/// Parsed metadata from a provider `tee_name` (or legacy DB label).
class ParsedTeeMetadata {
  const ParsedTeeMetadata({
    required this.rawLabel,
    this.color,
    this.gender,
    this.isHistorical = false,
    this.isTemporary = false,
    this.isNineHoleHint = false,
  });

  final String rawLabel;
  final String? color;
  /// `men` or `women` when detected.
  final String? gender;
  final bool isHistorical;
  final bool isTemporary;
  final bool isNineHoleHint;

  /// Stable key for picking one tee per color/gender family.
  String get familyKey {
    final c = (color ?? rawLabel.trim().toLowerCase()).toLowerCase();
    final g = gender ?? '';
    return '$c|$g';
  }
}

/// Longest-first so "Terra-Cotta" wins over shorter substring matches.
const _knownColorTokens = <String>[
  'terra-cotta',
  'terra cotta',
  'championship',
  'burgundy',
  'maroon',
  'purple',
  'silver',
  'golden',
  'yellow',
  'orange',
  'bronze',
  'cream',
  'shark',
  'ozzie',
  'aussie',
  'royal',
  'combo',
  'lion',
  'black',
  'blue',
  'white',
  'green',
  'gold',
  'red',
];

final _historicalToken = RegExp(
  r'\b(?:NOV|JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|DEC)\d{2}\b',
  caseSensitive: false,
);
final _yearSuffix = RegExp(r'\b(19|20)\d{2}\b');
final _nineHoleHint = RegExp(r'\b(?:SP\s*)?9\s*holes?\b', caseSensitive: false);
final _numericCourseCode = RegExp(r'^\d{4,6}$');
final _ratingSystem = RegExp(r'^(USGA|GA|MGA|AGU)$', caseSensitive: false);

/// Parse provider-style or plain tee names into filter/display metadata.
ParsedTeeMetadata parseProviderTeeLabel(String rawLabel) {
  final raw = rawLabel.trim();
  if (raw.isEmpty) {
    return ParsedTeeMetadata(rawLabel: raw);
  }

  final lower = raw.toLowerCase();
  final isHistorical = _historicalToken.hasMatch(raw) ||
      (_yearSuffix.hasMatch(raw) && raw.contains(','));
  final isTemporary = lower.contains('temp');
  final isNineHoleHint = _nineHoleHint.hasMatch(raw);

  if (!raw.contains(',')) {
    final color = _matchColorToken(raw) ?? _titleCaseSingle(raw);
    return ParsedTeeMetadata(
      rawLabel: raw,
      color: color,
      isHistorical: isHistorical,
      isTemporary: isTemporary,
      isNineHoleHint: isNineHoleHint,
    );
  }

  final parts = raw.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  String? gender;
  String? color;

  for (final part in parts) {
    final pl = part.toLowerCase();
    if (_numericCourseCode.hasMatch(part) || _ratingSystem.hasMatch(part)) continue;
    if (pl == 'men' || pl == 'man' || pl == 'male' || pl == 'mens') {
      gender = 'men';
      continue;
    }
    if (pl == 'women' || pl == 'woman' || pl == 'female' || pl == 'ladies' || pl == 'womens') {
      gender = 'women';
      continue;
    }
    final matched = _matchColorToken(part);
    if (matched != null) {
      color ??= matched;
    }
  }

  color ??= _matchColorToken(raw);

  return ParsedTeeMetadata(
    rawLabel: raw,
    color: color,
    gender: gender,
    isHistorical: isHistorical,
    isTemporary: isTemporary,
    isNineHoleHint: isNineHoleHint,
  );
}

String? _matchColorToken(String text) {
  final lower = text.toLowerCase();
  for (final token in _knownColorTokens) {
    if (lower.contains(token)) {
      return _titleCaseToken(token);
    }
  }
  if (lower.contains('/')) {
    final names = <String>[];
    for (final seg in lower.split('/')) {
      final s = seg.trim();
      for (final token in _knownColorTokens) {
        if (s.contains(token)) {
          names.add(_titleCaseToken(token));
          break;
        }
      }
    }
    if (names.isNotEmpty) return names.join('/');
  }
  return null;
}

String _titleCaseToken(String token) {
  if (token.contains('-')) {
    return token.split('-').map(_titleCaseSingle).join('-');
  }
  if (token.contains(' ')) {
    return token.split(' ').map(_titleCaseSingle).join(' ');
  }
  return _titleCaseSingle(token);
}

String _titleCaseSingle(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1).toLowerCase();
}

/// User-facing primary label (yardage / ratings stay in subtitle).
String teeDisplayLabel(
  ParsedTeeMetadata meta, {
  required bool showGenderSuffix,
}) {
  final base = meta.color ?? _titleCaseSingle(meta.rawLabel.split(',').first.trim());
  if (showGenderSuffix && meta.gender != null) {
    final g = meta.gender == 'women' ? 'Women' : 'Men';
    return '$base ($g)';
  }
  return base;
}

/// Color hint for tee row styling (falls back to parsed color).
String? teeColorHintFromMetadata(ParsedTeeMetadata meta, String? existingHint) {
  if (meta.color != null) return meta.color;
  final h = existingHint?.trim();
  if (h != null && h.isNotEmpty) return h;
  return null;
}

int teeColorSortRank(String? color) {
  final c = (color ?? '').toLowerCase();
  const order = [
    'black',
    'championship',
    'blue',
    'white',
    'yellow',
    'red',
    'gold',
    'green',
    'silver',
    'burgundy',
    'orange',
    'purple',
    'cream',
    'bronze',
    'terra-cotta',
    'terra cotta',
  ];
  for (var i = 0; i < order.length; i++) {
    if (c.contains(order[i])) return i;
  }
  return 50;
}

/// Whether [candidate] should replace [incumbent] within the same family.
bool preferTeeCandidate({
  required bool incumbentHas18,
  required bool candidateHas18,
  required ParsedTeeMetadata incumbentMeta,
  required ParsedTeeMetadata candidateMeta,
  required int incumbentYardage,
  required int candidateYardage,
  required int incumbentHoleRows,
  required int candidateHoleRows,
}) {
  if (incumbentHas18 != candidateHas18) return candidateHas18;
  if (incumbentMeta.isHistorical != candidateMeta.isHistorical) {
    return !candidateMeta.isHistorical;
  }
  if (incumbentMeta.isTemporary != candidateMeta.isTemporary) {
    return !candidateMeta.isTemporary;
  }
  if (incumbentMeta.isNineHoleHint != candidateMeta.isNineHoleHint) {
    return !candidateMeta.isNineHoleHint;
  }
  if (incumbentYardage != candidateYardage) return candidateYardage > incumbentYardage;
  if (incumbentHoleRows != candidateHoleRows) return candidateHoleRows > incumbentHoleRows;
  return candidateMeta.rawLabel.length < incumbentMeta.rawLabel.length;
}

int compareTeeMetadataForDisplay(ParsedTeeMetadata a, ParsedTeeMetadata b) {
  final ga = a.gender == 'men' ? 0 : (a.gender == 'women' ? 1 : 2);
  final gb = b.gender == 'men' ? 0 : (b.gender == 'women' ? 1 : 2);
  if (ga != gb) return ga.compareTo(gb);
  return teeColorSortRank(a.color).compareTo(teeColorSortRank(b.color));
}

/// Same rules as [parseProviderTeeLabel] for Edge Function ingest (TypeScript port).
String normalizeProviderTeeLabelForStorage(String rawLabel) {
  final meta = parseProviderTeeLabel(rawLabel);
  return teeDisplayLabel(meta, showGenderSuffix: meta.gender != null);
}
