import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/features/note_sharing/domain/entities/note_entity.dart';

part 'note_model.freezed.dart';
part 'note_model.g.dart';

/// Firestore DTO for a session note document (ADR 0008).
///
/// Converts [Timestamp] ↔ [DateTime] for [uploadedAt] via
/// [_TimestampConverter].
///
/// Use [toEntity] to cross the domain boundary.
@freezed
abstract class NoteModel with _$NoteModel {
  const NoteModel._();

  const factory NoteModel({
    required String noteId,
    required String uploaderUid,
    required String uploaderDisplayName,
    required String fileName,
    required String mimeType,
    required int sizeBytes,
    required String storageRef,
    required String downloadUrl,
    @_TimestampConverter() required DateTime uploadedAt,
  }) = _NoteModel;

  factory NoteModel.fromJson(Map<String, dynamic> json) =>
      _$NoteModelFromJson(json);

  /// Converts to the domain [NoteEntity].
  NoteEntity toEntity() => NoteEntity(
        noteId: noteId,
        uploaderUid: uploaderUid,
        uploaderDisplayName: uploaderDisplayName,
        fileName: fileName,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        storageRef: storageRef,
        downloadUrl: downloadUrl,
        uploadedAt: uploadedAt,
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
