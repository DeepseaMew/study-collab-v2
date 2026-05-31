// Golden tests for SettingsScreen.
//
// Generates 2 goldens:
//   - settings_screen_1_0.png  (text scale 1.0)
//   - settings_screen_1_5.png  (text scale 1.5)
//
// Re-generate with:
//   flutter test --update-goldens test/features/settings/presentation/settings_screen_golden_test.dart
//
// Fixed locale: th  Fixed theme: AppColors + AppTypography  (per QA rules)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/auth_state_notifier_provider.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/notifications/presentation/providers/notification_preferences_provider.dart';
import 'package:mobile/features/profile/presentation/providers/user_provider.dart';
import 'package:mobile/features/settings/presentation/screens/settings_screen.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeFirebaseUser extends Fake implements User {
  @override
  String get uid => 'golden-uid';
  @override
  String? get displayName => 'Golden User';
  @override
  String? get email => 'golden@mail.kmutt.ac.th';
}

// ── Stub notifier ─────────────────────────────────────────────────────────────

class _StubPrefsNotifier extends NotificationPreferencesNotifier {
  @override
  Future<Map<String, bool>> build() async => const {
    'allNotifications': true,
    'joinRequestAlerts': true,
    'friendRequests': true,
    'ratingAvailable': true,
  };
}

// ── Screen builder ────────────────────────────────────────────────────────────

Widget _buildScreen(double textScale) {
  const user = UserEntity(
    uid: 'golden-uid',
    displayName: 'Golden User',
    fullName: 'Golden Full User',
    email: 'golden@mail.kmutt.ac.th',
    hasHostedBefore: false,
    studentYear: 1,
    academicLevel: 'undergraduate',
    faculty: 'Engineering',
    profileScore: 0.0,
  );

  return ProviderScope(
    overrides: [
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser()),
      ),
      userProvider('golden-uid').overrideWith((_) => Stream.value(user)),
      notificationPreferencesNotifierProvider.overrideWith(
        () => _StubPrefsNotifier(),
      ),
      authStateNotifierProvider.overrideWith(
        () => throw UnimplementedError('not needed in golden'),
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
        child: const SettingsScreen(),
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('SettingsScreen golden', () {
    testWidgets('scale 1.0 — th locale', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(1.0));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await expectLater(
          find.byType(SettingsScreen),
          matchesGoldenFile('goldens/settings_screen_1_0.png'),
        );
      });
    });

    testWidgets('scale 1.5 — th locale', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(1.5));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await expectLater(
          find.byType(SettingsScreen),
          matchesGoldenFile('goldens/settings_screen_1_5.png'),
        );
      });
    });
  });
}
