/// All Firebase Storage path templates as string constants.
///
/// This is the ONLY file in the codebase that may contain Storage path
/// strings. Never inline path strings in datasource or repository files.
///
/// Storage paths are separate from Firestore paths (see [FirestorePaths])
/// because they are consumed by [FirebaseStorage] rather than [FirebaseFirestore].
abstract final class StoragePaths {
  StoragePaths._();

  // ── Avatars ───────────────────────────────────────────────────────────────

  /// Canonical avatar path for a user. Single file per user; overwritten on
  /// each new upload (ADR 0005 sub-decision 1).
  static String avatar(String uid) => 'avatars/$uid/avatar.jpg';

  // ── Notes ─────────────────────────────────────────────────────────────────

  /// Storage path for a session note file (ADR 0008 sub-decision 1).
  ///
  /// The [noteId] is the Firestore-auto-generated document ID; this path
  /// mirrors the Firestore `sessions/{sessionId}/notes/{noteId}` path.
  /// The `storageRef` field on the Firestore note document stores this path
  /// verbatim.
  static String sessionNote(String sessionId, String noteId) =>
      'sessions/$sessionId/notes/$noteId';
}
