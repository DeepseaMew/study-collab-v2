import 'package:mobile/features/rating/domain/repositories/rating_repository.dart';

/// Checks whether a user has already submitted ratings in a session.
///
/// Zero Flutter or Firebase imports — pure Dart.
class CheckHasRatedUseCase {
  CheckHasRatedUseCase(this._repo);

  final RatingRepository _repo;

  Future<bool> call(String sessionId, String raterUid) =>
      _repo.hasRatedInSession(sessionId, raterUid);
}
