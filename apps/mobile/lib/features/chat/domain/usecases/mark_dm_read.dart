import 'package:mobile/features/chat/domain/repositories/chat_repository.dart';

/// Zeroes the unread count for [uid] in [dmId].
///
/// Called on conversation open and silently ignored on failure
/// (ADR 0011: partial failure yields a stale badge — heals on next open).
final class MarkDmReadUseCase {
  const MarkDmReadUseCase(this._repository);

  final ChatRepository _repository;

  Future<void> execute(String dmId, String uid) =>
      _repository.markRead(dmId, uid);
}
