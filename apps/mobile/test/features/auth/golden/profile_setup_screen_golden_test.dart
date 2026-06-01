import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_state.dart';
import 'package:mobile/features/auth/presentation/providers/auth_state_notifier_provider.dart';
import 'package:mobile/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';

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

Widget _buildScreen(double textScale) {
  return ProviderScope(
    overrides: [
      authStateNotifierProvider.overrideWith(
        () => _StubNotifier(
          const AsyncValue.data(AuthState.pendingProfileSetup()),
        ),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('th'),
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
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: const ProfileSetupScreen(),
      ),
    ),
  );
}

void main() {
  group('ProfileSetupScreen golden', () {
    testWidgets('scale 1.0 — th locale', (tester) async {
      await tester.pumpWidget(_buildScreen(1.0));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(ProfileSetupScreen),
        matchesGoldenFile('goldens/profile_setup_screen_scale_1.0_th.png'),
      );
    });

    testWidgets('scale 1.5 — th locale', (tester) async {
      await tester.pumpWidget(_buildScreen(1.5));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(ProfileSetupScreen),
        matchesGoldenFile('goldens/profile_setup_screen_scale_1.5_th.png'),
      );
    });
  });
}
