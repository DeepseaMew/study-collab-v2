import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_state.dart';
import 'package:mobile/features/auth/presentation/providers/auth_state_notifier_provider.dart';
import 'package:mobile/shared/screens/home_placeholder_screen.dart';

// Minimal stub — holds state without real Firebase.
class _StubNotifier extends AuthStateNotifier {
  @override
  Future<AuthState> build() async {
    state = const AsyncValue.data(AuthState.authenticated());
    return const AuthState.authenticated();
  }

  @override
  Future<void> signOut() async {
    // no-op in widget tests
  }
}

Widget _buildScreen() {
  return ProviderScope(
    overrides: [authStateNotifierProvider.overrideWith(() => _StubNotifier())],
    child: const MaterialApp(home: HomePlaceholderScreen()),
  );
}

void main() {
  testWidgets('renders Scaffold with Home title text', (tester) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Scaffold must be present.
    expect(find.byType(Scaffold), findsOneWidget);

    // The body centre text 'Home' must be visible.
    // There are two 'Home' text nodes (AppBar title + body centre);
    // findsWidgets asserts at least one.
    expect(find.text('Home'), findsWidgets);
  });

  testWidgets('Sign out button is present', (tester) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.widgetWithText(TextButton, 'Sign out'), findsOneWidget);
  });
}
