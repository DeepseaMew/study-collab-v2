// Widget tests for SettingsScreen.
//
// Tests:
//   1. Smoke test — renders without error.
//   2. Profile section shows display name.
//   3. Exactly 4 notification toggle tiles are present (by SwitchListTile).
//   4. "Session Reminders" text is absent.
//   5. "Coming soon" is absent from the notification section.
//   6. Master toggle off visually disables the other 3 sub-toggles.
//   7. Sign Out tile is present.

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
  String get uid => 'test-uid-1';
  @override
  String? get displayName => 'Test User';
  @override
  String? get email => 'test@mail.kmutt.ac.th';
}

// ── Default prefs ─────────────────────────────────────────────────────────────

const _defaultPrefs = <String, bool>{
  'allNotifications': true,
  'joinRequestAlerts': true,
  'friendRequests': true,
  'ratingAvailable': true,
};

const _masterOffPrefs = <String, bool>{
  'allNotifications': false,
  'joinRequestAlerts': false,
  'friendRequests': false,
  'ratingAvailable': false,
};

// ── Stub notifier ─────────────────────────────────────────────────────────────

class _StubPrefsNotifier extends NotificationPreferencesNotifier {
  _StubPrefsNotifier(this._prefs);
  final Map<String, bool> _prefs;

  @override
  Future<Map<String, bool>> build() async => _prefs;
}

// ── Screen builder ────────────────────────────────────────────────────────────

Widget _buildScreen({
  Map<String, bool> prefs = _defaultPrefs,
  UserEntity? user,
}) {
  final resolvedUser =
      user ??
      const UserEntity(
        uid: 'test-uid-1',
        displayName: 'Alice Tester',
        fullName: 'Alice Full Tester',
        email: 'alice@mail.kmutt.ac.th',
        hasHostedBefore: false,
        studentYear: 2,
        academicLevel: 'undergraduate',
        faculty: 'Engineering',
        profileScore: 0.0,
      );

  return ProviderScope(
    overrides: [
      // Auth state — logged in as test-uid-1.
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser()),
      ),
      // User profile.
      userProvider(
        'test-uid-1',
      ).overrideWith((_) => Stream.value(resolvedUser)),
      // Notification preferences.
      notificationPreferencesNotifierProvider.overrideWith(
        () => _StubPrefsNotifier(prefs),
      ),
      // Auth notifier — not exercised in these widget tests.
      authStateNotifierProvider.overrideWith(
        () => throw UnimplementedError('not needed'),
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
      home: const SettingsScreen(),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('SettingsScreen', () {
    testWidgets('smoke test — renders without error', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.byType(SettingsScreen), findsOneWidget);
      });
    });

    testWidgets('profile section shows the user display name', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.text('Alice Tester'), findsWidgets);
      });
    });

    testWidgets('exactly 4 SwitchListTile notification toggles are present', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.byType(SwitchListTile), findsNWidgets(4));
      });
    });

    testWidgets('toggle labels match ADR 0013 specification', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.text('All Notifications'), findsOneWidget);
        expect(find.text('Join Request Alerts'), findsOneWidget);
        expect(find.text('Friend Requests'), findsOneWidget);
        expect(find.text('Rating Available'), findsOneWidget);
      });
    });

    testWidgets('"Session Reminders" text is absent', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.text('Session Reminders'), findsNothing);
      });
    });

    testWidgets('"Coming soon" is absent', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.textContaining('coming soon'), findsNothing);
        expect(find.textContaining('Coming soon'), findsNothing);
      });
    });

    testWidgets(
      'master toggle off — sub-toggles are rendered as disabled (onChanged == null)',
      (tester) async {
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(_buildScreen(prefs: _masterOffPrefs));
          await tester.pumpAndSettle(const Duration(seconds: 3));

          // All 4 SwitchListTiles should be rendered.
          final tiles = tester.widgetList<SwitchListTile>(
            find.byType(SwitchListTile),
          );
          final tileList = tiles.toList();
          expect(tileList, hasLength(4));

          // The master toggle (index 0) has onChanged == null because the
          // Semantics wrapper uses the prefKey-driven toggle logic. All 4 are
          // off when masterOff, and the 3 sub-toggles have enabled: false,
          // which maps to onChanged == null in SwitchListTile.
          // Verify all 3 sub-toggles are disabled.
          final subTiles = tileList.skip(1).toList();
          for (final tile in subTiles) {
            expect(
              tile.onChanged,
              isNull,
              reason:
                  'Sub-toggle should be disabled (onChanged == null) when master is off',
            );
          }
        });
      },
    );

    testWidgets('Sign Out tile is present', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.text('Sign Out'), findsOneWidget);
      });
    });

    testWidgets('profile section heading is visible', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.text('Profile'), findsOneWidget);
      });
    });

    testWidgets('Notifications section heading is visible', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.text('Notifications'), findsWidgets);
      });
    });

    testWidgets('Account section heading is visible', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.text('Account'), findsOneWidget);
      });
    });
  });
}
