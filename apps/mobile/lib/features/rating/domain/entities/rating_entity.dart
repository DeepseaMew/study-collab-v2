import 'package:freezed_annotation/freezed_annotation.dart';

part 'rating_entity.freezed.dart';

/// Domain entity representing a single thumbs-up rating.
///
/// Zero Flutter or Firebase imports — pure Dart.
@freezed
abstract class RatingEntity with _$RatingEntity {
  const factory RatingEntity({
    required String ratingId,
    required String raterUid,
    required String rateeUid,
    required bool liked,
    required DateTime ratedAt,
  }) = _RatingEntity;
}
