// Golden tests for NotificationPanelScreen.
//
// Generates 2 goldens:
//   - notification_panel_1_0.png  (text scale 1.0)
//   - notification_panel_1_5.png  (text scale 1.5)
//
// Re-generate with:
//   flutter test --update-goldens test/features/notifications/presentation/notification_panel_golden_test.dart
//
// Fixed locale: th  Fixed theme: AppColors + AppTypography  (per QA rules)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/notifications/domain/entities/notification_entity.dart';
import 'package:mobile/features/notifications/domain/repositories/notification_repository.dart';
import 'package:mobile/features/notifications/presentation/providers/notification_preferences_provider.dart';
import 'package:mobile/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:mobile/features/notifications/presentation/screens/notification_panel_screen.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';

// ── Fake repository (suppresses markAllRead on panel open) ────────────────────

class _FakeNotificationRepository implements NotificationRepository {
  @override
  Stream<List<NotificationEntity>> streamNotifications(String recipientUid) =>
      Stream.value([]);

  @override
  Stream<int> streamUnreadCount(String recipientUid) => Stream.value(0);

  @override
  Future<void> markAllRead(String recipientUid) async {}

  @override
  Future<void> createNotification({
    required String recipientUid,
    required String actorUid,
    required String actorDisplayName,
    required NotificationType type,
    String? sessionId,
    String? sessionTitle,
  }) async {}
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

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _fixedDate = DateTime(2026, 5, 1, 10);

final _sampleNotifications = [
  NotificationEntity(
    notifId: 'n1',
    type: NotificationType.friendRequest,
    actorUid: 'actor-1',
    actorDisplayName: 'Alice',
    isRead: false,
    createdAt: _fixedDate.subtract(const Duration(minutes: 5)),
  ),
  NotificationEntity(
    notifId: 'n2',
    type: NotificationType.joinApproved,
    actorUid: 'actor-2',
    actorDisplayName: 'Bob',
    sessionId: 'session-1',
    sessionTitle: 'Math Study',
    isRead: true,
    createdAt: _fixedDate.subtract(const Duration(hours: 2)),
  ),
  NotificationEntity(
    notifId: 'n3',
    type: NotificationType.ratingAvailable,
    actorUid: 'actor-3',
    actorDisplayName: 'Carol',
    sessionId: 'session-2',
    sessionTitle: 'Physics Lab',
    isRead: false,
    createdAt: _fixedDate.subtract(const Duration(days: 1)),
  ),
];

// ── Screen builder ────────────────────────────────────────────────────────────

Widget _buildScreen(
  double textScale, {
  List<NotificationEntity> notifications = const [],
}) {
  const uid = 'golden-uid';

  return ProviderScope(
    overrides: [
      notificationsProvider(
        uid,
      ).overrideWith((ref) => Stream.value(notifications)),
      notificationPreferencesNotifierProvider.overrideWith(
        () => _StubPrefsNotifier(),
      ),
      // markAllRead is called in initState via notificationRepositoryProvider;
      // suppress it with the fake repository.
      notificationRepositoryProvider.overrideWithValue(
        _FakeNotificationRepository(),
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
        child: const NotificationPanelScreen(uid: uid),
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('NotificationPanelScreen golden', () {
    testWidgets('scale 1.0 — th locale — empty state', (tester) async {
      await tester.pumpWidget(_buildScreen(1.0));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(NotificationPanelScreen),
        matchesGoldenFile('goldens/notification_panel_1_0.png'),
      );
    });

    testWidgets('scale 1.5 — th locale — with notifications', (tester) async {
      await tester.pumpWidget(
        _buildScreen(1.5, notifications: _sampleNotifications),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(NotificationPanelScreen),
        matchesGoldenFile('goldens/notification_panel_1_5.png'),
      );
    });
  });
}
