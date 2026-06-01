import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/features/friends/domain/entities/friend_entity.dart';

part 'friend_model.freezed.dart';
part 'friend_model.g.dart';

/// Data-layer model for a `users/{uid}/friends/{friendUid}` Firestore document.
///
/// Uses Freezed + json_serializable for serialization.
/// Provides [toEntity] to convert to the domain [FriendEntity].
@freezed
abstract class FriendModel with _$FriendModel {
  const FriendModel._();

  const factory FriendModel({
    required String friendUid,
    required String status,
    required String initiatorUid,
    @_EpochConverter() required DateTime createdAt,
    @_EpochConverter() required DateTime updatedAt,
    @Default('') String friendDisplayName,
    String? friendPhotoUrl,
  }) = _FriendModel;

  factory FriendModel.fromJson(Map<String, dynamic> json) =>
      _$FriendModelFromJson(json);

  /// Converts to the domain [FriendEntity].
  FriendEntity toEntity() => FriendEntity(
    friendUid: friendUid,
    status: status,
    initiatorUid: initiatorUid,
    createdAt: createdAt,
    updatedAt: updatedAt,
    friendDisplayName: friendDisplayName,
    friendPhotoUrl: friendPhotoUrl,
  );
}

/// Converts epoch milliseconds (int) ↔ [DateTime].
///
/// Used so that [FriendModel] has no dependency on [cloud_firestore] types.
/// The [FriendsDatasource] converts Firestore [Timestamp] fields to
/// millisecondsSinceEpoch before calling [FriendModel.fromJson].
class _EpochConverter implements JsonConverter<DateTime, int> {
  const _EpochConverter();

  @override
  DateTime fromJson(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

  @override
  int toJson(DateTime dt) => dt.millisecondsSinceEpoch;
}
