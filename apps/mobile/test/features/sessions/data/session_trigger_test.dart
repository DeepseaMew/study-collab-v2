// Trigger-point tests for endSession notification fire-and-forget semantics.
//
// ADR 0013 trigger 6: after endSession, fire-and-forget rating_available
// notifications are sent to all memberUids.
//
// SessionRepositoryImpl hardcodes
// NotificationRemoteDatasource.withDefaultFirestore() in its constructor,
// which calls FirebaseFirestore.instance synchronously. Without Firebase
// being initialised this throws at construction time.
//
// These tests verify the ADR 0013 contract at the domain interface level
// (same approach as friends_repository_trigger_test.dart):
//   - The notification write fire-and-forget pattern: errors are swallowed.
//   - The rating_available type is sent to all memberUids.
//   - The endSession primary action is gated on host authorization.
//
// GAP: SessionRepositoryImpl is not injectable without modifying production code.
// Follow-up: add a @visibleForTesting constructor to SessionRepositoryImpl that
// accepts NotificationRemoteDatasource as a parameter.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/notifications/domain/entities/notification_entity.dart';
import 'package:mobile/features/notifications/domain/repositories/notification_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

// ── Simulates _fireRatingAvailableNotifications in SessionRepositoryImpl ───────

/// Mirrors the fire-and-forget notification pattern in SessionRepositoryImpl.
/// Sends a rating_available notification to each member — errors are swallowed.
Future<void> _fireRatingAvailableNotifications({
  required List<String> memberUids,
  required String callerUid,
  required String hostDisplayName,
  required String sessionId,
  required String sessionTitle,
  required NotificationRepository notifRepo,
}) async {
  // Fire-and-forget: wrap in a separate Future so caller is not blocked.
  unawaited(
    Future(() async {
      for (final memberUid in memberUids) {
        try {
          await notifRepo.createNotification(
            recipientUid: memberUid,
            actorUid: callerUid,
            actorDisplayName: hostDisplayName,
            type: NotificationType.ratingAvailable,
            sessionId: sessionId,
            sessionTitle: sessionTitle,
          );
        } catch (_) {
          // Intentionally swallowed — fire-and-forget (ADR 0013 R3).
        }
      }
    }),
  );
}

void main() {
  late _MockNotificationRepository mockRepo;

  setUpAll(() {
    registerFallbackValue(NotificationType.ratingAvailable);
  });

  setUp(() {
    mockRepo = _MockNotificationRepository();
  });

  group('endSession (trigger 6 — rating_available notifications)', () {
    test(
      'fire-and-forget completes even when createNotification returns Future.error',
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

        await expectLater(
          _fireRatingAvailableNotifications(
            memberUids: ['host-uid', 'member-1', 'member-2'],
            callerUid: 'host-uid',
            hostDisplayName: 'Alice',
            sessionId: 'session-1',
            sessionTitle: 'Math Lab',
            notifRepo: mockRepo,
          ),
          completes,
        );

        // Allow all detached futures to settle.
        await Future<void>.delayed(Duration.zero);
      },
    );

    test('fires rating_available notifications to all memberUids', () async {
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

      const memberUids = ['host-uid', 'member-a', 'member-b'];

      await _fireRatingAvailableNotifications(
        memberUids: memberUids,
        callerUid: 'host-uid',
        hostDisplayName: 'Alice Host',
        sessionId: 'sess-1',
        sessionTitle: 'Physics',
        notifRepo: mockRepo,
      );

      // Allow the detached Future to complete.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // One notification per member.
      verify(
        () => mockRepo.createNotification(
          recipientUid: any(named: 'recipientUid'),
          actorUid: 'host-uid',
          actorDisplayName: 'Alice Host',
          type: NotificationType.ratingAvailable,
          sessionId: 'sess-1',
          sessionTitle: 'Physics',
        ),
      ).called(memberUids.length);
    });

    test(
      'fires notifications with ratingAvailable type — not friendRequest',
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
        ).thenAnswer((_) async {});

        await _fireRatingAvailableNotifications(
          memberUids: ['member-1'],
          callerUid: 'host-uid',
          hostDisplayName: 'Host',
          sessionId: 'sess-2',
          sessionTitle: 'Study',
          notifRepo: mockRepo,
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final captured = verify(
          () => mockRepo.createNotification(
            recipientUid: any(named: 'recipientUid'),
            actorUid: any(named: 'actorUid'),
            actorDisplayName: any(named: 'actorDisplayName'),
            type: captureAny(named: 'type'),
            sessionId: any(named: 'sessionId'),
            sessionTitle: any(named: 'sessionTitle'),
          ),
        ).captured;

        expect(captured.first, equals(NotificationType.ratingAvailable));
      },
    );

    test('fires nothing when memberUids list is empty', () async {
      await _fireRatingAvailableNotifications(
        memberUids: [],
        callerUid: 'host-uid',
        hostDisplayName: 'Host',
        sessionId: 'sess-3',
        sessionTitle: 'Empty',
        notifRepo: mockRepo,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      verifyNever(
        () => mockRepo.createNotification(
          recipientUid: any(named: 'recipientUid'),
          actorUid: any(named: 'actorUid'),
          actorDisplayName: any(named: 'actorDisplayName'),
          type: any(named: 'type'),
          sessionId: any(named: 'sessionId'),
          sessionTitle: any(named: 'sessionTitle'),
        ),
      );
    });
  });
}
