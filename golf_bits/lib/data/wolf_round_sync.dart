import '../data/history_repository.dart';
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
      final events = await HistoryRepository.fetchBitEventsForRound(roundId);
      final holeBits = <String, Map<int, int>>{};
      final bitLog = <Map<String, dynamic>>[];
      // Rebuild from events only — [state.bitsByPlayer] / score_by_player already
      // holds the same totals and must not be added again (double-count on each hole).
      final bitsByPlayer = {
        for (final p in state.session.participants) p.key: 0,
      };
      for (final p in state.session.participants) {
        holeBits[p.key] = <int, int>{};
      }
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
      return state.copyWith(holeBits: holeBits, bitLog: bitLog, bitsByPlayer: bitsByPlayer);
    } catch (_) {
      return state;
    }
  }

  static Future<void> persist(WolfRoundState state) async {
    final roundId = state.session.roundId;
    if (roundId == null || roundId.isEmpty) return;
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
  }

  static Future<void> saveBitEvent({
    required String roundId,
    required RoundBitEventDraft draft,
  }) async {
    await HistoryRepository.saveBitEventsForRound(roundId, [draft]);
  }

  static Future<void> deleteBitEvent({
    required String roundId,
    required String participantKey,
    required int hole,
    required String eventLabel,
    required int delta,
  }) async {
    await HistoryRepository.deleteLatestBitEventForRound(
      roundId: roundId,
      participantKey: participantKey,
      hole: hole,
      eventLabel: eventLabel,
      delta: delta,
    );
  }
}
