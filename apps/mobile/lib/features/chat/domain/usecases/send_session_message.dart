import 'package:mobile/features/chat/domain/repositories/session_chat_repository.dart';

/// Sends a text message to a session (group) chat.
///
/// Pure Dart — zero Flutter or Firebase imports.
final class SendSessionMessage {
  const SendSessionMessage(this._repository);

  final SessionChatRepository _repository;

  Future<void> execute({
    required String sessionId,
    required List<String> memberUids,
    required String senderUid,
    required String senderDisplayName,
    required String sessionTitle,
    required String text,
  }) {
    return _repository.sendMessage(
      sessionId: sessionId,
      memberUids: memberUids,
      senderUid: senderUid,
      senderDisplayName: senderDisplayName,
      sessionTitle: sessionTitle,
      text: text,
    );
  }
}
