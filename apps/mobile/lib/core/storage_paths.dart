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

  // ── Notes (reserved) ──────────────────────────────────────────────────────

  /// Reserved for the Note-Sharing feature — rules not yet defined.
  /// Do not use until the Note-Sharing ADR is accepted.
  static String noteObject(String sessionId, String fileName) =>
      'sessions/$sessionId/notes/$fileName';
}
