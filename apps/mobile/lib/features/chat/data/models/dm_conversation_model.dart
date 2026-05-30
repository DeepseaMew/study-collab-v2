import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/features/chat/domain/entities/dm_conversation.dart';

part 'dm_conversation_model.freezed.dart';
part 'dm_conversation_model.g.dart';

/// Data-layer model for a `dms/{dmId}` Firestore document.
///
/// Uses Freezed + json_serializable for serialization.
/// Provides [toEntity] to convert to the domain [DmConversation].
///
/// Timestamps are stored as millisecondsSinceEpoch (int) so that the model
/// has zero dependency on [cloud_firestore] types; the datasource converts
/// [Timestamp] values before calling [DmConversationModel.fromJson].
@freezed
abstract class DmConversationModel with _$DmConversationModel {
  const DmConversationModel._();

  const factory DmConversationModel({
    required String dmId,
    required List<String> participantUids,
    @_EpochConverter() required DateTime createdAt,
    @Default(<String, int>{}) Map<String, int> unreadCounts,
    String? lastMessageText,
    @_NullableEpochConverter() DateTime? lastMessageAt,
  }) = _DmConversationModel;

  factory DmConversationModel.fromJson(Map<String, dynamic> json) =>
      _$DmConversationModelFromJson(json);

  DmConversation toEntity() => DmConversation(
    dmId: dmId,
    participantUids: participantUids,
    createdAt: createdAt,
    unreadCounts: unreadCounts,
    lastMessageText: lastMessageText,
    lastMessageAt: lastMessageAt,
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

/// Nullable variant for optional timestamp fields.
class _NullableEpochConverter implements JsonConverter<DateTime?, int?> {
  const _NullableEpochConverter();

  @override
  DateTime? fromJson(int? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);

  @override
  int? toJson(DateTime? dt) => dt?.millisecondsSinceEpoch;
}
