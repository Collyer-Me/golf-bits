import 'package:flutter/foundation.dart';

/// One awarded bit event (in-memory during scoring; persisted after round save).
@immutable
class RoundBitEventDraft {
  const RoundBitEventDraft({
    required this.playerName,
    required this.hole,
    required this.eventLabel,
    required this.delta,
    this.iconKey,
  });

  final String playerName;
  final int hole;
  final String eventLabel;
  final int delta;
  final String? iconKey;

  Map<String, dynamic> toRow(String roundId) => {
        'round_id': roundId,
        'player_name': playerName,
        'hole': hole,
        'event_label': eventLabel,
        'delta': delta,
        'icon_key': iconKey,
      };
}
