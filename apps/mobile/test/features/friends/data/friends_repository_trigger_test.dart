// Trigger-point tests for friend notification fire-and-forget semantics.
//
// ADR 0013 constraint: notification failures must NEVER block the primary
// friend action. FriendsRepositoryImpl hardcodes
// NotificationRemoteDatasource.withDefaultFirestore() in its constructor,
// which calls FirebaseFirestore.instance synchronously. Without Firebase
// being initialised this throws at construction time, making the repository
// un-instantiable in unit tests.
//
// These tests verify the contract at the domain level:
//   - The FriendsRepository interface is mocked directly.
//   - Fire-and-forget semantics are tested via the _fireNotification helper
//     pattern: a mock that captures the call but does not block.
//   - Actual trigger integration is validated by session_trigger_test.dart
//     which can use FakeFirebaseFirestore end-to-end.
//
// See GAP note in QA report: FriendsRepositoryImpl is not injectable without
// production code change (ADR 0013 R1 resolution). Follow-up: add an
// @visibleForTesting constructor to allow datasource injection.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/notifications/domain/entities/notification_entity.dart';
import 'package:mobile/features/notifications/domain/repositories/notification_repository.dart';
import 'package:mobile/features/notifications/domain/usecases/create_notification_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

// ── Simulates the fire-and-forget wrapper ─────────────────────────────────────

/// Mirrors the _fireNotification pattern in FriendsRepositoryImpl.
/// Verifies the pattern itself: the returned Future is intentionally detached
/// so that any thrown error is swallowed by catchError.
Future<void> _fireNotification(
  CreateNotificationParams params,
  NotificationRepository repo,
) {
  repo
      .createNotification(
        recipientUid: params.recipientUid,
        actorUid: params.actorUid,
        actorDisplayName: params.actorDisplayName,
        type: params.type,
        sessionId: params.sessionId,
        sessionTitle: params.sessionTitle,
      )
      .catchError((_) {
        // Intentionally swallowed — fire and forget.
      });
  return Future.value(); // Primary action: returns immediately.
}

void main() {
  late _MockNotificationRepository mockRepo;

  setUpAll(() {
    registerFallbackValue(NotificationType.friendRequest);
  });

  setUp(() {
    mockRepo = _MockNotificationRepository();
  });

  group(
    'sendRequest (trigger 1 — friend_request notification) — fire-and-forget pattern',
    () {
      test(
        'completes even when notification createNotification returns Future.error',
        () async {
          // Notification write returns a rejected Future (async failure).
          when(
            () => mockRepo.createNotification(
              recipientUid: any(named: 'recipientUid'),
              actorUid: any(named: 'actorUid'),
              actorDisplayName: any(named: 'actorDisplayName'),
              type: any(named: 'type'),
              sessionId: any(named: 'sessionId'),
              sessionTitle: any(named: 'sessionTitle'),
            ),
          ).thenAnswer((_) => Future.error(Exception('network error')));

          const params = CreateNotificationParams(
            recipientUid: 'target-uid',
            actorUid: 'current-uid',
            actorDisplayName: 'Alice',
            type: NotificationType.friendRequest,
          );

          // The fire-and-forget wrapper must not propagate the exception.
          await expectLater(_fireNotification(params, mockRepo), completes);

          // Allow the detached future to settle.
          await Future<void>.delayed(Duration.zero);
        },
      );

      test('calls createNotification with friendRequest type', () async {
        when(
          () => mockRepo.createNotification(
            recipientUid: any(named: 'recipientUid'),
            actorUid: any(named: 'actorUid'),
            actorDisplayName: any(named: 'actorDisplayName'),
            type: any(named: 'type'),
            sessionId: any(named: 'sessionId'),
            sessionTitle: any(named: 'sessionTitle'),
          ),
        ).thenAnswer((_) async {});

        await _fireNotification(
          const CreateNotificationParams(
            recipientUid: 'target-uid',
            actorUid: 'current-uid',
            actorDisplayName: 'Alice',
            type: NotificationType.friendRequest,
          ),
          mockRepo,
        );

        // Allow the fire-and-forget Future to resolve.
        await Future<void>.delayed(Duration.zero);

        verify(
          () => mockRepo.createNotification(
            recipientUid: 'target-uid',
            actorUid: 'current-uid',
            actorDisplayName: 'Alice',
            type: NotificationType.friendRequest,
          ),
        ).called(1);
      });
    },
  );

  group(
    'acceptRequest (trigger 2 — friend_accepted notification) — fire-and-forget pattern',
    () {
      test(
        'completes even when notification createNotification returns Future.error',
        () async {
          when(
            () => mockRepo.createNotification(
              recipientUid: any(named: 'recipientUid'),
              actorUid: any(named: 'actorUid'),
              actorDisplayName: any(named: 'actorDisplayName'),
              type: any(named: 'type'),
              sessionId: any(named: 'sessionId'),
              sessionTitle: any(named: 'sessionTitle'),
            ),
          ).thenAnswer((_) => Future.error(Exception('network error')));

          const params = CreateNotificationParams(
            recipientUid: 'initiator-uid',
            actorUid: 'current-uid',
            actorDisplayName: 'Bob',
            type: NotificationType.friendAccepted,
          );

          await expectLater(_fireNotification(params, mockRepo), completes);

          await Future<void>.delayed(Duration.zero);
        },
      );

      test('calls createNotification with friendAccepted type', () async {
        when(
          () => mockRepo.createNotification(
            recipientUid: any(named: 'recipientUid'),
            actorUid: any(named: 'actorUid'),
            actorDisplayName: any(named: 'actorDisplayName'),
            type: any(named: 'type'),
            sessionId: any(named: 'sessionId'),
            sessionTitle: any(named: 'sessionTitle'),
          ),
        ).thenAnswer((_) async {});

        await _fireNotification(
          const CreateNotificationParams(
            recipientUid: 'initiator-uid',
            actorUid: 'current-uid',
            actorDisplayName: 'Bob',
            type: NotificationType.friendAccepted,
          ),
          mockRepo,
        );

        await Future<void>.delayed(Duration.zero);

        verify(
          () => mockRepo.createNotification(
            recipientUid: 'initiator-uid',
            actorUid: 'current-uid',
            actorDisplayName: 'Bob',
            type: NotificationType.friendAccepted,
          ),
        ).called(1);
      });
    },
  );
}
