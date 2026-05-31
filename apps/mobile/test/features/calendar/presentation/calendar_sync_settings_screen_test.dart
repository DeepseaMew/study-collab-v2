// Widget tests for CalendarSyncSettingsScreen.
//
// Production state: FeatureFlags.gcalSyncEnabled == true.
// The screen renders the full sync UI. The initial notifier state is
// AsyncData(null) (disconnected), so the Connect button is shown by default.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/presentation/screens/calendar_sync_settings_screen.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';

// ── Widget builder ────────────────────────────────────────────────────────────

/// Renders [CalendarSyncSettingsScreen] inside a minimal [MaterialApp] and
/// [ProviderScope]. No provider overrides are needed because the notifier's
/// silent reconnect catches any Firebase-not-initialised error gracefully.
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
  group(
    'CalendarSyncSettingsScreen — gcalSyncEnabled: true (feature flag on)',
    () {
      testWidgets('renders without error (smoke test)', (tester) async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.byType(CalendarSyncSettingsScreen), findsOneWidget);
      });

      testWidgets('shows app bar with "Google Calendar Sync" title', (
        tester,
      ) async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('Google Calendar Sync'), findsOneWidget);
      });

      testWidgets('does NOT show "Coming soon" placeholder text', (
        tester,
      ) async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('Coming soon'), findsNothing);
      });

      testWidgets('shows Connect Google Calendar button when disconnected', (
        tester,
      ) async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 3));
        // Initial state is AsyncData(null) → disconnected → Connect button shown.
        expect(find.text('Connect Google Calendar'), findsOneWidget);
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

      testWidgets('shows ListView body (sync settings list) when enabled', (
        tester,
      ) async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.byType(ListView), findsOneWidget);
      });
    },
  );
}
