import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/auth_failure.dart';
import 'package:mobile/features/auth/domain/entities/auth_state.dart';
import 'package:mobile/features/auth/presentation/providers/auth_state_notifier_provider.dart';
import 'package:mobile/features/auth/presentation/screens/sign_in_screen.dart';

// Notifier stub — controls state without real Firebase.
class _StubNotifier extends AuthStateNotifier {
  _StubNotifier(this._preset);
  final AsyncValue<AuthState> _preset;

  @override
  Future<AuthState> build() async {
    state = _preset;
    if (_preset.hasValue) return _preset.requireValue;
    if (_preset.hasError) {
      Error.throwWithStackTrace(_preset.error!, _preset.stackTrace!);
    }
    return const AuthState.unauthenticated();
  }
}

Widget _buildScreen(AsyncValue<AuthState> preset) {
  return ProviderScope(
    overrides: [
      authStateNotifierProvider.overrideWith(() => _StubNotifier(preset)),
    ],
    child: const MaterialApp(home: SignInScreen()),
  );
}

void main() {
  testWidgets('renders without exception', (tester) async {
    await tester.pumpWidget(
      _buildScreen(const AsyncValue.data(AuthState.unauthenticated())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back!'), findsOneWidget);
  });

  testWidgets('primary Sign In button is present', (tester) async {
    await tester.pumpWidget(
      _buildScreen(const AsyncValue.data(AuthState.unauthenticated())),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
  });

  testWidgets('error banner appears on InvalidCredentials failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildScreen(
        const AsyncValue.error(
          AuthFailure.invalidCredentials(),
          StackTrace.empty,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password.'), findsOneWidget);
  });

  testWidgets('Create Account link is present', (tester) async {
    await tester.pumpWidget(
      _buildScreen(const AsyncValue.data(AuthState.unauthenticated())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create Account'), findsOneWidget);
  });

  group('accessibility', () {
    // Known gaps (tracked for next sprint):
    //   androidTapTargetGuideline — "Create Account" text link renders at
    //     22dp height; needs a minimum 48dp tap target.
    //   labeledTapTargetGuideline — password-visibility suffix icon has no
    //     semantic label.
    testWidgets('meets WCAG AA text contrast guideline', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _buildScreen(const AsyncValue.data(AuthState.unauthenticated())),
      );
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });
}
