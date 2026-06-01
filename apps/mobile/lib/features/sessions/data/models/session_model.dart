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
    required DateTime scheduledAt,
    DateTime? scheduledEndAt,
    DateTime? endedAt,
    required String location,
    required int capacity,
    required String hostDisplayName,
    String? hostPhotoUrl,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _SessionModel;

  factory SessionModel.fromJson(Map<String, dynamic> json) =>
      _$SessionModelFromJson(json);

  /// Deserializes a Firestore document map into a [SessionModel].
  ///
  /// Uses explicit [Timestamp] type checks instead of generated casts so the
  /// method is safe on Flutter Web, where the Firestore JS SDK returns dynamic
  /// objects that cannot be directly cast to the Dart [Timestamp] type.
  static SessionModel fromFirestore(Map<String, dynamic> data) {
    Timestamp? ts(dynamic v) => v is Timestamp ? v : null;
    Timestamp tsRequired(dynamic v) {
      if (v is Timestamp) return v;
      throw ArgumentError('Expected Timestamp but got ${v?.runtimeType}: $v');
    }

    return SessionModel(
      sessionId: data['sessionId'] as String,
      hostUid: data['hostUid'] as String,
      hostFaculty: data['hostFaculty'] as String,
      title: data['title'] as String,
      description: data['description'] as String?,
      hashtags: List<String>.from(data['hashtags'] as List),
      academicLevel: data['academicLevel'] as String,
      studentYear: (data['studentYear'] as num).toInt(),
      visibility: data['visibility'] as String,
      memberUids: List<String>.from(data['memberUids'] as List),
      noteCount: (data['noteCount'] as num).toInt(),
      status: data['status'] as String,
      scheduledAt: tsRequired(data['scheduledAt']).toDate(),
      scheduledEndAt: ts(data['scheduledEndAt'])?.toDate(),
      endedAt: ts(data['endedAt'])?.toDate(),
      location: data['location'] as String,
      capacity: (data['capacity'] as num).toInt(),
      hostDisplayName: data['hostDisplayName'] as String,
      hostPhotoUrl: data['hostPhotoUrl'] as String?,
      createdAt: tsRequired(data['createdAt']).toDate(),
      updatedAt: tsRequired(data['updatedAt']).toDate(),
    );
  }

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
///
/// Uses [Object] as the JSON type so the generated cast is `as Object`
/// rather than `as Timestamp`, which avoids a runtime failure on Flutter Web
/// where Firestore returns JavaScript objects that cannot be directly cast
/// to the Dart [Timestamp] type.
class TimestampConverter implements JsonConverter<DateTime, Object> {
  const TimestampConverter();

  @override
  DateTime fromJson(Object ts) {
    if (ts is Timestamp) return ts.toDate();
    throw ArgumentError('Expected Timestamp, got ${ts.runtimeType}');
  }

  @override
  Object toJson(DateTime dt) => Timestamp.fromDate(dt);
}

/// Converts nullable Firestore [Timestamp] ↔ nullable [DateTime].
///
/// Uses [Object?] as the JSON type for the same web-compatibility reason
/// as [TimestampConverter].
class NullableTimestampConverter implements JsonConverter<DateTime?, Object?> {
  const NullableTimestampConverter();

  @override
  DateTime? fromJson(Object? ts) {
    if (ts == null) return null;
    if (ts is Timestamp) return ts.toDate();
    return null;
  }

  @override
  Object? toJson(DateTime? dt) => dt == null ? null : Timestamp.fromDate(dt);
}
