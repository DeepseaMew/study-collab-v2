import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile/core/firestore_paths.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'current_user_provider.g.dart';

/// Provides the currently authenticated [UserEntity], or `null` when signed out.
///
/// This provider is permitted to import `firebase_auth` as it is the
/// designated auth-state provider per ADR 0002 Amendment 2.
@riverpod
Stream<UserEntity?> currentUser(CurrentUserRef ref) {
  final authStateStream = FirebaseAuth.instance.authStateChanges();

  return authStateStream.asyncExpand((user) {
    if (user == null) {
      return Stream.value(null);
    }

    final uid = user.uid;
    return FirebaseFirestore.instance
        .doc(FirestorePaths.userDoc(uid))
        .snapshots()
        .map((snap) {
          if (!snap.exists || snap.data() == null) return null;
          try {
            final data = snap.data()!;
            return UserEntity(
              uid: uid,
              displayName: (data['displayName'] as String?) ?? '',
              fullName: (data['fullName'] as String?) ?? '',
              email: (data['email'] as String?) ?? '',
              photoUrl: data['photoUrl'] as String?,
              hasHostedBefore: (data['hasHostedBefore'] as bool?) ?? false,
              studentYear: (data['studentYear'] as int?) ?? 1,
              academicLevel:
                  (data['academicLevel'] as String?) ?? 'undergraduate',
              faculty: (data['faculty'] as String?) ?? '',
              bio: data['bio'] as String?,
              profileScore:
                  ((data['profileScore'] as num?) ?? 0.0).toDouble(),
            );
          } catch (e, st) {
            appLogger.error(
              'Failed to parse current user document',
              exception: e,
              stackTrace: st,
            );
            return null;
          }
        });
  });
}
