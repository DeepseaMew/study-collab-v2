import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/firestore_paths.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/profile/data/models/user_model.dart';

/// Firestore data source for user profile documents.
class ProfileDatasource {
  const ProfileDatasource(this._firestore);

  /// Creates a [ProfileDatasource] wired to the default [FirebaseFirestore]
  /// instance. Use this factory from `@riverpod` repository providers so that
  /// presentation-layer files do not need to import `cloud_firestore` directly.
  factory ProfileDatasource.withDefaultFirestore() =>
      ProfileDatasource(FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;

  /// Streams the `users/{uid}` document as a [UserModel].
  /// Emits `null` when the document does not exist.
  Stream<UserModel?> watchUser(String uid) {
    return _firestore
        .doc(FirestorePaths.userDoc(uid))
        .snapshots()
        .map((snap) {
          if (!snap.exists || snap.data() == null) return null;
          try {
            final data = Map<String, dynamic>.from(snap.data()!);
            // Inject the document ID as uid since it is the canonical uid.
            data['uid'] = uid;
            return UserModel.fromJson(data);
          } on FirebaseException catch (e, st) {
            appLogger.error(
              'ProfileDatasource.watchUser parse error',
              exception: e,
              stackTrace: st,
            );
            throw DataException('Failed to parse user document: ${e.code}');
          } catch (e, st) {
            appLogger.error(
              'ProfileDatasource.watchUser unexpected error',
              exception: e,
              stackTrace: st,
            );
            throw const DataException('Failed to parse user document');
          }
        });
  }

  /// Merges [updates] into `users/{uid}`, appending a server-side timestamp.
  Future<void> updateProfile(String uid, Map<String, dynamic> updates) async {
    try {
      final payload = Map<String, dynamic>.from(updates);
      payload['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore
          .doc(FirestorePaths.userDoc(uid))
          .set(payload, SetOptions(merge: true));
    } on FirebaseException catch (e, st) {
      appLogger.error(
        'ProfileDatasource.updateProfile failed',
        exception: e,
        stackTrace: st,
      );
      throw DataException('Failed to update profile: ${e.code}');
    }
  }
}
