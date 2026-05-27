import 'package:mobile/features/rating/domain/entities/rating_entity.dart';
import 'package:mobile/features/rating/domain/usecases/watch_session_ratings_usecase.dart';
import 'package:mobile/features/rating/presentation/providers/rating_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_ratings_provider.g.dart';

/// Streams all ratings for [sessionId] ordered by ratedAt descending.
@riverpod
Stream<List<RatingEntity>> sessionRatings(
  SessionRatingsRef ref,
  String sessionId,
) => WatchSessionRatingsUseCase(
  ref.watch(ratingRepositoryProvider),
).call(sessionId);
