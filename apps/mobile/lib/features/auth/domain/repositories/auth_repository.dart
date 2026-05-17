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

  /// Creates the Firestore user document and sets the profile fields in one
  /// atomic two-step operation. Must only be called after email verification
  /// is confirmed (i.e. from the profile-setup completion handler).
  ///
  /// Internally:
  ///   1. Creates the document stub (all required fields, `faculty = ''`).
  ///   2. Updates `displayName`, `faculty`, and `bio` to the supplied values.
  Future<void> completeProfileSetup({
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

  /// Returns the UID of the currently signed-in Firebase user, or `null`
  /// when no user is signed in. Exposes Firebase Auth state without leaking
  /// Firebase types into callers — the UID is plain Dart [String].
  String? get currentUser;

  /// Returns whether the current Firebase Auth user's email has been verified.
  /// Reads the live [User] object; does not make a network call.
  bool get isEmailVerified;
}
