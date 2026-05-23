import 'package:mobile/core/errors/note_error.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/note_sharing/domain/entities/note_upload_params.dart';
import 'package:mobile/features/note_sharing/domain/repositories/note_repository.dart';

/// Validates and uploads a note file to the session (ADR 0008).
///
/// Domain layer — all validation logic lives here; the presentation layer
/// must not duplicate these checks.
///
/// Allowed MIME types are the fixed set declared in ADR 0008 constraints.
/// Maximum file size is 10 MB (10,485,760 bytes).
class UploadNoteUseCase {
  const UploadNoteUseCase(this._repository);

  static const int _maxSizeBytes = 10485760;

  static const Set<String> _allowedMimeTypes = {
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
  };

  final NoteRepository _repository;

  Future<void> call(String sessionId, NoteUploadParams params) async {
    if (params.sizeBytes > _maxSizeBytes) {
      appLogger.warning(
        'note_upload: file too large sizeBytes=${params.sizeBytes} limit=$_maxSizeBytes',
      );
      throw NoteFileTooLarge(params.sizeBytes);
    }

    if (!_allowedMimeTypes.contains(params.mimeType)) {
      appLogger.warning('note_upload: unsupported mimeType=${params.mimeType}');
      throw NoteUnsupportedMimeType(params.mimeType);
    }

    await _repository.uploadNote(sessionId, params);
  }
}
