import 'package:mobile/features/friends/domain/repositories/friends_repository.dart';

/// Sends a friend request from [currentUid] to [targetUid].
///
/// Delegates to [FriendsRepository.sendRequest].
final class SendFriendRequestUseCase {
  const SendFriendRequestUseCase(this._repository);

  final FriendsRepository _repository;

  Future<void> execute({
    required String currentUid,
    required String targetUid,
  }) => _repository.sendRequest(currentUid, targetUid);
}
