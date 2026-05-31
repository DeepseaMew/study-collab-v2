import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/errors/rating_error.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/rating/domain/entities/rating_submission.dart';
import 'package:mobile/features/rating/domain/usecases/submit_ratings_usecase.dart';
import 'package:mobile/features/rating/presentation/providers/has_rated_provider.dart';
import 'package:mobile/features/rating/presentation/providers/rating_flag_provider.dart';
import 'package:mobile/features/rating/presentation/providers/rating_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'rating_provider.g.dart';

/// Manages the rating submission flow for a given session.
@riverpod
class RatingNotifier extends _$RatingNotifier {
  @override
  AsyncValue<void> build(String sessionId) => const AsyncValue.data(null);

  Future<void> submitRatings(
    List<String> rateeUids,
    List<String> sessionMemberUids,
  ) async {
    final isEnabled = ref.read(ratingEnabledProvider);
    if (!isEnabled) {
      state = AsyncError(
        const RatingError.submitFailed('rating_disabled'),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncValue.loading();

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final repo = ref.read(ratingRepositoryProvider);
    final useCase = SubmitRatingsUseCase(repo, currentUserId);

    try {
      await useCase.call(
        RatingSubmission(sessionId: sessionId, rateeUids: rateeUids),
        sessionMemberUids,
      );
      state = const AsyncValue.data(null);
      appLogger.info(
        'rating: submission succeeded',
        extra: {'sessionId': sessionId, 'rateeCount': rateeUids.length},
      );
      appLogger.debug(
        '${AnalyticsEvents.ratingSubmitted} ratee_count=${rateeUids.length}',
      );
      ref.invalidate(hasRatedProvider(sessionId, currentUserId));
    } on RatingError catch (e, st) {
      state = AsyncError(e, st);
      appLogger.warning(
        'rating: submission rejected',
        extra: {'errorType': e.runtimeType.toString()},
      );
      appLogger.debug(
        '${AnalyticsEvents.ratingSubmitFailed} error_type=${e.runtimeType}',
      );
    } catch (e, st) {
      state = AsyncError(e, st);
      appLogger.error(
        'rating: unexpected error during submission',
        exception: e,
        stackTrace: st,
      );
    }
  }
}
