import 'package:flutter/material.dart';

import '../data/wolf_round_sync.dart';
import '../models/wolf_round_state.dart';
import '../screens/wolf_call_screen.dart';
import '../screens/wolf_score_hole_screen.dart';

/// Jump between Wolf holes for review and correction.
class WolfRoundNavigation {
  WolfRoundNavigation._();

  static WolfRoundState stateForHoleIndex(WolfRoundState state, int holeIndex) {
    final hole = state.holeOrder[holeIndex];
    final saved = state.wolfHoleResults[hole];
    if (saved != null) {
      return state.copyWith(
        holeIndex: holeIndex,
        pendingCall: saved.call,
        currentPhase: WolfInRoundPhase.score,
      );
    }
    return state.copyWith(
      holeIndex: holeIndex,
      currentPhase: WolfInRoundPhase.call,
      clearPendingCall: true,
      opponentsTeedCount: 0,
    );
  }

  static Future<void> openHole(
    BuildContext context,
    WolfRoundState state,
    int holeIndex,
  ) async {
    if (holeIndex < 0 || holeIndex >= state.holeOrder.length) return;
    final next = stateForHoleIndex(state, holeIndex);
    await WolfRoundSync.persist(next);
    if (!context.mounted) return;

    final Widget screen;
    if (next.currentPhase == WolfInRoundPhase.score && next.pendingCall != null) {
      screen = WolfScoreHoleScreen(state: next);
    } else {
      screen = WolfCallScreen(state: next);
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }
}
