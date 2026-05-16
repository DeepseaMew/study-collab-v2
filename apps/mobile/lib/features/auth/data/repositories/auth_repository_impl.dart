import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/errors/auth_failure.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/auth/data/datasources/auth_datasource.dart';
import 'package:mobile/features/auth/domain/entities/auth_state.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

const _kmuttRegex = r'^[^@]+@(mail\.kmutt\.ac\.th|kmutt\.ac\.th)$';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._datasource);

  final AuthDatasource _datasource;

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _datasource.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      appLogger.info('Sign-in completed');
    } on FirebaseAuthException catch (e, st) {
      appLogger.error('Sign-in failed', exception: e.code, stackTrace: st);
      throw _mapFirebaseException(e);
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
    // Client-side KMUTT domain gate — defence-in-depth before Firebase call.
    if (!RegExp(_kmuttRegex).hasMatch(email)) {
      appLogger.warning(
        'Sign-up rejected: non-KMUTT domain',
        extra: {'event': AnalyticsEvents.authKmuttDomainRejected},
      );
      throw const AuthFailure.kmuttDomainRejected();
    }

    try {
      final credential = await _datasource.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;
      await _datasource.createUserDocument(
        uid: uid,
        fullName: fullName,
        email: email,
      );

      await _datasource.sendEmailVerification();
      appLogger.info('Sign-up completed — verification email sent');
    } on FirebaseAuthException catch (e, st) {
      appLogger.error('Sign-up failed', exception: e.code, stackTrace: st);
      throw _mapFirebaseException(e);
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
    } on FirebaseAuthException catch (e, st) {
      appLogger.error('Reload user failed', exception: e.code, stackTrace: st);
      throw _mapFirebaseException(e);
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
  Future<void> resendVerificationEmail() async {
    try {
      await _datasource.sendEmailVerification();
      appLogger.info('Verification email resent');
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
    final user = _datasource.currentUser;
    if (user == null) return const AuthState.unauthenticated();
    if (!user.emailVerified) return const AuthState.unverified();

    try {
      final doc = await _datasource.getUserDocument(user.uid);
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

  AuthFailure _mapFirebaseException(FirebaseAuthException e) {
    return switch (e.code) {
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' ||
      'invalid-email' => const AuthFailure.invalidCredentials(),
      'network-request-failed' => const AuthFailure.networkFailure(),
      'email-already-in-use' => const AuthFailure.unknownFailure(
        'An account with this email already exists.',
      ),
      _ => const AuthFailure.unknownFailure(),
    };
  }
}
