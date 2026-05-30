// Golden tests for CalendarScreen.
//
// Covers the monthly view with no day selected (the initial state) at two
// text scales: 1.0 and 1.5 (WCAG dynamic type requirement).
// Locale is fixed to 'th' per CLAUDE.md golden test rules.
// Theme is fixed to app theme.
//
// Regenerate with:
//   flutter test --update-goldens test/features/calendar/presentation/calendar_screen_golden_test.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/calendar/presentation/providers/calendar_sessions_provider.dart';
import 'package:mobile/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeFirebaseUser extends Fake implements User {
  @override
  String get uid => 'golden-uid';
}

// ── Widget builder ────────────────────────────────────────────────────────────

Widget _buildGolden(double textScale) {
  // Fixed window so queries are deterministic.
  const uid = 'golden-uid';
  final windowStart = DateTime(2026, 4);
  final windowEnd = DateTime(2026, 6, 30);

  return ProviderScope(
    overrides: [
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser()),
      ),
      calendarSessionsProvider(
        uid,
        windowStart,
        windowEnd,
      ).overrideWith((_) => Stream.value(const <SessionEntity>[])),
      calendarRepositoryProvider.overrideWith(
        (_) => throw UnimplementedError(),
      ),
      sessionRepositoryProvider.overrideWith((_) => throw UnimplementedError()),
    ],
    child: MaterialApp(
      locale: const Locale('th'),
      debugShowCheckedModeBanner: false,
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
        child: const CalendarScreen(),
      ),
    ),
  );
}

void main() {
  group('CalendarScreen golden — no day selected', () {
    testWidgets('scale 1.0 — th locale', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildGolden(1.0));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await expectLater(
          find.byType(CalendarScreen),
          matchesGoldenFile(
            'goldens/calendar_screen_no_day_selected_scale_1.0_th.png',
          ),
        );
      });
    });

    testWidgets('scale 1.5 — th locale', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildGolden(1.5));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await expectLater(
          find.byType(CalendarScreen),
          matchesGoldenFile(
            'goldens/calendar_screen_no_day_selected_scale_1.5_th.png',
          ),
        );
      });
    });
  });
}
