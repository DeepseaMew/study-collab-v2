// Unit tests for DeleteNoteUseCase (ADR 0008).
//
// Verifies:
//   - Delegates to repository.deleteNote with correct arguments
//   - Propagates NoteError.permissionDenied from repository
//   - Propagates NoteError.deleteFailed from repository

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/note_error.dart';
import 'package:mobile/features/note_sharing/domain/repositories/note_repository.dart';
import 'package:mobile/features/note_sharing/domain/usecases/delete_note_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockNoteRepository extends Mock implements NoteRepository {}

void main() {
  late _MockNoteRepository repository;
  late DeleteNoteUseCase useCase;

  setUp(() {
    repository = _MockNoteRepository();
    useCase = DeleteNoteUseCase(repository);
    when(() => repository.deleteNote(any(), any())).thenAnswer((_) async {});
  });

  group('DeleteNoteUseCase — delegation', () {
    test(
      'delegates to repository.deleteNote with correct sessionId and noteId',
      () async {
        const sessionId = 'sess-1';
        const noteId = 'note-42';

        await useCase.call(sessionId, noteId);

        final captured = verify(
          () => repository.deleteNote(captureAny(), captureAny()),
        ).captured;
        expect(captured[0], sessionId);
        expect(captured[1], noteId);
      },
    );

    test('calls repository.deleteNote exactly once', () async {
      await useCase.call('sess-1', 'note-1');

      verify(() => repository.deleteNote('sess-1', 'note-1')).called(1);
    });

    test('returns void on success', () async {
      final result = useCase.call('sess-1', 'note-1');
      await expectLater(result, completes);
    });
  });

  group('DeleteNoteUseCase — error propagation', () {
    test('propagates NoteError.permissionDenied from repository', () async {
      // Use Future.error so the error is wrapped in a Future (as the real
      // repository would do), preventing mocktail from throwing synchronously.
      when(
        () => repository.deleteNote(any(), any()),
      ).thenAnswer((_) => Future.error(const NoteError.permissionDenied()));

      await expectLater(
        useCase.call('sess-1', 'note-1'),
        throwsA(isA<NotePermissionDenied>()),
      );
    });

    test('propagates NoteError.deleteFailed from repository', () async {
      when(() => repository.deleteNote(any(), any())).thenAnswer(
        (_) => Future.error(
          const NoteError.deleteFailed('Firestore batch failed'),
        ),
      );

      await expectLater(
        useCase.call('sess-1', 'note-1'),
        throwsA(isA<NoteDeleteFailed>()),
      );
    });

    test('NoteDeleteFailed carries the message from repository', () async {
      const msg = 'storage timeout';
      when(
        () => repository.deleteNote(any(), any()),
      ).thenAnswer((_) => Future.error(const NoteError.deleteFailed(msg)));

      try {
        await useCase.call('sess-1', 'note-x');
        fail('Expected NoteDeleteFailed');
      } on NoteDeleteFailed catch (e) {
        expect(e.message, msg);
      }
    });

    test('does not swallow generic exceptions', () async {
      when(
        () => repository.deleteNote(any(), any()),
      ).thenAnswer((_) => Future.error(Exception('unexpected')));

      await expectLater(
        useCase.call('sess-1', 'note-1'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
