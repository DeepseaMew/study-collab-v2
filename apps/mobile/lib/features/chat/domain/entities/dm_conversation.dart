/// Domain entity for a DM conversation document (`dms/{dmId}`).
///
/// Pure Dart — zero Flutter or Firebase imports (ADR 0011 constraint).
///
/// [unreadCountForMe] is a computed convenience value resolved by the
/// presentation layer: `unreadCounts[myUid] ?? 0`.
final class DmConversation {
  const DmConversation({
    required this.dmId,
    required this.participantUids,
    required this.createdAt,
    required this.unreadCounts,
    this.lastMessageText,
    this.lastMessageAt,
  });

  /// Deterministic document ID: `min(uidA, uidB)_max(uidA, uidB)`.
  /// Constructed in `data/` only (ADR 0011 constraint).
  final String dmId;

  /// Exactly two UIDs in lexicographic order.
  final List<String> participantUids;

  /// Server-generated timestamp from first-send lazy doc creation.
  final DateTime createdAt;

  /// Map of `{uid: unreadCount}`. Incremented on send, zeroed on open.
  final Map<String, int> unreadCounts;

  /// Preview text (≤ 200 chars) from the last message. Null when no messages.
  final String? lastMessageText;

  /// Timestamp of the last message. Null when no messages have been sent.
  final DateTime? lastMessageAt;

  /// Resolves the unread count for [myUid].
  int unreadCountForUid(String uid) => unreadCounts[uid] ?? 0;

  /// Returns the UID of the other participant (not [myUid]).
  String otherUid(String myUid) =>
      participantUids.firstWhere((uid) => uid != myUid, orElse: () => '');
}
