import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile/features/sessions/data/datasources/session_datasource.dart';
import 'package:mobile/features/sessions/data/repositories/session_repository_impl.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/domain/repositories/session_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_provider.g.dart';

/// Provides the [SessionRepository] implementation.
@riverpod
SessionRepository sessionRepository(SessionRepositoryRef ref) {
  return SessionRepositoryImpl(
    SessionDatasource(FirebaseFirestore.instance),
  );
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
Stream<List<SessionEntity>> publicSessionsStream(
  PublicSessionsStreamRef ref,
) {
  return ref.watch(sessionRepositoryProvider).watchPublicSessions();
}
