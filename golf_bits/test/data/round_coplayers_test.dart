import 'package:flutter_test/flutter_test.dart';
import 'package:golf_bits/data/round_coplayers.dart';

void main() {
  group('RoundCoplayers.mergeLastHandicapsFromRoundRows', () {
    test('uses newest round handicap per display name', () {
      final lookup = RoundCoplayers.mergeLastHandicapsFromRoundRows(
        [
          {
            'ended_at': '2026-06-01T10:00:00Z',
            'participants': [
              {'key': 'u_you', 'display_name': 'You', 'is_you': true, 'handicap': 10},
              {'key': 'from_recent_charlie', 'display_name': 'Charlie', 'handicap': 14},
            ],
            'game_config': {
              'handicaps': {'from_recent_charlie': 14},
            },
          },
          {
            'ended_at': '2026-07-01T10:00:00Z',
            'participants': [
              {'key': 'u_you', 'display_name': 'You', 'is_you': true, 'handicap': 10},
              {'key': 'from_recent_charlie', 'display_name': 'Charlie', 'handicap': 12},
            ],
            'game_config': {
              'handicaps': {'from_recent_charlie': 12},
            },
          },
        ],
        'You',
        'user-you',
      );

      expect(lookup.byDisplayNameLower['charlie'], 12);
      expect(lookup.byUserId, isEmpty);
    });

    test('falls back to game_config handicaps when participant handicap missing', () {
      final lookup = RoundCoplayers.mergeLastHandicapsFromRoundRows(
        [
          {
            'ended_at': '2026-07-01T10:00:00Z',
            'participants': [
              {'key': 'u_you', 'display_name': 'You', 'is_you': true},
              {'key': 'u_sam', 'display_name': 'Sam', 'user_id': 'sam-id'},
            ],
            'game_config': {
              'handicaps': {'u_sam': 18},
            },
          },
        ],
        'You',
        'user-you',
      );

      expect(lookup.byUserId['sam-id'], 18);
      expect(lookup.byDisplayNameLower['sam'], 18);
    });

    test('skips self and linked current user entries', () {
      final lookup = RoundCoplayers.mergeLastHandicapsFromRoundRows(
        [
          {
            'ended_at': '2026-07-01T10:00:00Z',
            'participants': [
              {'key': 'u_you', 'display_name': 'You', 'is_you': true, 'handicap': 10},
              {
                'key': 'u_me',
                'display_name': 'Aaron',
                'user_id': 'user-you',
                'handicap': 10,
              },
            ],
          },
        ],
        'You',
        'user-you',
      );

      expect(lookup.byUserId, isEmpty);
      expect(lookup.byDisplayNameLower, isEmpty);
    });
  });
}
