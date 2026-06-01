import 'package:mobile/features/friends/domain/entities/friend_entity.dart';
import 'package:mobile/features/friends/domain/repositories/friends_repository.dart';

/// Returns a stream of pending friend requests received by [uid].
///
/// Delegates to [FriendsRepository.watchIncomingRequests].
final class WatchIncomingRequestsUseCase {
  const WatchIncomingRequestsUseCase(this._repository);

  final FriendsRepository _repository;

  Stream<List<FriendEntity>> execute(String uid) =>
      _repository.watchIncomingRequests(uid);
}
