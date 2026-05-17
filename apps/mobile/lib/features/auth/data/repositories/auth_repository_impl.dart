import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/errors/auth_failure.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/core/validators/kmutt_email.dart';
import 'package:mobile/features/auth/data/datasources/auth_datasource.dart';
import 'package:mobile/features/auth/domain/entities/auth_state.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._datasource);

  final AuthDatasource _datasource;

  @override
  String? get currentUser => _datasource.currentUserUid;

  @override
  bool get isEmailVerified => _datasource.currentUserEmailVerified;

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _datasource.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      appLogger.info('Sign-in completed');
    } on AuthFailure {
      rethrow;
    } catch (e, st) {
      appLogger.error('Sign-in unexpected error', exception: e, stackTrace: st);
      throw const AuthFailure.unknownFailure();
    }
  }

  @override
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    // Trim before the KMUTT domain guard — defence against leading/trailing whitespace.
    final trimmedEmail = email.trim();

    // Client-side KMUTT domain gate — defence-in-depth before Firebase call.
    if (!RegExp(kmuttEmailPattern).hasMatch(trimmedEmail)) {
      appLogger.warning(
        'Sign-up rejected: non-KMUTT domain',
        extra: {'event': AnalyticsEvents.authKmuttDomainRejected},
      );
      throw const AuthFailure.kmuttDomainRejected();
    }

    try {
      await _datasource.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      // Store fullName on the Firebase Auth user so it is available when the
      // Firestore document is created post-verification in completeProfileSetup.
      await _datasource.updateDisplayName(fullName);

      await _datasource.sendEmailVerification();
      appLogger.info('Sign-up completed — verification email sent');
    } on AuthFailure {
      rethrow;
    } catch (e, st) {
      appLogger.error('Sign-up unexpected error', exception: e, stackTrace: st);
      throw const AuthFailure.unknownFailure();
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _datasource.signOut();
      appLogger.info('Sign-out completed');
    } on AuthFailure {
      rethrow;
    } catch (e, st) {
      appLogger.error('Sign-out failed', exception: e, stackTrace: st);
      throw const AuthFailure.unknownFailure();
    }
  }

  @override
  Future<void> reloadUser() async {
    try {
      await _datasource.reloadCurrentUser();
      appLogger.info('User reloaded');
    } on AuthFailure {
      rethrow;
    } catch (e, st) {
      appLogger.error(
        'Reload user unexpected error',
        exception: e,
        stackTrace: st,
      );
      throw const AuthFailure.unknownFailure();
    }
  }

  @override
  Future<void> updateProfile({
    required String uid,
    required String displayName,
    required String faculty,
    required String bio,
  }) async {
    try {
      await _datasource.updateUserDocument(
        uid: uid,
        displayName: displayName,
        faculty: faculty,
        bio: bio,
      );
      appLogger.info('Profile update completed');
    } catch (e, st) {
      appLogger.error('Profile update failed', exception: e, stackTrace: st);
      throw const AuthFailure.unknownFailure();
    }
  }

  @override
  Future<void> completeProfileSetup({
    required String displayName,
    required String faculty,
    required String bio,
  }) async {
    final uid = _datasource.currentUserUid;
    if (uid == null) {
      appLogger.error('completeProfileSetup called with no authenticated user');
      throw const AuthFailure.unknownFailure();
    }

    final email = _datasource.currentUserEmail ?? '';
    // fullName was stored on the Firebase Auth user during sign-up via
    // updateDisplayName. Use it as the immutable fullName on the Firestore doc.
    final fullName = _datasource.currentUserDisplayName ?? displayName;

    try {
      // Step 1: create the stub document with all required fields and empty faculty.
      // email_verified == true at this point (router guard ensures profile setup
      // is only reachable after idTokenChanges emits emailVerified = true).
      await _datasource.createUserDocument(
        uid: uid,
        fullName: fullName,
        email: email,
      );

      // Step 2: write the profile fields the user just entered.
      await _datasource.updateUserDocument(
        uid: uid,
        displayName: displayName,
        faculty: faculty,
        bio: bio,
      );

      appLogger.info('Profile setup completed — Firestore document created');
    } on AuthFailure {
      rethrow;
    } catch (e, st) {
      appLogger.error(
        'completeProfileSetup unexpected error',
        exception: e,
        stackTrace: st,
      );
      throw const AuthFailure.unknownFailure();
    }
  }

  @override
  Future<void> resendVerificationEmail() async {
    try {
      await _datasource.sendEmailVerification();
      appLogger.info('Verification email resent');
    } on AuthFailure {
      rethrow;
    } catch (e, st) {
      appLogger.error(
        'Resend verification failed',
        exception: e,
        stackTrace: st,
      );
      throw const AuthFailure.unknownFailure();
    }
  }

  @override
  Future<AuthState> getAuthState() async {
    final uid = _datasource.currentUserUid;
    if (uid == null) return const AuthState.unauthenticated();
    if (!_datasource.currentUserEmailVerified) {
      return const AuthState.unverified();
    }

    try {
      final doc = await _datasource.getUserDocument(uid, forceServer: true);
      if (!doc.exists) return const AuthState.pendingProfileSetup();
      final faculty = (doc.data()?['faculty'] as String?) ?? '';
      if (faculty.isEmpty) return const AuthState.pendingProfileSetup();
      return const AuthState.authenticated();
    } catch (e, st) {
      appLogger.error(
        'getAuthState profile fetch failed',
        exception: e,
        stackTrace: st,
      );
      throw const AuthFailure.unknownFailure();
    }
  }

  @override
  Future<Map<String, dynamic>> getUserProfile(String uid) async {
    try {
      final doc = await _datasource.getUserDocument(uid);
      if (!doc.exists) {
        appLogger.debug('getUserProfile: document not found for uid');
        return {};
      }
      final data = doc.data() ?? {};
      return {
        'displayName': (data['displayName'] as String?) ?? '',
        'bio': (data['bio'] as String?) ?? '',
      };
    } catch (e, st) {
      appLogger.error('getUserProfile failed', exception: e, stackTrace: st);
      throw const AuthFailure.unknownFailure();
    }
  }
}
