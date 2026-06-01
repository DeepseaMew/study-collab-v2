import 'package:mobile/features/rating/domain/entities/rating_entity.dart';

/// Abstract contract for rating persistence operations.
///
/// Zero Flutter or Firebase imports — pure Dart.
abstract class RatingRepository {
  Future<void> submitRatings(String sessionId, List<String> rateeUids);

  Stream<List<RatingEntity>> watchSessionRatings(String sessionId);

  Future<bool> hasRatedInSession(String sessionId, String raterUid);
}
