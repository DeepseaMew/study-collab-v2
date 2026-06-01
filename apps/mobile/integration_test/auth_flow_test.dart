import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_state.dart';
import 'package:mobile/features/auth/presentation/providers/auth_state_notifier_provider.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';

// Controllable stub that lets the test drive auth state transitions.
class _ControllableNotifier extends AuthStateNotifier {
  _ControllableNotifier(AsyncValue<AuthState> initialState)
    : _current = initialState;

  AsyncValue<AuthState> _current;

  @override
  Future<AuthState> build() async {
    state = _current;
    if (_current.hasValue) return _current.requireValue;
    if (_current.hasError) {
      Error.throwWithStackTrace(_current.error!, _current.stackTrace!);
    }
    return const AuthState.unauthenticated();
  }

  void forceState(AsyncValue<AuthState> next) {
    _current = next;
    state = next;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late _ControllableNotifier notifier;

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        authStateNotifierProvider.overrideWith(() {
          notifier = _ControllableNotifier(
            const AsyncValue.data(AuthState.unauthenticated()),
          );
          return notifier;
        }),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          return MaterialApp.router(
            title: 'Study Collab Test',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.accent,
                primary: AppColors.accent,
                error: AppColors.error,
                surface: AppColors.background,
              ),
              textTheme: AppTypography.textTheme,
              useMaterial3: true,
            ),
            routerConfig: ref.watch(routerProvider),
          );
        },
      ),
    );
  }

  testWidgets('auth flow: unauthenticated → sign-in; '
      'unverified → verify-email; '
      'pendingProfileSetup → profile-setup; '
      'authenticated → home', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // 1. Unauthenticated → router should show /sign-in.
    expect(find.text('Welcome back!'), findsOneWidget);

    // 2. Transition to unverified (sign-up completed).
    notifier.forceState(const AsyncValue.data(AuthState.unverified()));
    await tester.pumpAndSettle();

    expect(find.text('Verify your email'), findsOneWidget);

    // 3. Transition to pendingProfileSetup (email verified).
    notifier.forceState(const AsyncValue.data(AuthState.pendingProfileSetup()));
    await tester.pumpAndSettle();

    expect(find.text('Set up your profile'), findsOneWidget);

    // 4. Transition to authenticated (profile complete).
    notifier.forceState(const AsyncValue.data(AuthState.authenticated()));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);

    // 5. Sign out → back to unauthenticated.
    notifier.forceState(const AsyncValue.data(AuthState.unauthenticated()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back!'), findsOneWidget);
  });
}
