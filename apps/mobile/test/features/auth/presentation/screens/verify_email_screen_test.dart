import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_state.dart';
import 'package:mobile/features/auth/presentation/providers/auth_state_notifier_provider.dart';
import 'package:mobile/features/auth/presentation/screens/verify_email_screen.dart';

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
    return const AuthState.unverified();
  }
}

Widget _buildScreen(AsyncValue<AuthState> preset) {
  return ProviderScope(
    overrides: [
      authStateNotifierProvider.overrideWith(() => _StubNotifier(preset)),
    ],
    child: const MaterialApp(home: VerifyEmailScreen()),
  );
}

void main() {
  testWidgets('renders without exception', (tester) async {
    await tester.pumpWidget(
      _buildScreen(const AsyncValue.data(AuthState.unverified())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Verify your email'), findsOneWidget);
  });

  testWidgets('primary tap-to-continue button is present', (tester) async {
    await tester.pumpWidget(
      _buildScreen(const AsyncValue.data(AuthState.unverified())),
    );
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(ElevatedButton, "I've verified my email"),
      findsOneWidget,
    );
  });

  testWidgets('Resend email button is present', (tester) async {
    await tester.pumpWidget(
      _buildScreen(const AsyncValue.data(AuthState.unverified())),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Resend email'), findsOneWidget);
  });
}
