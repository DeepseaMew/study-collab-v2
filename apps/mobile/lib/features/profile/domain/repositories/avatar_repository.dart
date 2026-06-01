/// Domain repository interface for avatar upload operations.
///
/// Zero Flutter or Firebase imports — pure Dart.
abstract interface class AvatarRepository {
  /// Opens the device gallery, compresses the selected image, uploads it to
  /// Firebase Storage, and updates the Firestore photoUrl field for [uid].
  ///
  /// Returns normally (no exception) if the user cancelled the picker.
  Future<void> pickAndUpload(String uid);

  /// Streams raw compressed image bytes for an optimistic local preview while
  /// an upload is in progress. Emits `null` when no upload is active.
  Stream<List<int>?> watchLocalPreviewBytes(String uid);

  /// Streams upload progress from 0.0 to 1.0 while an upload is in progress.
  /// Emits `null` when no upload is active.
  Stream<double?> watchUploadProgress(String uid);
}
