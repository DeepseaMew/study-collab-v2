import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';

/// Abstract repository interface for session CRUD operations.
///
/// Implementations live in `data/repositories/`.
/// No Firestore types may cross this boundary.
abstract interface class SessionRepository {
  /// Watches a single session document in real time.
  ///
  /// Emits `null` when the document does not exist or has been deleted.
  Stream<SessionEntity?> watchSession(String sessionId);

  /// Watches all public sessions, ordered by [SessionEntity.scheduledAt] ascending.
  Stream<List<SessionEntity>> watchPublicSessions();

  /// Watches the member list for a session.
  ///
  /// Reads `users/{uid}` documents for each UID in [SessionEntity.memberUids].
  Stream<List<UserEntity>> watchMembers(String sessionId);

  /// Creates a new session document.
  ///
  /// The implementation reads `users/{hostUid}` once to denormalize
  /// [SessionEntity.hostDisplayName] and [SessionEntity.hostPhotoUrl].
  ///
  /// Pass [plainTextPin] only when `session.visibility == 'private'`.
  Future<void> createSession(SessionEntity session, {String? plainTextPin});

  /// Edits mutable fields of an existing session.
  ///
  /// [updates] is a plain Dart map; the implementation converts to Firestore
  /// types (Timestamp, FieldValue) before writing.
  /// Only the host identified by [callerUid] may call this method.
  Future<void> editSession(
    String sessionId,
    String callerUid,
    Map<String, dynamic> updates,
  );

  /// Deletes a session document.
  ///
  /// Only the host identified by [callerUid] may delete a session, and only
  /// while `status == 'scheduled'`.
  Future<void> deleteSession(String sessionId, String callerUid);

  /// Transitions a session to `status == 'ended'` and sets [SessionEntity.endedAt].
  ///
  /// Only the host identified by [callerUid] may end a session.
  Future<void> endSession(String sessionId, String callerUid);

  /// Removes a member from a session's [SessionEntity.memberUids].
  ///
  /// Throws [AuthorisationException] when [uid] is the session host —
  /// the host cannot leave their own session.
  Future<void> leaveSession(String sessionId, String uid);

  /// Returns the raw PIN for a private session.
  ///
  /// Only the host identified by [callerUid] may call this method.
  /// Returns `null` when the session has no PIN (public session).
  Future<String?> fetchPin(String sessionId, String callerUid);

  /// Finds a private scheduled session matching [pin].
  /// Returns null when no session is found.
  Future<SessionEntity?> findSessionByPin(String pin);

  /// Watches public sessions where [uid] is the host or a member,
  /// ordered by scheduledAt descending.
  ///
  /// The host is always included in `memberUids`, so querying
  /// `memberUids array-contains uid` covers both roles.
  Stream<List<SessionEntity>> watchSessionsByUser(String uid);
}
