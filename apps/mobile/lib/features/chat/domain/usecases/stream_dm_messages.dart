import 'package:mobile/features/chat/domain/entities/dm_message.dart';
import 'package:mobile/features/chat/domain/repositories/chat_repository.dart';

/// Returns a stream of messages for [dmId].
///
/// [limit] defaults to 50 per ADR 0011.
/// [startAfter] is an optional [DateTime] pagination cursor.
final class StreamDmMessagesUseCase {
  const StreamDmMessagesUseCase(this._repository);

  final ChatRepository _repository;

  Stream<List<DmMessage>> execute(
    String dmId, {
    int limit = 50,
    DateTime? startAfter,
  }) => _repository.streamMessages(dmId, limit: limit, startAfter: startAfter);
}
