// Widget tests for NotificationBellBadge.
//
// Tests:
//   1. Badge is visible when count > 0.
//   2. Badge is hidden when count == 0.
//   3. Badge text shows the correct count.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:mobile/features/notifications/presentation/widgets/notification_bell_badge.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

Widget _buildBadge({required int unreadCount, String uid = 'test-uid'}) {
  return ProviderScope(
    overrides: [
      unreadNotificationCountProvider(
        uid,
      ).overrideWith((ref) => Stream.value(unreadCount)),
    ],
    child: MaterialApp(
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
      home: Scaffold(
        appBar: AppBar(actions: [NotificationBellBadge(uid: uid)]),
        body: const SizedBox.shrink(),
      ),
    ),
  );
}

void main() {
  group('NotificationBellBadge', () {
    testWidgets('badge is visible when unread count > 0', (tester) async {
      await tester.pumpWidget(_buildBadge(unreadCount: 3));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // The badge is a Container with the error color background.
      final badge = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == AppColors.error,
      );
      expect(badge, findsOneWidget);
    });

    testWidgets('badge is hidden when unread count == 0', (tester) async {
      await tester.pumpWidget(_buildBadge(unreadCount: 0));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // No red badge container should be present.
      final badge = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == AppColors.error,
      );
      expect(badge, findsNothing);
    });

    testWidgets('badge text shows the correct count when count is small', (
      tester,
    ) async {
      await tester.pumpWidget(_buildBadge(unreadCount: 7));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('badge text shows "99+" when count exceeds 99', (tester) async {
      await tester.pumpWidget(_buildBadge(unreadCount: 105));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('badge text shows "1" for exactly 1 unread', (tester) async {
      await tester.pumpWidget(_buildBadge(unreadCount: 1));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('Semantics label contains "unread" when count > 0', (
      tester,
    ) async {
      await tester.pumpWidget(_buildBadge(unreadCount: 4));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final semantics = tester.getSemantics(find.byType(NotificationBellBadge));
      expect(semantics.label, contains('unread'));
    });

    testWidgets('Semantics label says "no unread" when count == 0', (
      tester,
    ) async {
      await tester.pumpWidget(_buildBadge(unreadCount: 0));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final semantics = tester.getSemantics(find.byType(NotificationBellBadge));
      expect(semantics.label, contains('no unread'));
    });
  });
}
