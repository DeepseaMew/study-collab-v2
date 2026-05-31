import 'package:mobile/features/chat/domain/repositories/session_chat_repository.dart';

/// Zeroes the unread count for a session chat for a given user.
///
/// Pure Dart — zero Flutter or Firebase imports.
final class MarkSessionRead {
  const MarkSessionRead(this._repository);

  final SessionChatRepository _repository;

  Future<void> execute(String sessionId, String uid) {
    return _repository.markSessionRead(sessionId, uid);
  }
}
