import 'package:mobile/features/chat/domain/entities/group_chat_summary.dart';
import 'package:mobile/features/chat/domain/repositories/session_chat_repository.dart';

/// Returns the live group-chat summary stream for a user.
///
/// Powers the Groups tab in the Messages screen (ADR 0012 SD5).
/// Pure Dart — zero Flutter or Firebase imports.
final class StreamGroupChatSummaries {
  const StreamGroupChatSummaries(this._repository);

  final SessionChatRepository _repository;

  Stream<List<GroupChatSummary>> execute(String uid) {
    return _repository.streamGroupChatSummaries(uid);
  }
}
