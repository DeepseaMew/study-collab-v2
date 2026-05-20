import 'package:mobile/features/auth/domain/entities/user_entity.dart';

/// Domain repository interface for user profile data.
///
/// Zero Flutter or Firebase imports — pure Dart.
abstract interface class UserRepository {
  /// Returns a stream of the user document identified by [uid].
  /// Emits `null` when the document does not exist.
  Stream<UserEntity?> watchUser(String uid);

  /// Merges [updates] into the `users/{uid}` document.
  /// The `updatedAt` field is automatically set server-side.
  Future<void> updateProfile(String uid, Map<String, dynamic> updates);
}
