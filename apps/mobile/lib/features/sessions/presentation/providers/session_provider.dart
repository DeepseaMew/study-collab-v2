import 'package:mobile/features/sessions/data/datasources/session_datasource.dart';
import 'package:mobile/features/sessions/data/repositories/session_repository_impl.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/domain/repositories/session_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_provider.g.dart';

/// Provides the [SessionRepository] implementation.
///
/// [SessionDatasource.withDefaultFirestore] is called here — inside the
/// `@riverpod` body — so no `cloud_firestore` import is needed in this file.
@riverpod
SessionRepository sessionRepository(SessionRepositoryRef ref) {
  return SessionRepositoryImpl(SessionDatasource.withDefaultFirestore());
}

/// Watches a single session by ID.
///
/// Emits `null` when the session does not exist.
@riverpod
Stream<SessionEntity?> sessionStream(SessionStreamRef ref, String sessionId) {
  return ref.watch(sessionRepositoryProvider).watchSession(sessionId);
}

/// Watches all public sessions.
@riverpod
Stream<List<SessionEntity>> publicSessionsStream(PublicSessionsStreamRef ref) {
  return ref.watch(sessionRepositoryProvider).watchPublicSessions();
}

/// Watches public sessions where [uid] is the host or a member,
/// ordered by scheduledAt descending.
@riverpod
Stream<List<SessionEntity>> sessionsByUser(
  SessionsByUserRef ref,
  String uid,
) {
  return ref.watch(sessionRepositoryProvider).watchSessionsByUser(uid);
}
