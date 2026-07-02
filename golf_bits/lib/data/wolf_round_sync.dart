import 'dart:async';

import '../data/history_repository.dart';
import '../data/round_session_store.dart';
import '../data/sync_status_notifier.dart';
import '../models/round_bit_event_draft.dart';
import '../models/round_game_config.dart';
import '../models/round_session_args.dart';
import '../models/stroke_tracking.dart';
import '../models/wolf_round_state.dart';
import '../models/wolf_scoring.dart';

class WolfRoundSync {
  WolfRoundSync._();

  static Map<String, int> computeWolfTotals(Map<int, WolfHoleResult> results) {
    final totals = <String, int>{};
    for (final result in results.values) {
      for (final e in result.pointsByPlayer.entries) {
        totals[e.key] = (totals[e.key] ?? 0) + e.value;
      }
    }
    return totals;
  }

  static Map<String, int> computeGrossByPlayer(Map<String, Map<int, int>> strokeByHole) {
    return computeGrossByPlayerFromStrokes(strokeByHole);
  }

  static Map<String, int> computeGrossByPlayerFromStrokes(
    Map<String, Map<int, int>> strokeByHole,
  ) {
    return {
      for (final e in strokeByHole.entries)
        if (e.value.isNotEmpty) e.key: computeGrossStrokes(e.value),
    };
  }

  static Map<String, dynamic> gameConfigPayload(WolfRoundState state) {
    final json = state.gameConfig.toJson();
    if (state.pendingCall != null && state.currentPhase == WolfInRoundPhase.score) {
      json['pending_wolf_call'] = wolfCallToJson(state.pendingCall!);
      json['opponents_teed_count'] = state.opponentsTeedCount;
    } else {
      json.remove('pending_wolf_call');
      json.remove('opponents_teed_count');
    }
    return json;
  }

  static Future<WolfRoundState> hydrateBitEvents(WolfRoundState state) async {
    final roundId = state.session.roundId;
    if (roundId == null || roundId.isEmpty || !state.session.hasBits) return state;
    try {
      await HistoryRepository.replayPendingBitEvents(roundId);
      final events = await HistoryRepository.fetchBitEventsForRound(roundId);
      final holeBits = <String, Map<int, int>>{
        for (final p in state.session.participants) p.key: <int, int>{},
      };
      final bitLog = <Map<String, dynamic>>[];
      final bitsByPlayer = {
        for (final p in state.session.participants) p.key: state.bitsByPlayer[p.key] ?? 0,
      };

      for (final row in events) {
        final hole = (row['hole'] as num).toInt();
        final delta = (row['delta'] as num).toInt();
        final pKey = row['participant_key'] as String?;
        final pName = row['player_name'] as String;
        RoundParticipant? participant;
        for (final p in state.session.participants) {
          if ((pKey != null && pKey.isNotEmpty && p.key == pKey) || p.displayName == pName) {
            participant = p;
            break;
          }
        }
        if (participant == null) continue;
        bitLog.add(row);
        final byHole = holeBits.putIfAbsent(participant.key, () => <int, int>{});
        byHole[hole] = (byHole[hole] ?? 0) + delta;
        bitsByPlayer[participant.key] = (bitsByPlayer[participant.key] ?? 0) + delta;
      }

      // Prefer higher local totals when cloud events are behind (failed sync).
      for (final p in state.session.participants) {
        final local = state.bitsByPlayer[p.key] ?? 0;
        final rebuilt = bitsByPlayer[p.key] ?? 0;
        if (local > rebuilt) {
          bitsByPlayer[p.key] = local;
        }
      }

      return state.copyWith(holeBits: holeBits, bitLog: bitLog, bitsByPlayer: bitsByPlayer);
    } catch (_) {
      return state;
    }
  }

  /// Persists round progress; returns false when cloud write fails (caller may navigate anyway).
  static Future<bool> persist(WolfRoundState state) async {
    final roundId = state.session.roundId;
    if (roundId == null || roundId.isEmpty) {
      unawaited(RoundSessionStore.saveWolfDraft(state));
      return true;
    }
    try {
      await HistoryRepository.updateRoundProgress(
        roundId: roundId,
        currentHole: state.hole,
        scoreByPlayer: state.bitsByPlayer,
        strokeByHole: state.strokeByHole,
        grossByPlayer: computeGrossByPlayer(state.strokeByHole),
        wolfPointsByPlayer: computeWolfTotals(state.wolfHoleResults),
        wolfHoleResults: state.wolfHoleResults,
        wolfHolePhase: state.currentPhase,
        gameConfig: gameConfigPayload(state),
      );
      unawaited(RoundSessionStore.saveWolfDraft(state));
      return true;
    } catch (_) {
      SyncStatusNotifier.instance.recordFailure();
      unawaited(RoundSessionStore.saveWolfDraft(state));
      return false;
    }
  }

  static Future<bool> saveBitEvent({
    required String roundId,
    required RoundBitEventDraft draft,
  }) async {
    try {
      await HistoryRepository.saveBitEventsForRound(roundId, [draft]);
      SyncStatusNotifier.instance.recordSuccess();
      return true;
    } catch (_) {
      SyncStatusNotifier.instance.recordFailure();
      await RoundSessionStore.enqueuePendingBitEvent({
        'action': 'save',
        'round_id': roundId,
        ...draft.toRow(roundId),
      });
      return false;
    }
  }

  static Future<bool> deleteBitEvent({
    required String roundId,
    required String participantKey,
    required int hole,
    required String eventLabel,
    required int delta,
  }) async {
    try {
      await HistoryRepository.deleteLatestBitEventForRound(
        roundId: roundId,
        participantKey: participantKey,
        hole: hole,
        eventLabel: eventLabel,
        delta: delta,
      );
      SyncStatusNotifier.instance.recordSuccess();
      return true;
    } catch (_) {
      SyncStatusNotifier.instance.recordFailure();
      await RoundSessionStore.enqueuePendingBitEvent({
        'action': 'delete',
        'round_id': roundId,
        'participant_key': participantKey,
        'hole': hole,
        'event_label': eventLabel,
        'delta': delta,
      });
      return false;
    }
  }
}
