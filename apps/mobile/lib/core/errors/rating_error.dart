/// Domain errors for the Rating feature.
///
/// All variants are sealed subclasses of [RatingError]. No PII may appear
/// in any error message field — only error codes and counts are permitted.
sealed class RatingError implements Exception {
  const RatingError();

  /// The rater attempted to rate themselves.
  const factory RatingError.selfRatingNotAllowed() = RatingSelfRatingNotAllowed;

  /// Rating is only allowed after the session has ended.
  const factory RatingError.sessionNotEnded() = RatingSessionNotEnded;

  /// The rater has already submitted ratings for this session.
  const factory RatingError.alreadyRated() = RatingAlreadyRated;

  /// Firestore write failed. [message] must contain no PII.
  const factory RatingError.submitFailed(String message) = RatingSubmitFailed;

  /// Rating requires an active network connection.
  const factory RatingError.offlineNotSupported() = RatingOfflineNotSupported;

  /// One or more rateeUids are not members of the session.
  const factory RatingError.rateeNotMember() = RatingRateeNotMember;
}

final class RatingSelfRatingNotAllowed extends RatingError {
  const RatingSelfRatingNotAllowed();

  @override
  String toString() => 'RatingError.selfRatingNotAllowed';
}

final class RatingSessionNotEnded extends RatingError {
  const RatingSessionNotEnded();

  @override
  String toString() => 'RatingError.sessionNotEnded';
}

final class RatingAlreadyRated extends RatingError {
  const RatingAlreadyRated();

  @override
  String toString() => 'RatingError.alreadyRated';
}

final class RatingSubmitFailed extends RatingError {
  const RatingSubmitFailed(this.message);
  final String message;

  @override
  String toString() => 'RatingError.submitFailed(message=$message)';
}

final class RatingOfflineNotSupported extends RatingError {
  const RatingOfflineNotSupported();

  @override
  String toString() => 'RatingError.offlineNotSupported';
}

final class RatingRateeNotMember extends RatingError {
  const RatingRateeNotMember();

  @override
  String toString() => 'RatingError.rateeNotMember';
}
