/// Domain entity for a DM message document (`dms/{dmId}/messages/{messageId}`).
///
/// Pure Dart — zero Flutter or Firebase imports (ADR 0011 constraint).
final class DmMessage {
  const DmMessage({
    required this.messageId,
    required this.senderUid,
    required this.senderDisplayName,
    required this.text,
    required this.sentAt,
    required this.readBy,
  });

  /// Auto-generated ID, stored redundantly in the document.
  final String messageId;

  /// UID of the sender; must be a participant in the parent DM conversation.
  final String senderUid;

  /// Display name denormalized at send time from auth state (ADR 0011 SD5).
  /// Immutable after creation.
  final String senderDisplayName;

  /// Message body. Non-empty; ≤ 4 000 chars.
  final String text;

  /// Server timestamp set at creation. Immutable.
  final DateTime sentAt;

  /// List of UIDs that have read this message. Append-only.
  /// Initialized to `[senderUid]` on creation.
  final List<String> readBy;
}
