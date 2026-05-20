import 'package:mobile/features/friends/domain/repositories/friends_repository.dart';

/// Removes an accepted friendship between [currentUid] and [friendUid].
///
/// Delegates to [FriendsRepository.unfriend].
final class UnfriendUseCase {
  const UnfriendUseCase(this._repository);

  final FriendsRepository _repository;

  Future<void> execute({
    required String currentUid,
    required String friendUid,
  }) => _repository.unfriend(currentUid, friendUid);
}
