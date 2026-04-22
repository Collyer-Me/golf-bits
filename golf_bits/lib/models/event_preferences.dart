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

List<EventPreference> defaultEventPreferences() {
  return const [
    EventPreference(
      id: 'birdie',
      name: 'Birdie',
      description: 'Awarded for completing the hole in 1 under par.',
      defaultPoints: 1,
      enabled: true,
      points: 1,
      isCustom: false,
    ),
    EventPreference(
      id: 'eagle',
      name: 'Eagle',
      description: 'Awarded for completing the hole in 2 under par.',
      defaultPoints: 2,
      enabled: true,
      points: 2,
      isCustom: false,
    ),
    EventPreference(
      id: 'chip',
      name: 'Chip-in',
      description: 'Holed out from off the green.',
      defaultPoints: 2,
      enabled: true,
      points: 2,
      isCustom: false,
    ),
    EventPreference(
      id: 'greenie',
      name: 'Greenie',
      description: 'Hit the green in regulation and two-putt or better.',
      defaultPoints: 1,
      enabled: true,
      points: 1,
      isCustom: false,
    ),
    EventPreference(
      id: 'three',
      name: 'Three-putt',
      description: 'Three or more putts on the green.',
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
