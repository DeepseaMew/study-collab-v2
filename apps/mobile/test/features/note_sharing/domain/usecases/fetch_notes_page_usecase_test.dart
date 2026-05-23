// Unit tests for FetchNotesPageUseCase (ADR 0008).
//
// Verifies:
//   - Delegates to repository.fetchNotesPage with correct arguments
//   - Default limit of 20 is forwarded
//   - startAfter cursor is forwarded when provided
//   - Returns empty list when repository returns empty list
//   - Propagates repository errors

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/note_sharing/domain/entities/note_entity.dart';
import 'package:mobile/features/note_sharing/domain/repositories/note_repository.dart';
import 'package:mobile/features/note_sharing/domain/usecases/fetch_notes_page_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockNoteRepository extends Mock implements NoteRepository {}

NoteEntity _note(String noteId) => NoteEntity(
  noteId: noteId,
  uploaderUid: 'uid-1',
  uploaderDisplayName: 'Alice',
  fileName: '$noteId.pdf',
  mimeType: 'application/pdf',
  sizeBytes: 1024,
  storageRef: 'sessions/sess-1/notes/$noteId',
  downloadUrl: 'https://example.com/$noteId',
  uploadedAt: DateTime(2026, 5, 23),
);

void main() {
  late _MockNoteRepository repository;
  late FetchNotesPageUseCase useCase;

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    repository = _MockNoteRepository();
    useCase = FetchNotesPageUseCase(repository);
  });

  group('FetchNotesPageUseCase — default arguments', () {
    test('delegates to repository with sessionId and default limit', () async {
      const sessionId = 'sess-abc';
      when(
        () => repository.fetchNotesPage(
          sessionId,
          limit: any(named: 'limit'),
          startAfter: any(named: 'startAfter'),
        ),
      ).thenAnswer((_) async => []);

      await useCase.call(sessionId);

      final captured = verify(
        () => repository.fetchNotesPage(
          captureAny(),
          limit: captureAny(named: 'limit'),
          startAfter: captureAny(named: 'startAfter'),
        ),
      ).captured;
      expect(captured[0], sessionId);
      expect(captured[1], 20); // default limit
      expect(captured[2], isNull); // no cursor
    });

    test('returns empty list when repository returns empty list', () async {
      when(
        () => repository.fetchNotesPage(
          any(),
          limit: any(named: 'limit'),
          startAfter: any(named: 'startAfter'),
        ),
      ).thenAnswer((_) async => []);

      final result = await useCase.call('sess-empty');
      expect(result, isEmpty);
    });
  });

  group('FetchNotesPageUseCase — explicit limit', () {
    test('forwards custom limit to repository', () async {
      when(
        () => repository.fetchNotesPage(
          any(),
          limit: any(named: 'limit'),
          startAfter: any(named: 'startAfter'),
        ),
      ).thenAnswer((_) async => []);

      await useCase.call('sess-1', limit: 10);

      verify(
        () => repository.fetchNotesPage(
          any(),
          limit: 10,
          startAfter: any(named: 'startAfter'),
        ),
      ).called(1);
    });
  });

  group('FetchNotesPageUseCase — startAfter cursor', () {
    test('forwards startAfter to repository when provided', () async {
      final cursor = DateTime(2026, 5, 20);
      when(
        () => repository.fetchNotesPage(
          any(),
          limit: any(named: 'limit'),
          startAfter: any(named: 'startAfter'),
        ),
      ).thenAnswer((_) async => []);

      await useCase.call('sess-1', startAfter: cursor);

      verify(
        () => repository.fetchNotesPage(
          any(),
          limit: any(named: 'limit'),
          startAfter: cursor,
        ),
      ).called(1);
    });

    test('passes null startAfter when not provided', () async {
      when(
        () => repository.fetchNotesPage(
          any(),
          limit: any(named: 'limit'),
          startAfter: any(named: 'startAfter'),
        ),
      ).thenAnswer((_) async => []);

      await useCase.call('sess-1');

      verify(
        () => repository.fetchNotesPage(any(), limit: any(named: 'limit')),
      ).called(1);
    });
  });

  group('FetchNotesPageUseCase — result forwarding', () {
    test('returns notes returned by repository', () async {
      final notes = List.generate(20, (i) => _note('note-$i'));
      when(
        () => repository.fetchNotesPage(
          any(),
          limit: any(named: 'limit'),
          startAfter: any(named: 'startAfter'),
        ),
      ).thenAnswer((_) async => notes);

      final result = await useCase.call('sess-1');
      expect(result, notes);
      expect(result.length, 20);
    });

    test('preserves order of notes from repository', () async {
      final notes = [_note('note-c'), _note('note-b'), _note('note-a')];
      when(
        () => repository.fetchNotesPage(
          any(),
          limit: any(named: 'limit'),
          startAfter: any(named: 'startAfter'),
        ),
      ).thenAnswer((_) async => notes);

      final result = await useCase.call('sess-1');
      expect(result.map((n) => n.noteId).toList(), [
        'note-c',
        'note-b',
        'note-a',
      ]);
    });

    test('propagates repository exceptions', () async {
      when(
        () => repository.fetchNotesPage(
          any(),
          limit: any(named: 'limit'),
          startAfter: any(named: 'startAfter'),
        ),
      ).thenAnswer((_) => Future.error(Exception('Firestore unavailable')));

      await expectLater(useCase.call('sess-1'), throwsA(isA<Exception>()));
    });
  });
}
