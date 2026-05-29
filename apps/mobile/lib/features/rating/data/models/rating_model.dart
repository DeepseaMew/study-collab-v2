import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/features/rating/domain/entities/rating_entity.dart';

part 'rating_model.freezed.dart';
part 'rating_model.g.dart';

/// Firestore DTO for a rating document.
///
/// Converts [Timestamp] ↔ [DateTime] for [ratedAt] via [_TimestampConverter].
/// Use [toEntity] to cross the domain boundary.
@freezed
abstract class RatingModel with _$RatingModel {
  const RatingModel._();

  const factory RatingModel({
    required String ratingId,
    required String raterUid,
    required String rateeUid,
    required bool liked,
    @_TimestampConverter() required DateTime ratedAt,
  }) = _RatingModel;

  factory RatingModel.fromJson(Map<String, dynamic> json) =>
      _$RatingModelFromJson(json);

  factory RatingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RatingModel.fromJson(data);
  }

  RatingEntity toEntity() => RatingEntity(
    ratingId: ratingId,
    raterUid: raterUid,
    rateeUid: rateeUid,
    liked: liked,
    ratedAt: ratedAt,
  );
}

/// Converts Firestore [Timestamp] ↔ [DateTime].
class _TimestampConverter implements JsonConverter<DateTime, Timestamp> {
  const _TimestampConverter();

  @override
  DateTime fromJson(Timestamp ts) => ts.toDate();

  @override
  Timestamp toJson(DateTime dt) => Timestamp.fromDate(dt);
}
