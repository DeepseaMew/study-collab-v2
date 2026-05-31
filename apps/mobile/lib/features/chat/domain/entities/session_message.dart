import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_message.freezed.dart';

/// Domain entity for a `sessions/{sessionId}/messages/{messageId}` document.
///
/// Pure Dart — zero Flutter or Firebase imports (ADR 0001, ADR 0012).
/// No [readBy] field: unread state lives in `users/{uid}/groupChats/{sessionId}.unreadCount`
/// only (ADR 0012 SD3).
@freezed
abstract class SessionMessage with _$SessionMessage {
  const factory SessionMessage({
    required String messageId,

    /// `'text'` or `'file_shared'`
    required String type,
    required String senderUid,

    /// Denormalized from auth state at send time (ADR 0012 SD2). Immutable.
    required String senderDisplayName,
    required DateTime sentAt,

    /// Non-empty, ≤ 4 000 chars. Null for `file_shared` messages.
    String? text,

    /// Firestore document ID of the associated note. `file_shared` only.
    String? noteId,

    /// Original file name. `file_shared` only.
    String? fileName,

    /// Firebase Storage download URL. `file_shared` only; immutable (ADR 0012 SD4).
    String? downloadUrl,
  }) = _SessionMessage;
}
