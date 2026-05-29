import 'package:mobile/core/errors/rating_error.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/rating/domain/entities/rating_submission.dart';
import 'package:mobile/features/rating/domain/repositories/rating_repository.dart';

/// Validates and delegates a rating submission to [RatingRepository].
///
/// Zero Flutter or Firebase imports — pure Dart.
class SubmitRatingsUseCase {
  SubmitRatingsUseCase(this._repo, this._currentUserId);

  final RatingRepository _repo;
  final String _currentUserId;

  Future<void> call(
    RatingSubmission submission,
    List<String> sessionMemberUids,
  ) async {
    if (submission.rateeUids.isEmpty) {
      appLogger.warning(
        'submit_ratings: rateeUids is empty — nothing to submit',
        extra: {'sessionId': submission.sessionId},
      );
      throw const RatingError.submitFailed('empty_ratee_list');
    }

    if (submission.rateeUids.contains(_currentUserId)) {
      appLogger.warning(
        'submit_ratings: self-rating attempt rejected',
        extra: {'sessionId': submission.sessionId},
      );
      throw const RatingError.selfRatingNotAllowed();
    }

    final memberSet = sessionMemberUids.toSet();
    final nonMembers = submission.rateeUids
        .where((uid) => !memberSet.contains(uid))
        .toList();
    if (nonMembers.isNotEmpty) {
      appLogger.warning(
        'submit_ratings: rateeUid not in session members',
        extra: {
          'sessionId': submission.sessionId,
          'nonMemberCount': nonMembers.length,
        },
      );
      throw const RatingError.rateeNotMember();
    }

    await _repo.submitRatings(submission.sessionId, submission.rateeUids);
  }
}
