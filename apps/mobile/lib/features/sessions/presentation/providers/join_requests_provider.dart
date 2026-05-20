import 'package:mobile/features/sessions/data/datasources/join_request_datasource.dart';
import 'package:mobile/features/sessions/data/datasources/session_datasource.dart';
import 'package:mobile/features/sessions/data/repositories/join_request_repository_impl.dart';
import 'package:mobile/features/sessions/domain/entities/join_request_entity.dart';
import 'package:mobile/features/sessions/domain/repositories/join_request_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'join_requests_provider.g.dart';

/// Provides the [JoinRequestRepository] implementation.
///
/// Both [JoinRequestDatasource.withDefaultFirestore] and
/// [SessionDatasource.withDefaultFirestore] are called here — inside the
/// `@riverpod` body — so no `cloud_firestore` import is needed in this file.
@riverpod
JoinRequestRepository joinRequestRepository(JoinRequestRepositoryRef ref) {
  return JoinRequestRepositoryImpl(
    JoinRequestDatasource.withDefaultFirestore(),
    SessionDatasource.withDefaultFirestore(),
  );
}

/// Watches the join requests for a session.
///
/// Host-only. Firestore rules deny collection reads for non-hosts.
@riverpod
Stream<List<JoinRequestEntity>> joinRequests(
  JoinRequestsRef ref,
  String sessionId,
) {
  return ref.watch(joinRequestRepositoryProvider).watchRequests(sessionId);
}

/// Watches whether the current user has a pending request for [sessionId].
///
/// Reads a single document — never a collection query. Safe to call for any
/// authenticated user regardless of host status.
@riverpod
Stream<bool> myPendingRequest(
  MyPendingRequestRef ref,
  String sessionId,
  String uid,
) {
  return ref
      .watch(joinRequestRepositoryProvider)
      .watchMyRequest(sessionId, uid);
}
