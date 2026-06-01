import 'package:mobile/features/chat/domain/repositories/chat_repository.dart';

/// Sends a DM message from [senderUid] to [recipientUid] in [dmId].
///
/// Enforces the 4 000-character text limit before delegating to the
/// repository (ADR 0011 schema constraint).
final class SendDmMessageUseCase {
  const SendDmMessageUseCase(this._repository);

  final ChatRepository _repository;

  static const int maxTextLength = 4000;

  Future<void> execute({
    required String dmId,
    required String senderUid,
    required String senderDisplayName,
    required String recipientUid,
    required String text,
  }) {
    if (text.trim().isEmpty) {
      return Future.value();
    }
    final trimmed = text.trim().length > maxTextLength
        ? text.trim().substring(0, maxTextLength)
        : text.trim();
    return _repository.sendMessage(
      dmId: dmId,
      senderUid: senderUid,
      senderDisplayName: senderDisplayName,
      recipientUid: recipientUid,
      text: trimmed,
    );
  }
}
