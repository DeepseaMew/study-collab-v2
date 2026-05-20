import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/core/storage_paths.dart';

/// Result of a successful avatar upload.
///
/// [url] is the cache-busted download URL ready to store in Firestore.
/// [compressedSizeBytes] is used in the analytics payload.
typedef AvatarUploadResult = ({String url, int compressedSizeBytes});

/// Data source for avatar pick, compress, and upload operations.
///
/// This is the ONLY file in the codebase permitted to import:
///   - `firebase_storage`
///   - `image_picker`
///   - `flutter_image_compress`
///
/// All Firebase Storage types are confined here. No Storage types cross the
/// repository boundary.
class AvatarDatasource {
  AvatarDatasource(this._storage);

  /// Creates an [AvatarDatasource] wired to the default [FirebaseStorage]
  /// instance. Use this factory from `@riverpod` repository providers so that
  /// presentation-layer files do not need to import `firebase_storage`.
  factory AvatarDatasource.withDefaultStorage() =>
      AvatarDatasource(FirebaseStorage.instance);

  final FirebaseStorage _storage;

  // Per-uid StreamControllers so concurrent uploads for different users
  // do not interfere with each other.
  final Map<String, StreamController<List<int>?>> _previewControllers = {};
  final Map<String, StreamController<double?>> _progressControllers = {};

  StreamController<List<int>?> _previewController(String uid) {
    return _previewControllers.putIfAbsent(
      uid,
      () => StreamController<List<int>?>.broadcast(),
    );
  }

  StreamController<double?> _progressController(String uid) {
    return _progressControllers.putIfAbsent(
      uid,
      () => StreamController<double?>.broadcast(),
    );
  }

  /// Streams raw compressed image bytes for an optimistic local preview.
  /// Emits `null` when no upload is active.
  Stream<List<int>?> watchLocalPreviewBytes(String uid) =>
      _previewController(uid).stream;

  /// Streams upload progress 0.0–1.0. Emits `null` when no upload is active.
  Stream<double?> watchUploadProgress(String uid) =>
      _progressController(uid).stream;

  /// Executes the full 9-step upload flow defined in ADR 0005.
  ///
  /// Returns an [AvatarUploadResult] on success, or `null` if the user
  /// cancelled the image picker. Throws [StorageUploadFailure] on errors.
  Future<AvatarUploadResult?> pickAndUpload(String uid) async {
    // Step 1 — Pick image from gallery.
    final XFile? xFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (xFile == null) {
      appLogger.debug('AvatarDatasource.pickAndUpload: user cancelled picker');
      return null;
    }

    // Step 2 — Read raw bytes.
    final rawBytes = await xFile.readAsBytes();

    // Step 3 — Compress to max 512×512 px, JPEG quality 85.
    Uint8List compressed;
    try {
      compressed = await FlutterImageCompress.compressWithList(
        rawBytes,
        minWidth: 512,
        minHeight: 512,
        quality: 85,
      );
    } catch (e, st) {
      appLogger.error(
        'AvatarDatasource: image compression failed',
        exception: e,
        stackTrace: st,
      );
      throw const StorageUploadFailure('Image compression failed');
    }

    // Step 4 — Emit compressed bytes for local optimistic preview.
    _previewController(uid).add(compressed);

    try {
      // Step 5 — Upload via putData; stream progress events.
      final ref = _storage.ref(StoragePaths.avatar(uid));
      final uploadTask = ref.putData(
        compressed,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      uploadTask.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          _progressController(uid).add(progress);
        }
      });

      // Step 6 — Await completion and get download URL.
      final taskSnapshot = await uploadTask;
      final downloadUrl = await taskSnapshot.ref.getDownloadURL();

      // Step 7 — Append cache-bust using & because Firebase download URLs
      // already contain ?alt=media&token=... query parameters.
      final cacheBustedUrl =
          '$downloadUrl&v=${DateTime.now().millisecondsSinceEpoch}';

      // Step 8 — Return result.
      return (url: cacheBustedUrl, compressedSizeBytes: compressed.length);
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'AvatarDatasource: Storage upload failed',
        exception: e,
        stackTrace: st,
        extra: {'code': e.code},
      );
      throw StorageUploadFailure('Storage upload failed: ${e.code}');
    } catch (e, st) {
      appLogger.error(
        'AvatarDatasource: unexpected error during upload',
        exception: e,
        stackTrace: st,
      );
      throw const StorageUploadFailure('Unexpected error during avatar upload');
    } finally {
      // Step 9 — Clear local preview and progress regardless of outcome.
      _previewController(uid).add(null);
      _progressController(uid).add(null);
    }
  }
}
