import 'package:mobile/features/friends/domain/repositories/friends_repository.dart';

/// Accepts a pending friend request sent to [currentUid] by [initiatorUid].
///
/// Delegates to [FriendsRepository.acceptRequest].
final class AcceptFriendRequestUseCase {
  const AcceptFriendRequestUseCase(this._repository);

  final FriendsRepository _repository;

  Future<void> execute({
    required String currentUid,
    required String initiatorUid,
  }) => _repository.acceptRequest(currentUid, initiatorUid);
}
