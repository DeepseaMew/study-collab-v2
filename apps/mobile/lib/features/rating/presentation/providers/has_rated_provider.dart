import 'package:mobile/features/rating/domain/usecases/check_has_rated_usecase.dart';
import 'package:mobile/features/rating/presentation/providers/rating_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'has_rated_provider.g.dart';

/// Returns true if [raterUid] has already submitted ratings for [sessionId].
@riverpod
Future<bool> hasRated(
  HasRatedRef ref,
  String sessionId,
  String raterUid,
) =>
    CheckHasRatedUseCase(ref.watch(ratingRepositoryProvider)).call(
      sessionId,
      raterUid,
    );
