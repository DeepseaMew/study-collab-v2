import 'package:mobile/features/note_sharing/domain/entities/note_entity.dart';
import 'package:mobile/features/note_sharing/domain/repositories/note_repository.dart';

/// Fetches a page of notes for a session, ordered by `uploadedAt` descending.
///
/// Domain layer — delegates to [NoteRepository.fetchNotesPage].
/// Used by [PaginatedNotesNotifier] in the presentation layer.
class FetchNotesPageUseCase {
  const FetchNotesPageUseCase(this._repository);

  final NoteRepository _repository;

  Future<List<NoteEntity>> call(
    String sessionId, {
    int limit = 20,
    DateTime? startAfter,
  }) => _repository.fetchNotesPage(
    sessionId,
    limit: limit,
    startAfter: startAfter,
  );
}
