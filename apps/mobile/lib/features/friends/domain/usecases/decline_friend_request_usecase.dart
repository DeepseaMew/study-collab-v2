import 'package:mobile/features/friends/domain/repositories/friends_repository.dart';

/// Declines a pending friend request sent to [currentUid] by [initiatorUid].
///
/// Delegates to [FriendsRepository.declineRequest].
final class DeclineFriendRequestUseCase {
  const DeclineFriendRequestUseCase(this._repository);

  final FriendsRepository _repository;

  Future<void> execute({
    required String currentUid,
    required String initiatorUid,
  }) => _repository.declineRequest(currentUid, initiatorUid);
}
