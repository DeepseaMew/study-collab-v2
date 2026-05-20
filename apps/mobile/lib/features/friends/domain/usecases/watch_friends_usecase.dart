import 'package:mobile/features/friends/domain/entities/friend_entity.dart';
import 'package:mobile/features/friends/domain/repositories/friends_repository.dart';

/// Returns a stream of accepted friends for [uid].
///
/// Delegates to [FriendsRepository.watchFriends].
final class WatchFriendsUseCase {
  const WatchFriendsUseCase(this._repository);

  final FriendsRepository _repository;

  Stream<List<FriendEntity>> execute(String uid) =>
      _repository.watchFriends(uid);
}
