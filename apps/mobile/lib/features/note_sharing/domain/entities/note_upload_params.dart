import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'note_upload_params.freezed.dart';

/// Value object carrying the parameters needed to upload a note (ADR 0008).
///
/// Domain layer — the only non-pure-Dart type permitted here is [Uint8List]
/// from `dart:typed_data`, which is a Dart SDK core library with no Flutter
/// or Firebase dependency (ADR 0008 constraints section).
@freezed
abstract class NoteUploadParams with _$NoteUploadParams {
  const factory NoteUploadParams({
    /// Original filename including extension.
    required String fileName,

    /// MIME type reported by the file picker.
    required String mimeType,

    /// File size in bytes.
    required int sizeBytes,

    /// Raw file bytes.
    required Uint8List bytes,
  }) = _NoteUploadParams;
}
