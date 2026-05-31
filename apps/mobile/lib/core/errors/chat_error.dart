/// Domain errors for the Chat (DM) feature.
///
/// Uses a standalone sealed hierarchy so it does not need to extend the
/// sealed [AppException] class from another library.
sealed class ChatError implements Exception {
  const ChatError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when the sender is not friends with the recipient, enforced
/// client-side in [ChatRepositoryImpl.sendMessage] before any Firestore write.
///
/// ADR 0011: `areFriends()` is NOT called in Firestore rules on the DM path
/// (10-call budget constraint). The friends gate is enforced here in the
/// client layer.
final class NotFriendsException extends ChatError {
  const NotFriendsException([
    super.message = 'You must be friends to send a message.',
  ]);
}

/// Thrown when a DM send or read operation fails at the Firestore level.
final class ChatDataException extends ChatError {
  const ChatDataException(super.message);
}
