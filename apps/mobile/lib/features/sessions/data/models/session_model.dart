import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';

part 'session_model.freezed.dart';
part 'session_model.g.dart';

/// Data-layer model for a Firestore `sessions/{sessionId}` document.
///
/// Uses Freezed + json_serializable for serialization.
/// Provides [toEntity] to convert to the domain [SessionEntity].
@freezed
abstract class SessionModel with _$SessionModel {
  const SessionModel._();

  const factory SessionModel({
    required String sessionId,
    required String hostUid,
    required String hostFaculty,
    required String title,
    String? description,
    required List<String> hashtags,
    required String academicLevel,
    required int studentYear,
    required String visibility,
    required List<String> memberUids,
    required int noteCount,
    required String status,
    @TimestampConverter() required DateTime scheduledAt,
    @NullableTimestampConverter() DateTime? scheduledEndAt,
    @NullableTimestampConverter() DateTime? endedAt,
    required String location,
    required int capacity,
    required String hostDisplayName,
    String? hostPhotoUrl,
    @TimestampConverter() required DateTime createdAt,
    @TimestampConverter() required DateTime updatedAt,
  }) = _SessionModel;

  factory SessionModel.fromJson(Map<String, dynamic> json) =>
      _$SessionModelFromJson(json);

  /// Converts to the domain [SessionEntity], computing derived fields.
  SessionEntity toEntity() => SessionEntity(
    sessionId: sessionId,
    hostUid: hostUid,
    hostFaculty: hostFaculty,
    title: title,
    description: description,
    hashtags: hashtags,
    academicLevel: academicLevel,
    studentYear: studentYear,
    visibility: visibility,
    memberUids: memberUids,
    noteCount: noteCount,
    status: status,
    scheduledAt: scheduledAt,
    scheduledEndAt: scheduledEndAt,
    endedAt: endedAt,
    location: location,
    capacity: capacity,
    hostDisplayName: hostDisplayName,
    hostPhotoUrl: hostPhotoUrl,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

/// Converts Firestore [Timestamp] ↔ [DateTime].
class TimestampConverter implements JsonConverter<DateTime, Timestamp> {
  const TimestampConverter();

  @override
  DateTime fromJson(Timestamp ts) => ts.toDate();

  @override
  Timestamp toJson(DateTime dt) => Timestamp.fromDate(dt);
}

/// Converts nullable Firestore [Timestamp] ↔ nullable [DateTime].
class NullableTimestampConverter
    implements JsonConverter<DateTime?, Timestamp?> {
  const NullableTimestampConverter();

  @override
  DateTime? fromJson(Timestamp? ts) => ts?.toDate();

  @override
  Timestamp? toJson(DateTime? dt) => dt == null ? null : Timestamp.fromDate(dt);
}
