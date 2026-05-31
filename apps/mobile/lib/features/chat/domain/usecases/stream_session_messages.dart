import 'package:mobile/features/chat/domain/entities/session_message.dart';
import 'package:mobile/features/chat/domain/repositories/session_chat_repository.dart';

/// Returns the live message stream for a session chat.
///
/// Pure Dart — zero Flutter or Firebase imports.
final class StreamSessionMessages {
  const StreamSessionMessages(this._repository);

  final SessionChatRepository _repository;

  Stream<List<SessionMessage>> execute(String sessionId, {int limit = 50}) {
    return _repository.streamMessages(sessionId, limit: limit);
  }
}
