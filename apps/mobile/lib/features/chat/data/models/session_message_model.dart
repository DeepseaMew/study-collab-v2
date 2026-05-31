import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/features/chat/domain/entities/session_message.dart';

part 'session_message_model.freezed.dart';
part 'session_message_model.g.dart';

/// Data-layer model for a `sessions/{sessionId}/messages/{messageId}` document.
///
/// Uses Freezed + json_serializable for serialization.
/// Provides [toEntity] to convert to the domain [SessionMessage].
///
/// [sentAt] is stored as epoch milliseconds (int?) so that the model has zero
/// dependency on `cloud_firestore` types; the datasource converts [Timestamp]
/// values before calling [SessionMessageModel.fromJson].
@freezed
abstract class SessionMessageModel with _$SessionMessageModel {
  const SessionMessageModel._();

  const factory SessionMessageModel({
    required String messageId,
    required String type,
    required String senderUid,
    required String senderDisplayName,
    @_EpochConverter() required DateTime sentAt,
    String? text,
    String? noteId,
    String? fileName,
    String? downloadUrl,
  }) = _SessionMessageModel;

  factory SessionMessageModel.fromJson(Map<String, dynamic> json) =>
      _$SessionMessageModelFromJson(json);

  SessionMessage toEntity() => SessionMessage(
    messageId: messageId,
    type: type,
    senderUid: senderUid,
    senderDisplayName: senderDisplayName,
    sentAt: sentAt,
    text: text,
    noteId: noteId,
    fileName: fileName,
    downloadUrl: downloadUrl,
  );
}

/// Converts epoch milliseconds (int) ↔ [DateTime].
class _EpochConverter implements JsonConverter<DateTime, Object?> {
  const _EpochConverter();

  @override
  DateTime fromJson(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    // Fallback for any unexpected type (e.g. a String from tests).
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Object? toJson(DateTime dt) => dt.millisecondsSinceEpoch;
}
