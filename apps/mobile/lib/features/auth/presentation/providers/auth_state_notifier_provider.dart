import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile/core/analytics_events.dart';
import 'package:mobile/core/errors/auth_failure.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/auth/data/datasources/auth_datasource.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/entities/auth_state.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/domain/usecases/reload_user_use_case.dart';
import 'package:mobile/features/auth/domain/usecases/sign_in_use_case.dart';
import 'package:mobile/features/auth/domain/usecases/sign_out_use_case.dart';
import 'package:mobile/features/auth/domain/usecases/sign_up_use_case.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_state_notifier_provider.g.dart';

// ── Dependency injection ──────────────────────────────────────────────────────

@riverpod
AuthDatasource _authDatasource(_AuthDatasourceRef ref) {
  return AuthDatasource(
    auth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
  );
}

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepositoryImpl(ref.watch(_authDatasourceProvider));
}

// ── User profile provider ─────────────────────────────────────────────────────

/// Fetches the stored Firestore profile fields for the currently signed-in user.
/// Returns an empty map when no user is signed in or the document is absent.
@riverpod
Future<Map<String, dynamic>> userProfile(UserProfileRef ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return {};
  return ref.read(authRepositoryProvider).getUserProfile(user.uid);
}

// ── Auth state notifier ───────────────────────────────────────────────────────

@riverpod
class AuthStateNotifier extends _$AuthStateNotifier {
  @override
  Future<AuthState> build() async {
    // Watching the Firebase stream: build() re-runs on every auth state change.
    final user = await ref.watch(firebaseAuthStateProvider.future);

    if (user == null) return const AuthState.unauthenticated();
    if (!user.emailVerified) return const AuthState.unverified();

    final repo = ref.read(authRepositoryProvider);
    return repo.getAuthState();
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
      await SignInUseCase(
        ref.read(authRepositoryProvider),
      ).execute(email: email, password: password);
      appLogger.info('${AnalyticsEvents.authSignInCompleted} event fired');
      // Firebase stream triggers build() → state updated automatically.
    } on AuthFailure catch (e, st) {
      state = AsyncValue.error(e, st);
    } catch (e, st) {
      state = AsyncValue.error(const AuthFailure.unknownFailure(), st);
    }
  }

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    appLogger.info('${AnalyticsEvents.authSignUpStarted} event fired');
    try {
      await SignUpUseCase(
        ref.read(authRepositoryProvider),
      ).execute(fullName: fullName, email: email, password: password);
      appLogger.info('${AnalyticsEvents.authSignUpCompleted} event fired');
      // Firebase stream triggers build() → state updated automatically.
    } on AuthFailure catch (e, st) {
      state = AsyncValue.error(e, st);
    } catch (e, st) {
      state = AsyncValue.error(const AuthFailure.unknownFailure(), st);
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await SignOutUseCase(ref.read(authRepositoryProvider)).execute();
      appLogger.info('${AnalyticsEvents.authSignOut} event fired');
      // Firebase stream triggers build() → state = unauthenticated.
    } on AuthFailure catch (e, st) {
      state = AsyncValue.error(e, st);
    } catch (e, st) {
      state = AsyncValue.error(const AuthFailure.unknownFailure(), st);
    }
  }

  Future<void> reloadUser() async {
    state = const AsyncValue.loading();
    try {
      await ReloadUserUseCase(ref.read(authRepositoryProvider)).execute();
      // authStateChanges() may not emit on emailVerified change alone;
      // invalidating forces build() to re-check Firestore.
      ref.invalidateSelf();
    } on AuthFailure catch (e, st) {
      state = AsyncValue.error(e, st);
    } catch (e, st) {
      state = AsyncValue.error(const AuthFailure.unknownFailure(), st);
    }
  }

  Future<void> resendVerificationEmail() async {
    try {
      await ref.read(authRepositoryProvider).resendVerificationEmail();
      appLogger.info('${AnalyticsEvents.authVerifyEmailResend} event fired');
    } on AuthFailure catch (e, st) {
      state = AsyncValue.error(e, st);
    } catch (e, st) {
      state = AsyncValue.error(const AuthFailure.unknownFailure(), st);
    }
  }

  Future<void> updateProfile({
    required String displayName,
    required String faculty,
    required String bio,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      await ref
          .read(authRepositoryProvider)
          .updateProfile(
            uid: user.uid,
            displayName: displayName,
            faculty: faculty,
            bio: bio,
          );
      appLogger.info(
        '${AnalyticsEvents.authProfileSetupCompleted} event fired',
      );
      // Faculty is now non-empty; invalidate to re-check Firestore.
      ref.invalidateSelf();
    } on AuthFailure catch (e, st) {
      state = AsyncValue.error(e, st);
    } catch (e, st) {
      state = AsyncValue.error(const AuthFailure.unknownFailure(), st);
    }
  }
}
