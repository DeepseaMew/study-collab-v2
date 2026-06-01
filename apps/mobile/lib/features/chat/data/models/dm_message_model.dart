import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/features/chat/domain/entities/dm_message.dart';

part 'dm_message_model.freezed.dart';
part 'dm_message_model.g.dart';

/// Data-layer model for a `dms/{dmId}/messages/{messageId}` Firestore document.
///
/// Uses Freezed + json_serializable for serialization.
/// Provides [toEntity] to convert to the domain [DmMessage].
///
/// Timestamps are stored as millisecondsSinceEpoch (int) so that the model
/// has zero dependency on [cloud_firestore] types.
@freezed
abstract class DmMessageModel with _$DmMessageModel {
  const DmMessageModel._();

  const factory DmMessageModel({
    required String messageId,
    required String senderUid,
    required String senderDisplayName,
    required String text,
    @_EpochConverter() required DateTime sentAt,
    @Default(<String>[]) List<String> readBy,
  }) = _DmMessageModel;

  factory DmMessageModel.fromJson(Map<String, dynamic> json) =>
      _$DmMessageModelFromJson(json);

  DmMessage toEntity() => DmMessage(
    messageId: messageId,
    senderUid: senderUid,
    senderDisplayName: senderDisplayName,
    text: text,
    sentAt: sentAt,
    readBy: readBy,
  );
}

/// Converts epoch milliseconds (int) ↔ [DateTime].
class _EpochConverter implements JsonConverter<DateTime, int> {
  const _EpochConverter();

  @override
  DateTime fromJson(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

  @override
  int toJson(DateTime dt) => dt.millisecondsSinceEpoch;
}
