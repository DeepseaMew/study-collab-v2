/// Domain errors for the Note-Sharing feature (ADR 0008).
///
/// All variants are sealed subclasses of [NoteError]. No PII may appear
/// in any error message field — only sizes, MIME type strings, and
/// error codes are permitted.
sealed class NoteError implements Exception {
  const NoteError();

  /// File exceeds the 10 MB limit. [sizeBytes] is the actual file size.
  const factory NoteError.fileTooLarge(int sizeBytes) = NoteFileTooLarge;

  /// The MIME type is not in the allowed set. [mimeType] must contain no PII.
  const factory NoteError.unsupportedMimeType(String mimeType) =
      NoteUnsupportedMimeType;

  /// The session has reached the 50-note cap.
  const factory NoteError.sessionCapReached() = NoteSessionCapReached;

  /// Firebase Storage or Firestore write failed. [message] must contain no PII.
  const factory NoteError.uploadFailed(String message) = NoteUploadFailed;

  /// Delete operation failed. [message] must contain no PII.
  const factory NoteError.deleteFailed(String message) = NoteDeleteFailed;

  /// Caller is neither the session host nor the file owner.
  const factory NoteError.permissionDenied() = NotePermissionDenied;
}

final class NoteFileTooLarge extends NoteError {
  const NoteFileTooLarge(this.sizeBytes);
  final int sizeBytes;

  @override
  String toString() =>
      'NoteError.fileTooLarge(sizeBytes=$sizeBytes, limit=10485760)';
}

final class NoteUnsupportedMimeType extends NoteError {
  const NoteUnsupportedMimeType(this.mimeType);
  final String mimeType;

  @override
  String toString() => 'NoteError.unsupportedMimeType(mimeType=$mimeType)';
}

final class NoteSessionCapReached extends NoteError {
  const NoteSessionCapReached();

  @override
  String toString() => 'NoteError.sessionCapReached';
}

final class NoteUploadFailed extends NoteError {
  const NoteUploadFailed(this.message);
  final String message;

  @override
  String toString() => 'NoteError.uploadFailed(message=$message)';
}

final class NoteDeleteFailed extends NoteError {
  const NoteDeleteFailed(this.message);
  final String message;

  @override
  String toString() => 'NoteError.deleteFailed(message=$message)';
}

final class NotePermissionDenied extends NoteError {
  const NotePermissionDenied();

  @override
  String toString() => 'NoteError.permissionDenied';
}
