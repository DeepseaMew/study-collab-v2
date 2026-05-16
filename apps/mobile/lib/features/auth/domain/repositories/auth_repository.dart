import 'package:mobile/features/auth/domain/entities/auth_state.dart';

abstract interface class AuthRepository {
  Future<void> signIn({required String email, required String password});

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<void> reloadUser();

  Future<void> updateProfile({
    required String uid,
    required String displayName,
    required String faculty,
    required String bio,
  });

  Future<void> resendVerificationEmail();

  /// Returns the current [AuthState] by reading Firebase Auth + Firestore.
  /// Used by [AuthStateNotifier.build] after stream events and explicit reloads.
  Future<AuthState> getAuthState();

  /// Returns the stored profile fields for [uid] from Firestore.
  /// Returns an empty map if the document does not exist.
  /// Keys: `displayName` (String), `bio` (String).
  Future<Map<String, dynamic>> getUserProfile(String uid);
}
