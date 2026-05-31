import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_chat_summary.freezed.dart';

/// Domain entity for a `users/{uid}/groupChats/{sessionId}` document.
///
/// Pure Dart — zero Flutter or Firebase imports (ADR 0012).
/// Drives the Groups tab list in the Messages screen.
@freezed
abstract class GroupChatSummary with _$GroupChatSummary {
  const factory GroupChatSummary({
    required String sessionId,
    required String sessionTitle,

    /// Preview of the last message. Null when the chat has no messages yet.
    String? lastMessageText,

    /// Server timestamp of the last message. Null when no messages exist.
    DateTime? lastMessageAt,

    /// Number of unread messages for the owning user.
    /// Zeroed by [SessionChatRepository.markSessionRead].
    required int unreadCount,
  }) = _GroupChatSummary;
}
