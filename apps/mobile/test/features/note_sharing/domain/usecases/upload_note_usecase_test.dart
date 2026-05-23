// Unit tests for UploadNoteUseCase (ADR 0008).
//
// Verifies:
//   - Throws NoteError.fileTooLarge when sizeBytes > 10,485,760
//   - Throws NoteError.unsupportedMimeType for a disallowed MIME type
//   - Delegates to repository.uploadNote when params are valid
//   - Accepts all allowed MIME types
//   - Accepts exactly 10 MB (boundary value)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/note_error.dart';
import 'package:mobile/features/note_sharing/domain/entities/note_upload_params.dart';
import 'package:mobile/features/note_sharing/domain/repositories/note_repository.dart';
import 'package:mobile/features/note_sharing/domain/usecases/upload_note_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockNoteRepository extends Mock implements NoteRepository {}

NoteUploadParams _params({
  String fileName = 'file.pdf',
  String mimeType = 'application/pdf',
  int sizeBytes = 1024,
  Uint8List? bytes,
}) => NoteUploadParams(
  fileName: fileName,
  mimeType: mimeType,
  sizeBytes: sizeBytes,
  bytes: bytes ?? Uint8List(sizeBytes),
);

void main() {
  late _MockNoteRepository repository;
  late UploadNoteUseCase useCase;

  setUpAll(() {
    registerFallbackValue(_params());
  });

  setUp(() {
    repository = _MockNoteRepository();
    useCase = UploadNoteUseCase(repository);
    when(() => repository.uploadNote(any(), any())).thenAnswer((_) async {});
  });

  group('UploadNoteUseCase — file size validation', () {
    test('throws NoteFileTooLarge when sizeBytes exceeds 10 MB', () async {
      const oversized = 10485761; // one byte over 10 MB
      final params = _params(sizeBytes: oversized, bytes: Uint8List(0));

      await expectLater(
        useCase.call('sess-1', params),
        throwsA(isA<NoteFileTooLarge>()),
      );
      verifyNever(() => repository.uploadNote(any(), any()));
    });

    test('throws NoteFileTooLarge and includes the actual sizeBytes', () async {
      const oversized = 20000000;
      final params = _params(sizeBytes: oversized, bytes: Uint8List(0));

      try {
        await useCase.call('sess-1', params);
        fail('Expected NoteFileTooLarge');
      } on NoteFileTooLarge catch (e) {
        expect(e.sizeBytes, oversized);
      }
    });

    test('accepts exactly 10 MB (boundary value — not too large)', () async {
      const exactly10Mb = 10485760;
      final params = _params(sizeBytes: exactly10Mb, bytes: Uint8List(0));

      await useCase.call('sess-1', params);

      verify(() => repository.uploadNote('sess-1', any())).called(1);
    });

    test('accepts sizeBytes = 1 (minimum valid size)', () async {
      final params = _params(sizeBytes: 1, bytes: Uint8List(1));

      await useCase.call('sess-1', params);

      verify(() => repository.uploadNote('sess-1', any())).called(1);
    });
  });

  group('UploadNoteUseCase — MIME type validation', () {
    test(
      'throws NoteUnsupportedMimeType for application/octet-stream',
      () async {
        final params = _params(mimeType: 'application/octet-stream');

        await expectLater(
          useCase.call('sess-1', params),
          throwsA(isA<NoteUnsupportedMimeType>()),
        );
        verifyNever(() => repository.uploadNote(any(), any()));
      },
    );

    test('throws NoteUnsupportedMimeType for video/mp4', () async {
      final params = _params(mimeType: 'video/mp4');

      await expectLater(
        useCase.call('sess-1', params),
        throwsA(isA<NoteUnsupportedMimeType>()),
      );
    });

    test('NoteUnsupportedMimeType contains the offending mimeType', () async {
      const badMime = 'image/tiff';
      final params = _params(mimeType: badMime);

      try {
        await useCase.call('sess-1', params);
        fail('Expected NoteUnsupportedMimeType');
      } on NoteUnsupportedMimeType catch (e) {
        expect(e.mimeType, badMime);
      }
    });

    test('throws NoteUnsupportedMimeType for empty string mimeType', () async {
      final params = _params(mimeType: '');

      await expectLater(
        useCase.call('sess-1', params),
        throwsA(isA<NoteUnsupportedMimeType>()),
      );
    });

    // Allowed MIME types — all should delegate to repository.
    for (final mime in [
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/webp',
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'text/plain',
      'application/zip',
      'application/x-rar-compressed',
      'application/x-7z-compressed',
    ]) {
      test('accepts allowed MIME type: $mime', () async {
        final params = _params(mimeType: mime);

        await useCase.call('sess-1', params);

        verify(() => repository.uploadNote('sess-1', any())).called(1);
      });
    }
  });

  group('UploadNoteUseCase — repository delegation', () {
    test(
      'delegates to repository.uploadNote with correct sessionId and params',
      () async {
        const sessionId = 'sess-delegate';
        final params = _params(fileName: 'report.pdf', sizeBytes: 512);

        await useCase.call(sessionId, params);

        final captured = verify(
          () => repository.uploadNote(captureAny(), captureAny()),
        ).captured;
        expect(captured[0], sessionId);
        final capturedParams = captured[1] as NoteUploadParams;
        expect(capturedParams.fileName, 'report.pdf');
        expect(capturedParams.mimeType, 'application/pdf');
        expect(capturedParams.sizeBytes, 512);
      },
    );

    test('propagates NoteError.uploadFailed from repository', () async {
      when(() => repository.uploadNote(any(), any())).thenAnswer(
        (_) =>
            Future.error(const NoteError.uploadFailed('Storage write failed')),
      );
      final params = _params();

      await expectLater(
        useCase.call('sess-1', params),
        throwsA(isA<NoteUploadFailed>()),
      );
    });

    test('propagates NoteError.sessionCapReached from repository', () async {
      when(
        () => repository.uploadNote(any(), any()),
      ).thenAnswer((_) => Future.error(const NoteError.sessionCapReached()));
      final params = _params();

      await expectLater(
        useCase.call('sess-1', params),
        throwsA(isA<NoteSessionCapReached>()),
      );
    });
  });
}
