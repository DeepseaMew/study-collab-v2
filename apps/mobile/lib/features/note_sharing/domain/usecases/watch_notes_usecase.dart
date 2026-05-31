import 'package:mobile/features/note_sharing/domain/entities/note_entity.dart';
import 'package:mobile/features/note_sharing/domain/repositories/note_repository.dart';

/// Watches all notes for a session in real time (ADR 0008 sub-decision 3).
///
/// Domain layer — delegates directly to [NoteRepository.watchNotes].
class WatchNotesUseCase {
  const WatchNotesUseCase(this._repository);

  final NoteRepository _repository;

  Stream<List<NoteEntity>> call(String sessionId) =>
      _repository.watchNotes(sessionId);
}
