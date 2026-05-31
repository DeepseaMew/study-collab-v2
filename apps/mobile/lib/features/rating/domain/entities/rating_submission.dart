import 'package:freezed_annotation/freezed_annotation.dart';

part 'rating_submission.freezed.dart';

/// Value object encapsulating a rating submission request.
///
/// Zero Flutter or Firebase imports — pure Dart.
@freezed
abstract class RatingSubmission with _$RatingSubmission {
  const factory RatingSubmission({
    required String sessionId,
    required List<String> rateeUids,
  }) = _RatingSubmission;
}
