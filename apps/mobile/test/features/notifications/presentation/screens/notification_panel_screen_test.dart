import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/notifications/domain/entities/notification_entity.dart';
import 'package:mobile/features/notifications/domain/repositories/notification_repository.dart';
import 'package:mobile/features/notifications/presentation/providers/notification_preferences_provider.dart';
import 'package:mobile/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:mobile/features/notifications/presentation/screens/notification_panel_screen.dart';
import 'package:mobile/features/notifications/presentation/widgets/notification_list_tile.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

const _uid = 'user-1';

NotificationEntity _stubNotif({
  String id = 'n1',
  NotificationType type = NotificationType.joinRequest,
}) {
  return NotificationEntity(
    notifId: id,
    type: type,
    actorUid: 'actor-uid',
    actorDisplayName: 'Alice',
    isRead: false,
    createdAt: DateTime(2026, 5, 20),
  );
}

class _FakePrefsNotifier extends NotificationPreferencesNotifier {
  _FakePrefsNotifier(this._prefs);
  final Map<String, bool> _prefs;
  @override
  Future<Map<String, bool>> build() async => _prefs;
}

Widget _buildScreen({
  AsyncValue<List<NotificationEntity>> notifs = const AsyncValue.data([]),
  Map<String, bool> prefs = const {
    'allNotifications': true,
    'joinRequestAlerts': true,
    'friendRequests': true,
    'ratingAvailable': true,
  },
}) {
  final mockRepo = _MockNotificationRepository();
  when(() => mockRepo.markAllRead(any())).thenAnswer((_) async {});

  return ProviderScope(
    overrides: [
      notificationRepositoryProvider.overrideWithValue(mockRepo),
      notificationsProvider(_uid).overrideWith(
        (_) => notifs.when(
          loading: () => const Stream.empty(),
          error: (e, st) => Stream.error(e, st),
          data: (v) => Stream.value(v),
        ),
      ),
      notificationPreferencesNotifierProvider.overrideWith(
        () => _FakePrefsNotifier(prefs),
      ),
    ],
    child: MaterialApp(home: NotificationPanelScreen(uid: _uid)),
  );
}

void main() {
  testWidgets(
    'NotificationPanelScreen — renders AppBar title "Notifications"',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('Notifications'), findsOneWidget);
        expect(find.byType(Scaffold), findsOneWidget);
      });
    },
  );

  testWidgets(
    'NotificationPanelScreen — loading state renders CircularProgressIndicator',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(notifs: const AsyncValue.loading()),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    },
  );

  testWidgets(
    'NotificationPanelScreen — empty list shows empty state',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('No notifications yet'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'NotificationPanelScreen — error state shows error message',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(
          notifs: AsyncValue.error(
            Exception('Firestore error'),
            StackTrace.empty,
          ),
        ));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('Failed to load notifications'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'NotificationPanelScreen — populated list renders NotificationListTile',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(
          notifs: AsyncValue.data([_stubNotif()]),
        ));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.byType(NotificationListTile), findsOneWidget);
      });
    },
  );

  testWidgets(
    'NotificationPanelScreen — allNotifications=false shows empty state',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(
          notifs: AsyncValue.data([_stubNotif()]),
          prefs: const {
            'allNotifications': false,
            'joinRequestAlerts': false,
            'friendRequests': false,
            'ratingAvailable': false,
          },
        ));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('No notifications yet'), findsOneWidget);
        expect(find.byType(NotificationListTile), findsNothing);
      });
    },
  );
}
