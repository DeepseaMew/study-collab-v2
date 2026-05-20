import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/profile/data/datasources/avatar_datasource.dart';
import 'package:mobile/features/profile/data/datasources/profile_datasource.dart';
import 'package:mobile/features/profile/domain/repositories/avatar_repository.dart';

/// Firestore + Storage implementation of [AvatarRepository].
///
/// Coordinates [AvatarDatasource] (Storage + image picker) with
/// [ProfileDatasource] (Firestore photoUrl write). No Firebase types appear
/// at the [AvatarRepository] interface boundary.
class AvatarRepositoryImpl implements AvatarRepository {
  AvatarRepositoryImpl(this._avatarDatasource, this._profileDatasource);

  final AvatarDatasource _avatarDatasource;
  final ProfileDatasource _profileDatasource;

  @override
  Future<void> pickAndUpload(String uid) async {
    appLogger.info(AnalyticsEvents.avatarUploadStarted);

    try {
      final result = await _avatarDatasource.pickAndUpload(uid);
      if (result == null) {
        // User cancelled the gallery picker — treat as a no-op.
        appLogger.debug('AvatarRepositoryImpl.pickAndUpload: user cancelled');
        return;
      }

      // Write the cache-busted download URL to Firestore.
      try {
        await _profileDatasource.updateProfile(uid, {
          'photoUrl': result.url,
        });
      } on DataException catch (e) {
        appLogger.warning(
          'Avatar uploaded to Storage but Firestore update failed; '
          'photoUrl may be stale — retrying once',
          extra: {'error': e.message},
        );
        // Retry once as prescribed by ADR 0005 error handling.
        try {
          await _profileDatasource.updateProfile(uid, {
            'photoUrl': result.url,
          });
        } catch (retryError, retrySt) {
          appLogger.warning(
            'Avatar uploaded to Storage but Firestore update failed after '
            'retry; photoUrl may be stale for this user',
            extra: {'error': retryError.toString()},
          );
          appLogger.info(
            AnalyticsEvents.avatarUploadFailed,
            extra: {'reason': 'firestore_error'},
          );
          // Re-throw so the presentation layer can revert the optimistic UI.
          Error.throwWithStackTrace(e, retrySt);
        }
      }

      appLogger.info(
        AnalyticsEvents.avatarUploadSucceeded,
        extra: {'file_size_bytes': result.compressedSizeBytes},
      );
    } on StorageUploadFailure catch (e, st) {
      appLogger.error(
        'AvatarRepositoryImpl: storage upload failed',
        exception: e,
        stackTrace: st,
      );
      appLogger.info(
        AnalyticsEvents.avatarUploadFailed,
        extra: {'reason': 'storage_error'},
      );
      rethrow;
    }
  }

  @override
  Stream<List<int>?> watchLocalPreviewBytes(String uid) =>
      _avatarDatasource.watchLocalPreviewBytes(uid);

  @override
  Stream<double?> watchUploadProgress(String uid) =>
      _avatarDatasource.watchUploadProgress(uid);
}
