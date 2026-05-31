// Unit tests for SessionChatRemoteDatasource (ADR 0012).
//
// Uses fake_cloud_firestore to exercise the real datasource logic without a
// live Firebase project.
//
// Covers:
//   - sendMessage: message doc written with required fields (no readBy)
//   - sendMessage: N groupChats docs written (one per memberUid)
//   - sendMessage: sender's unreadCount == 0; others' unreadCount incremented
//   - sendMessage: lastMessageText preview truncated at 200 chars with ellipsis
//   - sendMessage: NO readBy field on the message document
//   - markSessionRead: writes {unreadCount: 0} to users/{uid}/groupChats/{sid}
//   - markSessionRead: does NOT touch any messages collection

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/data/datasources/session_chat_remote_datasource.dart';

void main() {
  // ── sendMessage ──────────────────────────────────────────────────────────

  group('sendMessage', () {
    test(
      'message document is written to sessions/{sessionId}/messages',
      () async {
        final fakeFirestore = FakeFirebaseFirestore();
        final datasource = SessionChatRemoteDatasource(fakeFirestore);

        await datasource.sendMessage(
          sessionId: 'session-1',
          memberUids: const ['uid-sender', 'uid-other'],
          senderUid: 'uid-sender',
          senderDisplayName: 'Alice',
          sessionTitle: 'Study Group',
          text: 'Hello everyone',
        );

        final msgs = await fakeFirestore
            .collection('sessions/session-1/messages')
            .get();
        expect(msgs.docs, hasLength(1));
        final data = msgs.docs.first.data();

        expect(data['type'], 'text');
        expect(data['senderUid'], 'uid-sender');
        expect(data['senderDisplayName'], 'Alice');
        expect(data['text'], 'Hello everyone');
        expect(data.containsKey('sentAt'), isTrue);
        expect(data.containsKey('messageId'), isTrue);
      },
    );

    test(
      'groupChats doc written for each memberUid (N members = N docs)',
      () async {
        final fakeFirestore = FakeFirebaseFirestore();
        final datasource = SessionChatRemoteDatasource(fakeFirestore);

        await datasource.sendMessage(
          sessionId: 'session-1',
          memberUids: const ['uid-a', 'uid-b', 'uid-c'],
          senderUid: 'uid-a',
          senderDisplayName: 'Alice',
          sessionTitle: 'Study Group',
          text: 'Hi',
        );

        for (final uid in ['uid-a', 'uid-b', 'uid-c']) {
          final snap = await fakeFirestore
              .doc('users/$uid/groupChats/session-1')
              .get();
          expect(
            snap.exists,
            isTrue,
            reason: 'groupChats doc missing for uid=$uid',
          );
        }
      },
    );

    test("sender's unreadCount is set to 0 in their groupChats doc", () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final datasource = SessionChatRemoteDatasource(fakeFirestore);

      await datasource.sendMessage(
        sessionId: 'session-1',
        memberUids: const ['uid-sender', 'uid-other'],
        senderUid: 'uid-sender',
        senderDisplayName: 'Alice',
        sessionTitle: 'Study Group',
        text: 'Hello',
      );

      final snap = await fakeFirestore
          .doc('users/uid-sender/groupChats/session-1')
          .get();
      expect(snap.data()!['unreadCount'], 0);
    });

    test("other members' unreadCount is incremented from 0 to 1", () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final datasource = SessionChatRemoteDatasource(fakeFirestore);

      await datasource.sendMessage(
        sessionId: 'session-1',
        memberUids: const ['uid-sender', 'uid-other'],
        senderUid: 'uid-sender',
        senderDisplayName: 'Alice',
        sessionTitle: 'Study Group',
        text: 'Hello',
      );

      final snap = await fakeFirestore
          .doc('users/uid-other/groupChats/session-1')
          .get();
      // FakeFirebaseFirestore evaluates FieldValue.increment numerically.
      expect(snap.data()!['unreadCount'], 1);
    });

    test(
      'lastMessageText is set on groupChats doc (≤ 200 chars → no ellipsis)',
      () async {
        final fakeFirestore = FakeFirebaseFirestore();
        final datasource = SessionChatRemoteDatasource(fakeFirestore);

        await datasource.sendMessage(
          sessionId: 'session-1',
          memberUids: const ['uid-a'],
          senderUid: 'uid-a',
          senderDisplayName: 'Alice',
          sessionTitle: 'Study Group',
          text: 'Short message',
        );

        final snap = await fakeFirestore
            .doc('users/uid-a/groupChats/session-1')
            .get();
        expect(snap.data()!['lastMessageText'], 'Short message');
      },
    );

    test(
      'lastMessageText truncated to 200 chars with ellipsis when text > 200',
      () async {
        final fakeFirestore = FakeFirebaseFirestore();
        final datasource = SessionChatRemoteDatasource(fakeFirestore);

        final longText = 'A' * 250;
        await datasource.sendMessage(
          sessionId: 'session-1',
          memberUids: const ['uid-a'],
          senderUid: 'uid-a',
          senderDisplayName: 'Alice',
          sessionTitle: 'Study Group',
          text: longText,
        );

        final snap = await fakeFirestore
            .doc('users/uid-a/groupChats/session-1')
            .get();
        final preview = snap.data()!['lastMessageText'] as String;
        // preview = first 200 chars + '…' (single Unicode ellipsis char)
        expect(preview.length, 201);
        expect(preview.endsWith('…'), isTrue);
      },
    );

    test('message document does NOT contain a readBy field', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final datasource = SessionChatRemoteDatasource(fakeFirestore);

      await datasource.sendMessage(
        sessionId: 'session-1',
        memberUids: const ['uid-sender'],
        senderUid: 'uid-sender',
        senderDisplayName: 'Alice',
        sessionTitle: 'Study Group',
        text: 'Hello',
      );

      final msgs = await fakeFirestore
          .collection('sessions/session-1/messages')
          .get();
      expect(msgs.docs, hasLength(1));
      final data = msgs.docs.first.data();
      expect(
        data.containsKey('readBy'),
        isFalse,
        reason: 'readBy must not appear on session messages (ADR 0012 SD3)',
      );
    });

    test('groupChats doc carries sessionId and sessionTitle fields', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final datasource = SessionChatRemoteDatasource(fakeFirestore);

      await datasource.sendMessage(
        sessionId: 'session-99',
        memberUids: const ['uid-a'],
        senderUid: 'uid-a',
        senderDisplayName: 'Bob',
        sessionTitle: 'Advanced Calculus',
        text: 'Let\'s meet',
      );

      final snap = await fakeFirestore
          .doc('users/uid-a/groupChats/session-99')
          .get();
      final data = snap.data()!;
      expect(data['sessionId'], 'session-99');
      expect(data['sessionTitle'], 'Advanced Calculus');
    });
  });

  // ── markSessionRead ──────────────────────────────────────────────────────

  group('markSessionRead', () {
    test(
      'writes unreadCount = 0 to users/{uid}/groupChats/{sessionId}',
      () async {
        final fakeFirestore = FakeFirebaseFirestore();
        // Pre-create the summary doc with a non-zero unread count.
        await fakeFirestore.doc('users/uid-reader/groupChats/session-1').set({
          'unreadCount': 5,
          'sessionId': 'session-1',
        });

        final datasource = SessionChatRemoteDatasource(fakeFirestore);
        await datasource.markSessionRead('session-1', 'uid-reader');

        final snap = await fakeFirestore
            .doc('users/uid-reader/groupChats/session-1')
            .get();
        expect(snap.data()!['unreadCount'], 0);
      },
    );

    test(
      'does NOT write to the sessions/{sessionId}/messages collection',
      () async {
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore.doc('users/uid-reader/groupChats/session-1').set({
          'unreadCount': 2,
          'sessionId': 'session-1',
        });

        final datasource = SessionChatRemoteDatasource(fakeFirestore);
        await datasource.markSessionRead('session-1', 'uid-reader');

        final msgs = await fakeFirestore
            .collection('sessions/session-1/messages')
            .get();
        expect(
          msgs.docs,
          isEmpty,
          reason: 'markSessionRead must not touch the messages collection',
        );
      },
    );

    test(
      'completes without throwing when summary doc does not exist',
      () async {
        final fakeFirestore = FakeFirebaseFirestore();
        // Do NOT create the summary doc — simulate first-open.
        final datasource = SessionChatRemoteDatasource(fakeFirestore);

        // Should not throw.
        await expectLater(
          () => datasource.markSessionRead('session-missing', 'uid-reader'),
          returnsNormally,
        );
      },
    );
  });
}
