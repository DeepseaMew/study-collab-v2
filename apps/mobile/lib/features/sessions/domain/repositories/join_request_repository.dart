import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/features/sessions/domain/entities/join_request_entity.dart';

/// Abstract repository interface for join-request operations.
///
/// Implementations live in `data/repositories/`.
/// No Firestore types may cross this boundary.
abstract interface class JoinRequestRepository {
  /// Watches the pending join requests for a session in real time.
  ///
  /// Only the host should call this; Firestore rules enforce read permission.
  Stream<List<JoinRequestEntity>> watchRequests(String sessionId);

  /// Watches whether the current user has a pending request for [sessionId].
  ///
  /// Reads only `sessions/{sessionId}/requests/{uid}` — a single-document
  /// stream that never opens a collection listener. Safe to call for any
  /// authenticated user.
  Stream<bool> watchMyRequest(String sessionId, String uid);

  /// Submits a join request for the requesting user.
  ///
  /// The implementation stores the request document at
  /// `sessions/{sessionId}/requests/{request.uid}`.
  Future<void> submitRequest(String sessionId, JoinRequestEntity request);

  /// Approves a pending join request.
  ///
  /// Uses a [WriteBatch] to atomically:
  ///   1. Delete `sessions/{sessionId}/requests/{requestUid}`.
  ///   2. Append [requestUid] to `sessions/{sessionId}.memberUids` via arrayUnion.
  ///
  /// Only the host identified by [callerUid] may approve.
  Future<void> approveRequest(
    String sessionId,
    String callerUid,
    String requestUid,
  );

  /// Declines a pending join request by deleting its document.
  ///
  /// Only the host identified by [callerUid] may decline.
  Future<void> declineRequest(
    String sessionId,
    String callerUid,
    String requestUid,
  );

  /// Allows the requesting user to withdraw their own pending request.
  Future<void> withdrawRequest(String sessionId, String uid);

  /// Submits a join request for a private session, including [pin] so that
  /// the Firestore rule `request.resource.data.pin == session.pin` passes.
  ///
  /// Unlike [joinWithPin], the request is left pending — the host must still
  /// approve it. Throws [InvalidPinException] if the PIN does not match.
  Future<void> submitRequestWithPin(
    String sessionId,
    JoinRequestEntity request,
    String pin,
  );

  /// Joins a private session by submitting a request that includes [pin].
  ///
  /// The PIN is written to `sessions/{sessionId}/requests/{request.uid}`
  /// and validated server-side by Firestore rules — it is never compared
  /// in client code. If the PIN is wrong, Firestore returns permission-denied
  /// and this method throws [InvalidPinException].
  ///
  /// On success the request is immediately approved, adding [request.uid]
  /// to `sessions/{sessionId}.memberUids`.
  Future<void> joinWithPin(
    String sessionId,
    JoinRequestEntity request,
    String pin,
  );
}
