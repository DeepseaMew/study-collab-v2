import 'package:mobile/features/note_sharing/domain/entities/note_entity.dart';
import 'package:mobile/features/note_sharing/domain/entities/note_upload_params.dart';

/// Abstract repository interface for note-sharing operations (ADR 0008).
///
/// Domain layer — zero Flutter or Firebase imports permitted.
/// Implementations live in `data/repositories/`.
abstract class NoteRepository {
  /// Streams all notes for [sessionId], ordered by `uploadedAt` descending.
  /// Bounded by the 50-note session cap.
  Stream<List<NoteEntity>> watchNotes(String sessionId);

  /// Uploads a note file and creates the corresponding Firestore document.
  ///
  /// Throws [NoteError] variants on validation or network failure.
  Future<void> uploadNote(String sessionId, NoteUploadParams params);

  /// Deletes a note document and its Storage file atomically.
  ///
  /// Throws [NoteError.permissionDenied] when the caller is neither the
  /// session host nor the file owner.
  Future<void> deleteNote(String sessionId, String noteId);

  /// Fetches a paginated page of notes ordered by `uploadedAt` descending.
  ///
  /// [limit] defaults to 20. When [startAfter] is provided, only notes with
  /// `uploadedAt` strictly before that timestamp are returned.
  Future<List<NoteEntity>> fetchNotesPage(
    String sessionId, {
    int limit = 20,
    DateTime? startAfter,
  });
}
