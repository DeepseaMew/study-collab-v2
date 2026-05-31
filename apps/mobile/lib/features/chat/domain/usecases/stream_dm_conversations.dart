import 'package:mobile/features/chat/domain/entities/dm_conversation.dart';
import 'package:mobile/features/chat/domain/repositories/chat_repository.dart';

/// Returns a stream of DM conversations for [uid], ordered by
/// `lastMessageAt` descending.
final class StreamDmConversationsUseCase {
  const StreamDmConversationsUseCase(this._repository);

  final ChatRepository _repository;

  Stream<List<DmConversation>> execute(String uid) =>
      _repository.streamConversations(uid);
}
