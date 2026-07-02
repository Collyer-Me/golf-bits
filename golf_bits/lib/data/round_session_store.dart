import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/round_bit_event_draft.dart';
import '../models/round_game_config.dart';
import '../models/round_session_args.dart';
import '../models/stroke_tracking.dart';
import '../models/wolf_round_state.dart';
import '../models/wolf_scoring.dart';

/// Local draft persistence for in-progress rounds (survives refresh).
abstract final class RoundSessionStore {
  static const _draftKey = 'bits_active_round_draft_v1';
  static const _pendingEventsKey = 'bits_pending_bit_events_v1';

  static Future<void> saveBitsDraft({
    required RoundSessionArgs session,
    required int holeIndex,
    required List<Map<String, dynamic>> players,
    required Map<String, Map<int, int>> holeBits,
    required List<RoundBitEventDraft> bitLog,
    required Map<String, Map<int, int>> strokeByHole,
    required List<int> holeOrder,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'kind': 'bits',
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'session': _sessionToJson(session),
      'holeIndex': holeIndex,
      'players': players,
      'holeBits': _holeBitsToJson(holeBits),
      'bitLog': bitLog.map((e) => e.toRow(session.roundId ?? '')).toList(),
      'strokeByHole': _holeBitsToJson(strokeByHole),
      'holeOrder': holeOrder,
    };
    await prefs.setString(_draftKey, jsonEncode(payload));
  }

  static Future<void> saveWolfDraft(WolfRoundState state) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'kind': 'wolf',
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'session': _sessionToJson(state.session),
      'holeOrder': state.holeOrder,
      'holeStrokeIndexes': state.holeStrokeIndexes.map((k, v) => MapEntry(k, v)),
      'holeIndex': state.holeIndex,
      'wolfPointsByPlayer': state.wolfPointsByPlayer,
      'wolfHoleResults': wolfHoleResultsToJson(state.wolfHoleResults),
      'bitsByPlayer': state.bitsByPlayer,
      'holeBits': _holeBitsToJson(state.holeBits),
      'strokeByHole': _holeBitsToJson(state.strokeByHole),
      'bitLog': state.bitLog,
      'pendingCall': state.pendingCall == null ? null : wolfCallToJson(state.pendingCall!),
      'opponentsTeedCount': state.opponentsTeedCount,
      'currentPhase': state.currentPhase.name,
      'gameConfig': state.gameConfig.toJson(),
    };
    await prefs.setString(_draftKey, jsonEncode(payload));
  }

  static Future<({String kind, Map<String, dynamic> data})?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final kind = (map['kind'] as String?) ?? 'bits';
      return (kind: kind, data: map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
    await prefs.remove(_pendingEventsKey);
  }

  static Future<List<Map<String, dynamic>>> loadPendingBitEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingEventsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> savePendingBitEvents(List<Map<String, dynamic>> events) async {
    final prefs = await SharedPreferences.getInstance();
    if (events.isEmpty) {
      await prefs.remove(_pendingEventsKey);
      return;
    }
    await prefs.setString(_pendingEventsKey, jsonEncode(events));
  }

  static Future<void> enqueuePendingBitEvent(Map<String, dynamic> event) async {
    final pending = await loadPendingBitEvents();
    pending.add(event);
    await savePendingBitEvents(pending);
  }

  static RoundSessionArgs sessionFromJson(Map<String, dynamic> m) {
    final participants = (m['participants'] as List<dynamic>? ?? [])
        .map((e) => RoundParticipant.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final eventRules = (m['eventRules'] as List<dynamic>? ?? [])
        .map(
          (e) => RoundEventRule(
            label: (e as Map)['label'] as String,
            delta: (e['delta'] as num).toInt(),
            iconKey: e['icon_key'] as String? ?? '',
          ),
        )
        .toList();
    return RoundSessionArgs(
      courseName: m['courseName'] as String? ?? '',
      courseShortTitle: m['courseShortTitle'] as String? ?? '',
      holeCount: (m['holeCount'] as num?)?.toInt() ?? 18,
      startHole: (m['startHole'] as num?)?.toInt() ?? 1,
      playerNames: (m['playerNames'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      roundId: m['roundId'] as String?,
      currentHole: (m['currentHole'] as num?)?.toInt() ?? 1,
      initialScoreByPlayer: _intMap(m['initialScoreByPlayer']),
      eventRules: eventRules,
      participants: participants,
      strokeTrackingMode: StrokeTrackingMode.fromDb(m['strokeTrackingMode'] as String?),
      holePars: _stringIntMap(m['holePars']),
      holeYardages: _stringIntMap(m['holeYardages']),
      holeStrokeIndexes: _stringIntMap(m['holeStrokeIndexes']),
      gameConfig: RoundGameConfig.fromJson(
        Map<String, dynamic>.from(m['gameConfig'] as Map? ?? {}),
      ),
    );
  }

  static WolfRoundState? wolfStateFromDraft(Map<String, dynamic> data) {
    final sessionJson = data['session'];
    if (sessionJson is! Map) return null;
    final session = sessionFromJson(Map<String, dynamic>.from(sessionJson));
    final holeOrder = (data['holeOrder'] as List<dynamic>? ?? [])
        .map((e) => (e as num).toInt())
        .toList();
    if (holeOrder.isEmpty) return WolfRoundState.fromSession(session);
    return WolfRoundState(
      session: session,
      gameConfig: RoundGameConfig.fromJson(
        Map<String, dynamic>.from(data['gameConfig'] as Map? ?? session.gameConfig.toJson()),
      ),
      holeOrder: holeOrder,
      holeStrokeIndexes: _stringIntMap(data['holeStrokeIndexes']),
      holeIndex: (data['holeIndex'] as num?)?.toInt() ?? 0,
      wolfPointsByPlayer: _intMap(data['wolfPointsByPlayer']),
      wolfHoleResults: parseWolfHoleResults(data['wolfHoleResults']),
      bitsByPlayer: _intMap(data['bitsByPlayer']),
      holeBits: _holeBitsFromJson(data['holeBits']),
      strokeByHole: _holeBitsFromJson(data['strokeByHole']),
      bitLog: (data['bitLog'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      pendingCall: parsePendingWolfCall(data['pendingCall']),
      opponentsTeedCount: (data['opponentsTeedCount'] as num?)?.toInt() ?? 0,
      currentPhase: (data['currentPhase'] as String?) == 'score'
          ? WolfInRoundPhase.score
          : WolfInRoundPhase.call,
    );
  }

  static Map<String, dynamic> _sessionToJson(RoundSessionArgs s) => {
        'courseName': s.courseName,
        'courseShortTitle': s.courseShortTitle,
        'holeCount': s.holeCount,
        'startHole': s.startHole,
        'playerNames': s.playerNames,
        'roundId': s.roundId,
        'currentHole': s.currentHole,
        'initialScoreByPlayer': s.initialScoreByPlayer,
        'eventRules': s.eventRules
            .map((r) => {'label': r.label, 'delta': r.delta, 'icon_key': r.iconKey})
            .toList(),
        'participants': s.participants.map((p) => p.toJson()).toList(),
        'strokeTrackingMode': s.strokeTrackingMode.toDb(),
        'holePars': s.holePars,
        'holeYardages': s.holeYardages,
        'holeStrokeIndexes': s.holeStrokeIndexes,
        'gameConfig': s.gameConfig.toJson(),
      };

  static Map<String, dynamic> _holeBitsToJson(Map<String, Map<int, int>> src) => {
        for (final e in src.entries)
          e.key: {for (final h in e.value.entries) '${h.key}': h.value},
      };

  static Map<String, Map<int, int>> _holeBitsFromJson(dynamic raw) {
    if (raw is! Map) return {};
    final out = <String, Map<int, int>>{};
    for (final e in raw.entries) {
      final inner = e.value;
      if (inner is! Map) continue;
      out[e.key as String] = {
        for (final h in inner.entries) int.parse(h.key.toString()): (h.value as num).toInt(),
      };
    }
    return out;
  }

  static Map<String, int> _intMap(dynamic raw) {
    if (raw is! Map) return {};
    return {for (final e in raw.entries) e.key as String: (e.value as num).toInt()};
  }

  static Map<String, int> _stringIntMap(dynamic raw) {
    if (raw is! Map) return {};
    return {for (final e in raw.entries) e.key.toString(): (e.value as num).toInt()};
  }
}
