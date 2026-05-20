import 'package:mobile/features/friends/domain/repositories/friends_repository.dart';

/// Withdraws an outgoing friend request sent by [currentUid] to [targetUid].
///
/// Delegates to [FriendsRepository.withdrawRequest].
final class WithdrawFriendRequestUseCase {
  const WithdrawFriendRequestUseCase(this._repository);

  final FriendsRepository _repository;

  Future<void> execute({
    required String currentUid,
    required String targetUid,
  }) => _repository.withdrawRequest(currentUid, targetUid);
}
