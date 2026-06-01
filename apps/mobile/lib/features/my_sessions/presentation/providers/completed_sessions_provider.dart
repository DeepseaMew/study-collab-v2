import 'package:mobile/features/my_sessions/presentation/providers/upcoming_sessions_provider.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'completed_sessions_provider.g.dart';

/// Watches completed (ended) sessions for the current user.
@riverpod
Stream<List<SessionEntity>> completedSessions(
  CompletedSessionsRef ref,
  String uid,
) {
  return ref.watch(mySessionsRepositoryProvider).watchCompletedSessions(uid);
}
