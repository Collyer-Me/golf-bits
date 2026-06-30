import 'package:flutter/foundation.dart';

import 'round_session_args.dart';
import 'wolf_scoring.dart';

/// Which game formats run in a round.
enum RoundFormat {
  bits,
  wolf;

  static RoundFormat? fromDb(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'bits' => RoundFormat.bits,
      'wolf' => RoundFormat.wolf,
      _ => null,
    };
  }

  String toDb() => name;
}

List<RoundFormat> parseRoundFormats(dynamic raw) {
  if (raw is List) {
    return [
      for (final item in raw)
        if (RoundFormat.fromDb(item.toString()) case final f?) f,
    ];
  }
  if (raw is String && raw.contains('wolf')) {
    return raw.contains('bits') ? [RoundFormat.wolf, RoundFormat.bits] : [RoundFormat.wolf];
  }
  return const [RoundFormat.bits];
}

List<String> roundFormatsToDb(List<RoundFormat> formats) {
  return formats.map((f) => f.toDb()).toList();
}

bool roundHasWolf(List<RoundFormat> formats) => formats.contains(RoundFormat.wolf);

bool roundHasBits(List<RoundFormat> formats) => formats.contains(RoundFormat.bits);

@immutable
class RoundGameConfig {
  const RoundGameConfig({
    this.formats = const [RoundFormat.bits],
    this.scoringBasis = WolfScoringBasis.net,
    this.teeOrder = const [],
    this.handicaps = const {},
    this.wolfPointValue = 1.0,
    this.bitsPointValue = 1.0,
    this.eventRules = const [],
  });

  final List<RoundFormat> formats;
  final WolfScoringBasis scoringBasis;
  final List<String> teeOrder;
  final Map<String, int> handicaps;
  final double wolfPointValue;
  final double bitsPointValue;
  final List<RoundEventRule> eventRules;

  bool get hasWolf => roundHasWolf(formats);
  bool get hasBits => roundHasBits(formats);

  Map<String, dynamic> toJson() => {
        'formats': roundFormatsToDb(formats),
        'scoring_basis': scoringBasis.toDb(),
        'tee_order': teeOrder,
        'handicaps': handicaps.map((k, v) => MapEntry(k, v)),
        'wolf_point_value': wolfPointValue,
        'bits_point_value': bitsPointValue,
        'event_rules': eventRules
            .map(
              (r) => {
                'label': r.label,
                'delta': r.delta,
                'icon_key': r.iconKey,
              },
            )
            .toList(),
      };

  factory RoundGameConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const RoundGameConfig();
    }
    final formatsRaw = json['formats'];
    final formats = formatsRaw is List
        ? parseRoundFormats(formatsRaw)
        : const [RoundFormat.bits];
    final rulesRaw = json['event_rules'] as List<dynamic>? ?? const [];
    final rules = rulesRaw
        .map(
          (e) => RoundEventRule(
            label: (e['label'] as String?) ?? '',
            delta: (e['delta'] as num?)?.toInt() ?? 0,
            iconKey: (e['icon_key'] as String?) ?? 'star_outline',
          ),
        )
        .where((r) => r.label.isNotEmpty)
        .toList();
    final hcRaw = json['handicaps'];
    final handicaps = hcRaw is Map
        ? hcRaw.map(
            (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? int.tryParse('$v') ?? 0),
          )
        : const <String, int>{};
    return RoundGameConfig(
      formats: formats.isEmpty ? const [RoundFormat.bits] : formats,
      scoringBasis: WolfScoringBasis.fromDb(json['scoring_basis'] as String?),
      teeOrder: (json['tee_order'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      handicaps: handicaps,
      wolfPointValue: (json['wolf_point_value'] as num?)?.toDouble() ?? 1.0,
      bitsPointValue: (json['bits_point_value'] as num?)?.toDouble() ?? 1.0,
      eventRules: rules,
    );
  }
}

@immutable
class WolfHoleResult {
  const WolfHoleResult({
    required this.hole,
    required this.wolfKey,
    required this.call,
    required this.grossByPlayer,
    this.pointsByPlayer = const {},
    this.wolfBestBall,
    this.fieldBestBall,
    this.winner = WolfHoleWinner.tie,
  });

  final int hole;
  final String wolfKey;
  final WolfCall call;
  final Map<String, int> grossByPlayer;
  final Map<String, int> pointsByPlayer;
  final int? wolfBestBall;
  final int? fieldBestBall;
  final WolfHoleWinner winner;

  Map<String, dynamic> toJson() => {
        'hole': hole,
        'wolf_key': wolfKey,
        'call_type': call.type.name,
        'partner_key': call.partnerKey,
        'multiplier': call.multiplier,
        'gross': grossByPlayer.map((k, v) => MapEntry(k, v)),
        'points': pointsByPlayer.map((k, v) => MapEntry(k, v)),
        'wolf_best_ball': wolfBestBall,
        'field_best_ball': fieldBestBall,
        'winner': winner.name,
      };

  factory WolfHoleResult.fromJson(Map<String, dynamic> json) {
    final callType = WolfCallType.values.asNameMap()[json['call_type'] as String?] ??
        WolfCallType.partner;
    final grossRaw = json['gross'];
    final gross = grossRaw is Map
        ? grossRaw.map(
            (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? int.tryParse('$v') ?? 0),
          )
        : const <String, int>{};
    final pointsRaw = json['points'];
    final points = pointsRaw is Map
        ? pointsRaw.map(
            (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? int.tryParse('$v') ?? 0),
          )
        : const <String, int>{};
    return WolfHoleResult(
      hole: (json['hole'] as num?)?.toInt() ?? int.tryParse('${json['hole']}') ?? 0,
      wolfKey: (json['wolf_key'] as String?) ?? '',
      call: WolfCall(type: callType, partnerKey: json['partner_key'] as String?),
      grossByPlayer: gross,
      pointsByPlayer: points,
      wolfBestBall: (json['wolf_best_ball'] as num?)?.toInt(),
      fieldBestBall: (json['field_best_ball'] as num?)?.toInt(),
      winner: WolfHoleWinner.values.asNameMap()[json['winner'] as String?] ?? WolfHoleWinner.tie,
    );
  }
}

Map<int, WolfHoleResult> parseWolfHoleResults(dynamic raw) {
  if (raw is! Map) return {};
  final out = <int, WolfHoleResult>{};
  for (final entry in raw.entries) {
    final hole = int.tryParse(entry.key.toString());
    if (hole == null) continue;
    final value = entry.value;
    if (value is! Map) continue;
    out[hole] = WolfHoleResult.fromJson(Map<String, dynamic>.from(value));
  }
  return out;
}

Map<String, dynamic> wolfHoleResultsToJson(Map<int, WolfHoleResult> data) {
  return {for (final e in data.entries) '${e.key}': e.value.toJson()};
}

Map<String, int> parseWolfPointsByPlayer(dynamic raw) {
  if (raw is! Map) return {};
  return raw.map(
    (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? int.tryParse('$v') ?? 0),
  );
}

Map<String, int> parseHoleStrokeIndexes(dynamic raw) {
  if (raw is! Map) return {};
  return raw.map(
    (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? int.tryParse('$v') ?? 0),
  );
}

List<int> buildHoleOrder({required int holeCount, required int startHole}) {
  if (holeCount == 9) {
    return List<int>.generate(9, (i) => startHole + i);
  }
  return List<int>.generate(18, (i) => i + 1);
}
