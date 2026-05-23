import 'package:freezed_annotation/freezed_annotation.dart';

part 'note_entity.freezed.dart';

/// Domain entity representing a shared note file in a session (ADR 0008).
///
/// Domain layer — zero Flutter or Firebase imports permitted.
@freezed
abstract class NoteEntity with _$NoteEntity {
  const factory NoteEntity({
    /// Firestore document ID.
    required String noteId,

    /// UID of the user who uploaded the note.
    required String uploaderUid,

    /// Denormalized display name of the uploader; populated from
    /// `users/{uploaderUid}.displayName` at upload time.
    required String uploaderDisplayName,

    /// Original filename including extension.
    required String fileName,

    /// Validated MIME type.
    required String mimeType,

    /// File size in bytes.
    required int sizeBytes,

    /// Firebase Storage path (not a full URL).
    /// Value of `StoragePaths.sessionNote(sessionId, noteId)`.
    required String storageRef,

    /// Firebase Storage download URL.
    required String downloadUrl,

    /// Timestamp when the file was uploaded.
    required DateTime uploadedAt,
  }) = _NoteEntity;
}
