class FriendCandidate {
  const FriendCandidate({
    required this.userId,
    required this.displayName,
    this.email,
  });

  final String userId;
  final String displayName;
  final String? email;

  factory FriendCandidate.fromRpc(Map<String, dynamic> row) {
    return FriendCandidate(
      userId: (row['user_id'] as String?) ?? '',
      displayName: ((row['display_name'] as String?)?.trim().isNotEmpty ?? false)
          ? (row['display_name'] as String).trim()
          : 'Player',
      email: (row['email'] as String?)?.trim(),
    );
  }
}

class FriendConnection {
  const FriendConnection({
    required this.friendshipId,
    required this.status,
    required this.requesterUserId,
    required this.addresseeUserId,
    required this.otherUserId,
    required this.otherDisplayName,
    this.otherEmail,
  });

  final String friendshipId;
  final String status;
  final String requesterUserId;
  final String addresseeUserId;
  final String otherUserId;
  final String otherDisplayName;
  final String? otherEmail;

  bool isIncomingFor(String uid) => status == 'pending' && addresseeUserId == uid;
  bool isOutgoingFor(String uid) => status == 'pending' && requesterUserId == uid;
  bool get isAccepted => status == 'accepted';

  factory FriendConnection.fromRpc(Map<String, dynamic> row) {
    return FriendConnection(
      friendshipId: (row['friendship_id'] as String?) ?? '',
      status: (row['status'] as String?) ?? 'pending',
      requesterUserId: (row['requester_user_id'] as String?) ?? '',
      addresseeUserId: (row['addressee_user_id'] as String?) ?? '',
      otherUserId: (row['other_user_id'] as String?) ?? '',
      otherDisplayName: ((row['other_display_name'] as String?)?.trim().isNotEmpty ?? false)
          ? (row['other_display_name'] as String).trim()
          : 'Player',
      otherEmail: (row['other_email'] as String?)?.trim(),
    );
  }
}
