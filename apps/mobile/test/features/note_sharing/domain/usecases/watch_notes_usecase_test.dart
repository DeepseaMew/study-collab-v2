// Unit tests for WatchNotesUseCase (ADR 0008).
//
// Verifies that the use case delegates to NoteRepository.watchNotes and
// passes the sessionId through unchanged.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/note_sharing/domain/entities/note_entity.dart';
import 'package:mobile/features/note_sharing/domain/repositories/note_repository.dart';
import 'package:mobile/features/note_sharing/domain/usecases/watch_notes_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockNoteRepository extends Mock implements NoteRepository {}

NoteEntity _note({String noteId = 'note-1'}) => NoteEntity(
  noteId: noteId,
  uploaderUid: 'uid-1',
  uploaderDisplayName: 'Alice',
  fileName: 'lecture.pdf',
  mimeType: 'application/pdf',
  sizeBytes: 1024,
  storageRef: 'sessions/sess-1/notes/$noteId',
  downloadUrl: 'https://example.com/$noteId',
  uploadedAt: DateTime(2026, 5, 23, 10),
);

void main() {
  late _MockNoteRepository repository;
  late WatchNotesUseCase useCase;

  setUp(() {
    repository = _MockNoteRepository();
    useCase = WatchNotesUseCase(repository);
  });

  group('WatchNotesUseCase', () {
    test('delegates to repository.watchNotes with correct sessionId', () {
      const sessionId = 'sess-abc';
      when(
        () => repository.watchNotes(sessionId),
      ).thenAnswer((_) => Stream.value([]));

      useCase.call(sessionId);

      verify(() => repository.watchNotes(sessionId)).called(1);
    });

    test('returns the stream emitted by repository', () async {
      const sessionId = 'sess-1';
      final notes = [_note(), _note(noteId: 'note-2')];

      when(
        () => repository.watchNotes(sessionId),
      ).thenAnswer((_) => Stream.value(notes));

      final result = await useCase.call(sessionId).first;
      expect(result, notes);
    });

    test('emits empty list when repository emits empty list', () async {
      const sessionId = 'sess-empty';
      when(
        () => repository.watchNotes(sessionId),
      ).thenAnswer((_) => Stream.value([]));

      final result = await useCase.call(sessionId).first;
      expect(result, isEmpty);
    });

    test('propagates repository stream error', () async {
      const sessionId = 'sess-err';
      when(
        () => repository.watchNotes(sessionId),
      ).thenAnswer((_) => Stream.error(Exception('firestore error')));

      expect(useCase.call(sessionId), emitsError(isA<Exception>()));
    });

    test('returns stream with multiple emissions in order', () async {
      const sessionId = 'sess-multi';
      final first = [_note()];
      final second = [_note(), _note(noteId: 'note-2')];

      when(
        () => repository.watchNotes(sessionId),
      ).thenAnswer((_) => Stream.fromIterable([first, second]));

      final results = await useCase.call(sessionId).toList();
      expect(results, [first, second]);
    });
  });
}
