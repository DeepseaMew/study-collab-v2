/// All Firestore path templates as string constants.
///
/// This is the ONLY file in the codebase that may contain Firestore path
/// strings. Never inline path strings in datasource or repository files.
abstract final class FirestorePaths {
  // ── Users ──────────────────────────────────────────────────────────────────
  static const String usersCollection = 'users';

  static String userDoc(String uid) => 'users/$uid';

  // ── Sessions ───────────────────────────────────────────────────────────────
  static const String sessionsCollection = 'sessions';

  static String sessionDoc(String sessionId) => 'sessions/$sessionId';

  // ── Session subcollections ─────────────────────────────────────────────────
  static String sessionMessagesCollection(String sessionId) =>
      'sessions/$sessionId/messages';

  static String sessionMessageDoc(String sessionId, String messageId) =>
      'sessions/$sessionId/messages/$messageId';

  static String sessionRequestsCollection(String sessionId) =>
      'sessions/$sessionId/requests';

  static String sessionRequestDoc(String sessionId, String uid) =>
      'sessions/$sessionId/requests/$uid';

  static String ratings(String sessionId) => 'sessions/$sessionId/ratings';

  static String rating(String sessionId, String raterUid, String rateeUid) =>
      'sessions/$sessionId/ratings/${raterUid}_$rateeUid';

  static String sessionNotesCollection(String sessionId) =>
      'sessions/$sessionId/notes';

  static String sessionNoteDoc(String sessionId, String noteId) =>
      'sessions/$sessionId/notes/$noteId';

  // ── DMs ────────────────────────────────────────────────────────────────────
  static const String dmsCollection = 'dms';

  static String dmDoc(String dmId) => 'dms/$dmId';

  static String dmMessagesCollection(String dmId) => 'dms/$dmId/messages';

  static String dmMessageDoc(String dmId, String messageId) =>
      'dms/$dmId/messages/$messageId';

  // ── Friends ────────────────────────────────────────────────────────────────
  static String userFriendsCollection(String uid) => 'users/$uid/friends';

  static String userFriendDoc(String uid, String friendUid) =>
      'users/$uid/friends/$friendUid';

  // ── Group chats ────────────────────────────────────────────────────────────
  /// `users/{uid}/groupChats` — summary documents for the Groups tab (ADR 0012).
  static String userGroupChatsCollection(String uid) => 'users/$uid/groupChats';

  /// `users/{uid}/groupChats/{sessionId}` — individual summary document.
  static String userGroupChatDoc(String uid, String sessionId) =>
      'users/$uid/groupChats/$sessionId';

  // ── Notifications ──────────────────────────────────────────────────────────
  /// `users/{uid}/notifications` — per-user notification subcollection (ADR 0013).
  static String userNotificationsCollection(String uid) =>
      'users/$uid/notifications';

  /// `users/{uid}/notifications/{notifId}` — individual notification document.
  static String userNotificationDoc(String uid, String notifId) =>
      'users/$uid/notifications/$notifId';
}
