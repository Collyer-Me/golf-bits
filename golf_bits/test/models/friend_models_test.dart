import 'package:flutter_test/flutter_test.dart';
import 'package:golf_bits/models/friend_models.dart';

void main() {
  group('FriendConnection', () {
    const connection = FriendConnection(
      friendshipId: 'f1',
      status: 'pending',
      requesterUserId: 'user-a',
      addresseeUserId: 'user-b',
      otherUserId: 'user-b',
      otherDisplayName: 'Jamie',
    );

    test('detects incoming and outgoing pending requests', () {
      expect(connection.isIncomingFor('user-b'), isTrue);
      expect(connection.isIncomingFor('user-a'), isFalse);
      expect(connection.isOutgoingFor('user-a'), isTrue);
      expect(connection.isOutgoingFor('user-b'), isFalse);
    });

    test('isAccepted only for accepted status', () {
      expect(connection.isAccepted, isFalse);
      const accepted = FriendConnection(
        friendshipId: 'f1',
        status: 'accepted',
        requesterUserId: 'user-a',
        addresseeUserId: 'user-b',
        otherUserId: 'user-b',
        otherDisplayName: 'Jamie',
      );
      expect(accepted.isAccepted, isTrue);
    });

    test('fromRpc fills display name fallback', () {
      final fromRow = FriendConnection.fromRpc({
        'friendship_id': 'f2',
        'status': 'accepted',
        'requester_user_id': 'a',
        'addressee_user_id': 'b',
        'other_user_id': 'b',
        'other_display_name': '   ',
      });
      expect(fromRow.otherDisplayName, 'Player');
      expect(fromRow.isAccepted, isTrue);
    });
  });

  group('FriendCandidate', () {
    test('fromRpc trims display name and email', () {
      final candidate = FriendCandidate.fromRpc({
        'user_id': 'u1',
        'display_name': '  Alex  ',
        'email': ' alex@example.com ',
      });
      expect(candidate.displayName, 'Alex');
      expect(candidate.email, 'alex@example.com');
    });
  });
}
