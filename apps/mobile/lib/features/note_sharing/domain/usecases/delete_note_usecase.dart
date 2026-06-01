import 'package:mobile/features/note_sharing/domain/repositories/note_repository.dart';

/// Deletes a note from a session (ADR 0008).
///
/// Domain layer — delegates to [NoteRepository.deleteNote].
/// Throws [NoteError.permissionDenied] when the caller is neither the
/// session host nor the file owner (propagated from the repository).
class DeleteNoteUseCase {
  const DeleteNoteUseCase(this._repository);

  final NoteRepository _repository;

  Future<void> call(String sessionId, String noteId) =>
      _repository.deleteNote(sessionId, noteId);
}
