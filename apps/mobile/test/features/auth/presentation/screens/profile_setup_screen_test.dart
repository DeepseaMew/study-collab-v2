import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/auth_failure.dart';
import 'package:mobile/features/auth/domain/entities/auth_state.dart';
import 'package:mobile/features/auth/presentation/providers/auth_state_notifier_provider.dart';
import 'package:mobile/features/auth/presentation/screens/profile_setup_screen.dart';

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
    return const AuthState.pendingProfileSetup();
  }
}

Widget _buildScreen(AsyncValue<AuthState> preset) {
  return ProviderScope(
    overrides: [
      authStateNotifierProvider.overrideWith(() => _StubNotifier(preset)),
    ],
    child: const MaterialApp(home: ProfileSetupScreen()),
  );
}

void main() {
  testWidgets('renders without exception', (tester) async {
    await tester.pumpWidget(
      _buildScreen(const AsyncValue.data(AuthState.pendingProfileSetup())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set up your profile'), findsOneWidget);
  });

  testWidgets('faculty dropdown is present', (tester) async {
    await tester.pumpWidget(
      _buildScreen(const AsyncValue.data(AuthState.pendingProfileSetup())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Faculty'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is DropdownButtonFormField),
      findsOneWidget,
    );
  });

  testWidgets('Save and continue button is present', (tester) async {
    await tester.pumpWidget(
      _buildScreen(const AsyncValue.data(AuthState.pendingProfileSetup())),
    );
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(ElevatedButton, 'Save and continue'),
      findsOneWidget,
    );
  });

  testWidgets('error banner appears when notifier emits failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildScreen(
        const AsyncValue.error(
          AuthFailure.unknownFailure('Profile update failed'),
          StackTrace.empty,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile update failed'), findsOneWidget);
  });
}
