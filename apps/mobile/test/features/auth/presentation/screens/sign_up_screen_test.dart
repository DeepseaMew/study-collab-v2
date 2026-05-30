import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/auth_failure.dart';
import 'package:mobile/features/auth/domain/entities/auth_state.dart';
import 'package:mobile/features/auth/presentation/providers/auth_state_notifier_provider.dart';
import 'package:mobile/features/auth/presentation/screens/sign_up_screen.dart';

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
    child: const MaterialApp(home: SignUpScreen()),
  );
}

void main() {
  testWidgets('renders without exception', (tester) async {
    await tester.pumpWidget(
      _buildScreen(const AsyncValue.data(AuthState.unauthenticated())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create Account'), findsWidgets);
  });

  testWidgets('primary Create Account button is present', (tester) async {
    await tester.pumpWidget(
      _buildScreen(const AsyncValue.data(AuthState.unauthenticated())),
    );
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(ElevatedButton, 'Create Account'),
      findsOneWidget,
    );
  });

  testWidgets('error banner appears on KmuttDomainRejected failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildScreen(
        const AsyncValue.error(
          AuthFailure.kmuttDomainRejected(),
          StackTrace.empty,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Only KMUTT email addresses are allowed.'),
      findsOneWidget,
    );
  });

  testWidgets('Full name field is present', (tester) async {
    await tester.pumpWidget(
      _buildScreen(const AsyncValue.data(AuthState.unauthenticated())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Full name'), findsOneWidget);
  });
}
