import 'package:mobile/features/chat/domain/entities/group_chat_summary.dart';
import 'package:mobile/features/chat/domain/entities/session_message.dart';

/// Abstract interface for session (group) chat operations.
///
/// Pure Dart — zero Flutter or Firebase imports (ADR 0001).
/// Implemented by `SessionChatRepositoryImpl` in the data layer.
abstract interface class SessionChatRepository {
  /// Streams messages for [sessionId], ordered by `sentAt` ascending.
  ///
  /// Returns at most [limit] messages. The live stream reflects new messages
  /// as they are written to Firestore.
  Stream<List<SessionMessage>> streamMessages(
    String sessionId, {
    int limit = 50,
  });

  /// Fetches a page of older messages before [startAfter].
  ///
  /// Used to load history above the initial window when the user scrolls up.
  Future<List<SessionMessage>> getOlderMessages(
    String sessionId,
    DateTime startAfter, {
    int limit = 50,
  });

  /// Sends a text message to the session chat.
  ///
  /// Uses a [WriteBatch] to atomically write the message document and update
  /// every member's `users/{uid}/groupChats/{sessionId}` summary document
  /// (ADR 0012 SD1).
  Future<void> sendMessage({
    required String sessionId,
    required List<String> memberUids,
    required String senderUid,
    required String senderDisplayName,
    required String sessionTitle,
    required String text,
  });

  /// Zeroes `unreadCount` in `users/[uid]/groupChats/[sessionId]`.
  ///
  /// Fire-and-forget; callers should silently swallow errors.
  Future<void> markSessionRead(String sessionId, String uid);

  /// Streams all `users/[uid]/groupChats` documents ordered by
  /// `lastMessageAt` descending (Index 12, ADR 0012 SD5).
  Stream<List<GroupChatSummary>> streamGroupChatSummaries(String uid);
}
