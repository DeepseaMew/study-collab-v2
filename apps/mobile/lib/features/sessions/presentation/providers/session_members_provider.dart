import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_members_provider.g.dart';

/// Watches the member list for a session.
///
/// Returns the list of [UserEntity] objects for each UID in memberUids.
@riverpod
Stream<List<UserEntity>> sessionMembers(
  SessionMembersRef ref,
  String sessionId,
) {
  return ref.watch(sessionRepositoryProvider).watchMembers(sessionId);
}
