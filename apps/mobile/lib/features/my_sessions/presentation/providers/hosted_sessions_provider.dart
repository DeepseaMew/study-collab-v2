import 'package:mobile/features/my_sessions/presentation/providers/upcoming_sessions_provider.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'hosted_sessions_provider.g.dart';

/// Watches sessions hosted by the current user.
@riverpod
Stream<List<SessionEntity>> hostedSessions(
  HostedSessionsRef ref,
  String uid,
) {
  return ref.watch(mySessionsRepositoryProvider).watchHostedSessions(uid);
}
