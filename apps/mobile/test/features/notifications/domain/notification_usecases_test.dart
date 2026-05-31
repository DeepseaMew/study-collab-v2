// Unit tests for all four notification domain use cases.
//
// Tests that each use case correctly delegates to the repository without
// adding behaviour of its own (single-responsibility).

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/notifications/domain/entities/notification_entity.dart';
import 'package:mobile/features/notifications/domain/repositories/notification_repository.dart';
import 'package:mobile/features/notifications/domain/usecases/create_notification_usecase.dart';
import 'package:mobile/features/notifications/domain/usecases/mark_all_read_usecase.dart';
import 'package:mobile/features/notifications/domain/usecases/stream_notifications_usecase.dart';
import 'package:mobile/features/notifications/domain/usecases/stream_unread_count_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

void main() {
  late _MockNotificationRepository mockRepo;

  setUpAll(() {
    registerFallbackValue(NotificationType.friendRequest);
  });

  setUp(() {
    mockRepo = _MockNotificationRepository();
  });

  // ── StreamNotificationsUseCase ──────────────────────────────────────────────

  group('StreamNotificationsUseCase', () {
    test(
      'delegates to repository.streamNotifications with the given uid',
      () async {
        const uid = 'user-1';
        when(
          () => mockRepo.streamNotifications(uid),
        ).thenAnswer((_) => Stream.value([]));

        final useCase = StreamNotificationsUseCase(mockRepo);
        final stream = useCase.execute(uid);

        await stream.first;

        verify(() => mockRepo.streamNotifications(uid)).called(1);
      },
    );

    test('emits the list returned by the repository', () async {
      final now = DateTime(2026);
      final entity = NotificationEntity(
        notifId: 'n1',
        type: NotificationType.friendRequest,
        actorUid: 'actor-1',
        actorDisplayName: 'Alice',
        isRead: false,
        createdAt: now,
      );

      when(
        () => mockRepo.streamNotifications(any()),
      ).thenAnswer((_) => Stream.value([entity]));

      final useCase = StreamNotificationsUseCase(mockRepo);
      final list = await useCase.execute('user-1').first;

      expect(list, equals([entity]));
    });
  });

  // ── StreamUnreadCountUseCase ────────────────────────────────────────────────

  group('StreamUnreadCountUseCase', () {
    test(
      'delegates to repository.streamUnreadCount with the given uid',
      () async {
        const uid = 'user-2';
        when(
          () => mockRepo.streamUnreadCount(uid),
        ).thenAnswer((_) => Stream.value(3));

        final useCase = StreamUnreadCountUseCase(mockRepo);
        final count = await useCase.execute(uid).first;

        verify(() => mockRepo.streamUnreadCount(uid)).called(1);
        expect(count, equals(3));
      },
    );

    test('emits 0 when the repository emits 0', () async {
      when(
        () => mockRepo.streamUnreadCount(any()),
      ).thenAnswer((_) => Stream.value(0));

      final useCase = StreamUnreadCountUseCase(mockRepo);
      final count = await useCase.execute('user-2').first;

      expect(count, equals(0));
    });
  });

  // ── MarkAllReadUseCase ──────────────────────────────────────────────────────

  group('MarkAllReadUseCase', () {
    test('delegates to repository.markAllRead with the given uid', () async {
      const uid = 'user-3';
      when(() => mockRepo.markAllRead(uid)).thenAnswer((_) async {});

      final useCase = MarkAllReadUseCase(mockRepo);
      await useCase.execute(uid);

      verify(() => mockRepo.markAllRead(uid)).called(1);
    });

    test('propagates exceptions thrown by the repository', () async {
      when(() => mockRepo.markAllRead(any())).thenThrow(Exception('network'));

      final useCase = MarkAllReadUseCase(mockRepo);

      expect(() => useCase.execute('user-3'), throwsException);
    });
  });

  // ── CreateNotificationUseCase ───────────────────────────────────────────────

  group('CreateNotificationUseCase', () {
    test('delegates all params to repository.createNotification', () async {
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

      final useCase = CreateNotificationUseCase(mockRepo);
      await useCase.execute(
        const CreateNotificationParams(
          recipientUid: 'r-uid',
          actorUid: 'a-uid',
          actorDisplayName: 'Bob',
          type: NotificationType.joinApproved,
          sessionId: 'session-1',
          sessionTitle: 'Physics Lab',
        ),
      );

      verify(
        () => mockRepo.createNotification(
          recipientUid: 'r-uid',
          actorUid: 'a-uid',
          actorDisplayName: 'Bob',
          type: NotificationType.joinApproved,
          sessionId: 'session-1',
          sessionTitle: 'Physics Lab',
        ),
      ).called(1);
    });

    test(
      'passes null sessionId and sessionTitle for friend-type events',
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

        final useCase = CreateNotificationUseCase(mockRepo);
        await useCase.execute(
          const CreateNotificationParams(
            recipientUid: 'r-uid',
            actorUid: 'a-uid',
            actorDisplayName: 'Carol',
            type: NotificationType.friendRequest,
          ),
        );

        verify(
          () => mockRepo.createNotification(
            recipientUid: 'r-uid',
            actorUid: 'a-uid',
            actorDisplayName: 'Carol',
            type: NotificationType.friendRequest,
          ),
        ).called(1);
      },
    );

    test('propagates exceptions from the repository', () async {
      when(
        () => mockRepo.createNotification(
          recipientUid: any(named: 'recipientUid'),
          actorUid: any(named: 'actorUid'),
          actorDisplayName: any(named: 'actorDisplayName'),
          type: any(named: 'type'),
          sessionId: any(named: 'sessionId'),
          sessionTitle: any(named: 'sessionTitle'),
        ),
      ).thenThrow(Exception('firestore error'));

      final useCase = CreateNotificationUseCase(mockRepo);

      await expectLater(
        () => useCase.execute(
          const CreateNotificationParams(
            recipientUid: 'r-uid',
            actorUid: 'a-uid',
            actorDisplayName: 'Dave',
            type: NotificationType.ratingAvailable,
          ),
        ),
        throwsException,
      );
    });
  });
}
