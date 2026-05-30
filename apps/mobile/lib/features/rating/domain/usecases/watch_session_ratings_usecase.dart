import 'package:mobile/features/rating/domain/entities/rating_entity.dart';
import 'package:mobile/features/rating/domain/repositories/rating_repository.dart';

/// Streams all ratings for a session from [RatingRepository].
///
/// Zero Flutter or Firebase imports — pure Dart.
class WatchSessionRatingsUseCase {
  WatchSessionRatingsUseCase(this._repo);

  final RatingRepository _repo;

  Stream<List<RatingEntity>> call(String sessionId) =>
      _repo.watchSessionRatings(sessionId);
}
