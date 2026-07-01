import 'dart:convert';

import 'custom_event_draft.dart';

class EventPreference {
  const EventPreference({
    required this.id,
    required this.name,
    this.nickname,
    required this.description,
    required this.defaultPoints,
    required this.enabled,
    required this.points,
    required this.isCustom,
  });

  final String id;
  final String name;
  final String? nickname;
  final String description;
  final int defaultPoints;
  final bool enabled;
  final int points;
  final bool isCustom;
  String get displayLabel => (nickname != null && nickname!.trim().isNotEmpty) ? nickname!.trim() : name;

  EventPreference copyWith({
    String? id,
    String? name,
    String? nickname,
    String? description,
    int? defaultPoints,
    bool? enabled,
    int? points,
    bool? isCustom,
  }) {
    return EventPreference(
      id: id ?? this.id,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      description: description ?? this.description,
      defaultPoints: defaultPoints ?? this.defaultPoints,
      enabled: enabled ?? this.enabled,
      points: points ?? this.points,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  factory EventPreference.fromJson(Map<String, dynamic> json) {
    return EventPreference(
      id: (json['id'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      nickname: (json['nickname'] as String?)?.trim(),
      description: (json['description'] as String?)?.trim() ?? '',
      defaultPoints: (json['defaultPoints'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      points: (json['points'] as num?)?.toInt() ?? 0,
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'nickname': nickname,
        'description': description,
        'defaultPoints': defaultPoints,
        'enabled': enabled,
        'points': points,
        'isCustom': isCustom,
      };
}

/// Maps award-sheet / round-setup labels to Material icon keys.
String iconKeyForEventLabel(String name) {
  final n = name.toLowerCase();
  if (n.contains('birdie')) return 'sports_golf';
  if (n.contains('eagle')) return 'trending_up';
  if (n.contains('greenie') || n.contains('gir') || n.contains('green in')) {
    return 'gps_fixed';
  }
  if (n.contains('sand') || n.contains('bunker')) return 'beach_access';
  if (n.contains('bark') || n.contains('wood')) return 'park';
  if (n.contains('chip') || n.contains('chippie')) return 'flag_outlined';
  if (n.contains('prox') || n.contains('closest') || n.contains('pin')) {
    return 'my_location';
  }
  if (n.contains('drive') || n.contains('nicklaus') || n.contains('tiger')) {
    return 'straighten';
  }
  if (n.contains('putt') || n.contains('snake')) return 'radio_button_checked_outlined';
  if (n.contains('water') || n.contains(' ob') || n.startsWith('ob')) {
    return 'waves_outlined';
  }
  if (n.contains('double') || n.contains('bogey')) return 'trending_down';
  if (n.contains('three') || n.contains('hazard')) return 'remove_circle_outline';
  return 'star_outline';
}

/// Built-in bits catalog — Stick Golf “standard set” plus common variants.
///
/// [Greenie] is par-3 closest-to-pin (must make par+). [GIR] is the alternate
/// “green in regulation” meaning some groups use instead.
List<EventPreference> defaultEventPreferences() {
  return const [
    EventPreference(
      id: 'birdie',
      name: 'Birdie',
      description: 'Score exactly one under par on the hole.',
      defaultPoints: 1,
      enabled: true,
      points: 1,
      isCustom: false,
    ),
    EventPreference(
      id: 'eagle',
      name: 'Eagle',
      description: 'Score two or more under par on the hole.',
      defaultPoints: 2,
      enabled: true,
      points: 2,
      isCustom: false,
    ),
    EventPreference(
      id: 'greenie',
      name: 'Greenie',
      description:
          'On a par 3: closest tee shot to the pin (on the green) and make par or better.',
      defaultPoints: 1,
      enabled: true,
      points: 1,
      isCustom: false,
    ),
    EventPreference(
      id: 'sandie',
      name: 'Sandie',
      nickname: 'Sandy',
      description: 'Ball in a greenside bunker, then up-and-down for par or better.',
      defaultPoints: 1,
      enabled: true,
      points: 1,
      isCustom: false,
    ),
    EventPreference(
      id: 'barkie',
      name: 'Barkie',
      nickname: 'Woodie',
      description: 'Ball hits a tree during the hole and you still make par or better.',
      defaultPoints: 1,
      enabled: true,
      points: 1,
      isCustom: false,
    ),
    EventPreference(
      id: 'chip',
      name: 'Chip-in',
      nickname: 'Chippie',
      description: 'Hole out from off the green (not a fringe putt) for par or better.',
      defaultPoints: 1,
      enabled: true,
      points: 1,
      isCustom: false,
    ),
    EventPreference(
      id: 'prox',
      name: 'Closest to Pin',
      nickname: 'Prox',
      description: 'Closest approach shot to the hole (one winner per hole).',
      defaultPoints: 1,
      enabled: true,
      points: 1,
      isCustom: false,
    ),
    EventPreference(
      id: 'long_drive',
      name: 'Long Drive',
      nickname: 'Nicklaus',
      description: 'Longest tee shot on a par 4 or 5 (usually must finish in the fairway).',
      defaultPoints: 1,
      enabled: true,
      points: 1,
      isCustom: false,
    ),
    EventPreference(
      id: 'gir',
      name: 'GIR',
      nickname: 'Green in regulation',
      description: 'Reach the green in regulation strokes (alternate to par-3 Greenie).',
      defaultPoints: 1,
      enabled: false,
      points: 1,
      isCustom: false,
    ),
    EventPreference(
      id: 'three',
      name: 'Three-putt',
      nickname: 'Snake',
      description: 'Three or more putts once the ball is on the putting surface.',
      defaultPoints: -1,
      enabled: true,
      points: -1,
      isCustom: false,
    ),
    EventPreference(
      id: 'double_plus',
      name: 'Double bogey+',
      nickname: 'Double+',
      description: 'Score double bogey or worse on the hole.',
      defaultPoints: -1,
      enabled: true,
      points: -1,
      isCustom: false,
    ),
    EventPreference(
      id: 'water_ob',
      name: 'Water / OB',
      description: 'Ball in a water hazard or out of bounds during the hole.',
      defaultPoints: -1,
      enabled: true,
      points: -1,
      isCustom: false,
    ),
  ];
}

List<EventPreference> mergeWithDefaultBuiltIns(List<EventPreference> input) {
  final defaults = defaultEventPreferences();
  final byId = {for (final event in input) event.id: event};
  final resolved = <EventPreference>[];
  for (final builtIn in defaults) {
    final saved = byId[builtIn.id];
    if (saved == null) {
      resolved.add(builtIn);
    } else {
      resolved.add(
        builtIn.copyWith(
          enabled: saved.enabled,
          points: saved.points,
          nickname: saved.nickname,
        ),
      );
    }
  }
  for (final event in input.where((event) => event.isCustom)) {
    resolved.add(event);
  }
  return resolved;
}

List<EventPreference> decodeEventPreferencesJson(dynamic raw) {
  if (raw == null) return defaultEventPreferences();
  try {
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is! List<dynamic>) return defaultEventPreferences();
    final events = decoded
        .whereType<Map>()
        .map((row) => EventPreference.fromJson(Map<String, dynamic>.from(row)))
        .where((event) => event.id.isNotEmpty && event.name.isNotEmpty)
        .toList();
    if (events.isEmpty) return defaultEventPreferences();
    return mergeWithDefaultBuiltIns(events);
  } catch (_) {
    return defaultEventPreferences();
  }
}

List<Map<String, dynamic>> encodeEventPreferencesJson(List<EventPreference> events) {
  return events.map((event) => event.toJson()).toList();
}

EventPreference eventPreferenceFromCustomDraft(CustomEventDraft draft) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return EventPreference(
    id: 'c_$now',
    name: draft.name,
    description: draft.description,
    defaultPoints: draft.points,
    enabled: true,
    points: draft.points,
    isCustom: true,
  );
}
