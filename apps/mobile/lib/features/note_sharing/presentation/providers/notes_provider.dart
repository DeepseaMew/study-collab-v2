import 'package:mobile/features/note_sharing/domain/entities/note_entity.dart';
import 'package:mobile/features/note_sharing/domain/usecases/watch_notes_usecase.dart';
import 'package:mobile/features/note_sharing/presentation/providers/note_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notes_provider.g.dart';

/// Auto-dispose stream provider that watches all notes for [sessionId].
///
/// Ordered by `uploadedAt` descending. Bounded by the 50-note session cap.
/// Delegates to [WatchNotesUseCase].
@riverpod
Stream<List<NoteEntity>> notes(NotesRef ref, String sessionId) {
  final repository = ref.watch(noteRepositoryProvider);
  return WatchNotesUseCase(repository).call(sessionId);
}
