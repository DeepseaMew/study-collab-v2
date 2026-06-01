/// The relationship status between the currently signed-in user and another user.
///
/// This enum lives in the domain layer so that both presentation providers and
/// presentation widgets can import it without any cross-layer violation.
/// No Flutter or Firebase imports — pure Dart.
enum FriendshipStatus {
  /// The two users have no relationship.
  notFriends,

  /// The current user has sent a friend request that has not yet been accepted.
  requestSent,

  /// The other user has sent a friend request to the current user.
  requestReceived,

  /// Both users have accepted each other's request; they are friends.
  friends,

  /// The profile being viewed belongs to the current user.
  self,
}
