// Unit tests for NotificationRemoteDatasource.
//
// Tests:
//   1. createNotification produces a document with isRead: false.
//   2. createNotification produces a document with actorUid equal to the caller's UID.
//   3. markAllRead calls update on every unread document ID provided.
//   4. streamUnreadCount filters by isRead == false and emits the correct count.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:mobile/features/notifications/domain/entities/notification_entity.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late NotificationRemoteDatasource datasource;

  const kRecipientUid = 'recipient-uid-1';
  const kActorUid = 'actor-uid-1';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    datasource = NotificationRemoteDatasource(fakeFirestore);
  });

  group('createNotification', () {
    test('produces a document with isRead: false', () async {
      await datasource.createNotification(
        recipientUid: kRecipientUid,
        actorUid: kActorUid,
        actorDisplayName: 'Actor User',
        type: NotificationType.friendRequest,
      );

      final snap = await fakeFirestore
          .collection('users/$kRecipientUid/notifications')
          .get();

      expect(snap.docs, hasLength(1));
      expect(snap.docs.first.data()['isRead'], isFalse);
    });

    test(
      'produces a document with actorUid equal to the supplied actor UID',
      () async {
        await datasource.createNotification(
          recipientUid: kRecipientUid,
          actorUid: kActorUid,
          actorDisplayName: 'Actor User',
          type: NotificationType.friendAccepted,
        );

        final snap = await fakeFirestore
            .collection('users/$kRecipientUid/notifications')
            .get();

        expect(snap.docs, hasLength(1));
        expect(snap.docs.first.data()['actorUid'], equals(kActorUid));
      },
    );

    test('produces a document with the correct type string', () async {
      await datasource.createNotification(
        recipientUid: kRecipientUid,
        actorUid: kActorUid,
        actorDisplayName: 'Actor User',
        type: NotificationType.ratingAvailable,
        sessionId: 'session-1',
        sessionTitle: 'Study Math',
      );

      final snap = await fakeFirestore
          .collection('users/$kRecipientUid/notifications')
          .get();

      expect(snap.docs.first.data()['type'], equals('rating_available'));
    });

    test('writes sessionId and sessionTitle when provided', () async {
      await datasource.createNotification(
        recipientUid: kRecipientUid,
        actorUid: kActorUid,
        actorDisplayName: 'Actor User',
        type: NotificationType.joinApproved,
        sessionId: 'session-42',
        sessionTitle: 'Physics 101',
      );

      final snap = await fakeFirestore
          .collection('users/$kRecipientUid/notifications')
          .get();

      final data = snap.docs.first.data();
      expect(data['sessionId'], equals('session-42'));
      expect(data['sessionTitle'], equals('Physics 101'));
    });
  });

  group('markAllRead', () {
    test(
      'calls update on every unread document — all become isRead: true',
      () async {
        // Seed three unread notifications.
        final col = fakeFirestore.collection(
          'users/$kRecipientUid/notifications',
        );
        for (var i = 0; i < 3; i++) {
          await col.add({
            'notifId': 'notif-$i',
            'type': 'friend_request',
            'actorUid': kActorUid,
            'actorDisplayName': 'Actor',
            'isRead': false,
            'createdAt': Timestamp.now(),
          });
        }

        await datasource.markAllRead(kRecipientUid);

        final snap = await col.where('isRead', isEqualTo: false).get();
        expect(snap.docs, isEmpty);
      },
    );

    test('does not throw when there are no unread documents', () async {
      // No documents in the collection.
      await expectLater(datasource.markAllRead(kRecipientUid), completes);
    });

    test(
      'only marks unread documents — already-read docs are unaffected',
      () async {
        final col = fakeFirestore.collection(
          'users/$kRecipientUid/notifications',
        );
        // One already read.
        await col.add({
          'notifId': 'read-1',
          'type': 'friend_request',
          'actorUid': kActorUid,
          'actorDisplayName': 'Actor',
          'isRead': true,
          'createdAt': Timestamp.now(),
        });
        // One unread.
        await col.add({
          'notifId': 'unread-1',
          'type': 'friend_request',
          'actorUid': kActorUid,
          'actorDisplayName': 'Actor',
          'isRead': false,
          'createdAt': Timestamp.now(),
        });

        await datasource.markAllRead(kRecipientUid);

        final allSnap = await col.get();
        expect(allSnap.docs, hasLength(2));
        for (final doc in allSnap.docs) {
          expect(doc.data()['isRead'], isTrue);
        }
      },
    );
  });

  group('streamUnreadCount', () {
    test('emits 0 when there are no documents', () async {
      final stream = datasource.streamUnreadCount(kRecipientUid);
      expect(await stream.first, equals(0));
    });

    test('filters by isRead == false and emits the correct count', () async {
      final col = fakeFirestore.collection(
        'users/$kRecipientUid/notifications',
      );
      // Two unread.
      for (var i = 0; i < 2; i++) {
        await col.add({
          'notifId': 'unread-$i',
          'type': 'join_request',
          'actorUid': kActorUid,
          'actorDisplayName': 'Actor',
          'isRead': false,
          'createdAt': Timestamp.now(),
        });
      }
      // One already read (must NOT be counted).
      await col.add({
        'notifId': 'read-1',
        'type': 'friend_request',
        'actorUid': kActorUid,
        'actorDisplayName': 'Actor',
        'isRead': true,
        'createdAt': Timestamp.now(),
      });

      final stream = datasource.streamUnreadCount(kRecipientUid);
      expect(await stream.first, equals(2));
    });

    test('emits 0 after all documents are marked read', () async {
      final col = fakeFirestore.collection(
        'users/$kRecipientUid/notifications',
      );
      final ref = await col.add({
        'notifId': 'notif-x',
        'type': 'friend_request',
        'actorUid': kActorUid,
        'actorDisplayName': 'Actor',
        'isRead': false,
        'createdAt': Timestamp.now(),
      });

      // Count starts at 1.
      final stream = datasource.streamUnreadCount(kRecipientUid);
      expect(await stream.first, equals(1));

      // Mark read directly via Firestore.
      await ref.update({'isRead': true});

      // Count should now be 0.
      expect(await stream.first, equals(0));
    });
  });
}
