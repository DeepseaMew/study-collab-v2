import 'package:mobile/features/friends/domain/entities/friend_entity.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'incoming_requests_provider.g.dart';

/// Watches pending friend requests received by [uid].
@riverpod
Stream<List<FriendEntity>> incomingRequests(
  IncomingRequestsRef ref,
  String uid,
) {
  return ref.watch(friendsRepositoryProvider).watchIncomingRequests(uid);
}
