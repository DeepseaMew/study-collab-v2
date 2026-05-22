// Widget tests for CalendarSyncSettingsScreen.
//
// Production state: FeatureFlags.gcalSyncEnabled == false.
// When the flag is false the screen renders a "Coming soon" placeholder.
// The enabled path is NOT tested because the flag is false in production.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/presentation/screens/calendar_sync_settings_screen.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';

// ── Widget builder ────────────────────────────────────────────────────────────

/// Renders [CalendarSyncSettingsScreen] inside a minimal [MaterialApp] and
/// [ProviderScope]. No provider overrides are needed because when
/// [FeatureFlags.gcalSyncEnabled] is false the screen never reads
/// [calendarSyncNotifierProvider].
Widget _buildScreen() {
  return ProviderScope(
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
      home: const CalendarSyncSettingsScreen(),
    ),
  );
}

void main() {
  group('CalendarSyncSettingsScreen — gcalSyncEnabled: false (feature flag off)',
      () {
    testWidgets('renders without error (smoke test)', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(CalendarSyncSettingsScreen), findsOneWidget);
    });

    testWidgets('shows app bar with "Google Calendar Sync" title',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('Google Calendar Sync'), findsOneWidget);
    });

    testWidgets('shows "Coming soon" body text', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('Coming soon'), findsOneWidget);
    });

    testWidgets('does NOT show Connect Google Calendar button', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('Connect Google Calendar'), findsNothing);
    });

    testWidgets('does NOT show Disconnect button', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('Disconnect'), findsNothing);
    });

    testWidgets('does NOT show Sync Now button', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('Sync Now'), findsNothing);
    });

    testWidgets('renders a Scaffold as root widget', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('"Coming soon" text is centred in the body', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));
      // The body is a Center widget wrapping the Text.
      expect(find.byType(Center), findsWidgets);
      expect(find.text('Coming soon'), findsOneWidget);
    });
  });
}
