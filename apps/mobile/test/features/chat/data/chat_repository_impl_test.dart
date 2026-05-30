// Unit tests for ChatRepositoryImpl (ADR 0011).
//
// Covers:
//   - sendMessage: throws NotFriendsException (and does NOT call createDm or
//     datasource.sendMessage) when areFriends returns false
//   - sendMessage: calls createDm BEFORE datasource.sendMessage when friends
//   - sendMessage: does NOT call datasource.sendMessage if createDm throws

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/chat_error.dart';
import 'package:mobile/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:mobile/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class _MockChatRemoteDatasource extends Mock implements ChatRemoteDatasource {}

void main() {
  late _MockChatRemoteDatasource mockDatasource;
  late ChatRepositoryImpl repo;

  setUp(() {
    mockDatasource = _MockChatRemoteDatasource();
    repo = ChatRepositoryImpl(mockDatasource);
  });

  // ── friends gate ──────────────────────────────────────────────────────────

  group('sendMessage — friends gate', () {
    test('throws NotFriendsException when areFriends returns false', () async {
      when(
        () => mockDatasource.areFriends(any(), any()),
      ).thenAnswer((_) async => false);

      await expectLater(
        () => repo.sendMessage(
          dmId: 'a_z',
          senderUid: 'a',
          senderDisplayName: 'Alice',
          recipientUid: 'z',
          text: 'Hello',
        ),
        throwsA(isA<NotFriendsException>()),
      );
    });

    test('does NOT call createDm when areFriends returns false', () async {
      when(
        () => mockDatasource.areFriends(any(), any()),
      ).thenAnswer((_) async => false);

      try {
        await repo.sendMessage(
          dmId: 'a_z',
          senderUid: 'a',
          senderDisplayName: 'Alice',
          recipientUid: 'z',
          text: 'Hello',
        );
      } catch (_) {}

      verifyNever(() => mockDatasource.createDm(any(), any(), any()));
    });

    test(
      'does NOT call datasource.sendMessage when areFriends returns false',
      () async {
        when(
          () => mockDatasource.areFriends(any(), any()),
        ).thenAnswer((_) async => false);

        try {
          await repo.sendMessage(
            dmId: 'a_z',
            senderUid: 'a',
            senderDisplayName: 'Alice',
            recipientUid: 'z',
            text: 'Hello',
          );
        } catch (_) {}

        verifyNever(
          () => mockDatasource.sendMessage(
            dmId: any(named: 'dmId'),
            senderUid: any(named: 'senderUid'),
            senderDisplayName: any(named: 'senderDisplayName'),
            recipientUid: any(named: 'recipientUid'),
            text: any(named: 'text'),
          ),
        );
      },
    );
  });

  // ── happy path (friends) ──────────────────────────────────────────────────

  group('sendMessage — friends (happy path)', () {
    test('calls createDm before datasource.sendMessage', () async {
      final callOrder = <String>[];

      when(
        () => mockDatasource.areFriends(any(), any()),
      ).thenAnswer((_) async => true);
      when(() => mockDatasource.createDm(any(), any(), any())).thenAnswer((
        _,
      ) async {
        callOrder.add('createDm');
      });
      when(
        () => mockDatasource.sendMessage(
          dmId: any(named: 'dmId'),
          senderUid: any(named: 'senderUid'),
          senderDisplayName: any(named: 'senderDisplayName'),
          recipientUid: any(named: 'recipientUid'),
          text: any(named: 'text'),
        ),
      ).thenAnswer((_) async {
        callOrder.add('sendMessage');
      });

      await repo.sendMessage(
        dmId: 'a_z',
        senderUid: 'a',
        senderDisplayName: 'Alice',
        recipientUid: 'z',
        text: 'Hello',
      );

      expect(callOrder, ['createDm', 'sendMessage']);
    });

    test(
      'passes dmId, senderUid, recipientUid to createDm unchanged',
      () async {
        when(
          () => mockDatasource.areFriends(any(), any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockDatasource.createDm(any(), any(), any()),
        ).thenAnswer((_) async {});
        when(
          () => mockDatasource.sendMessage(
            dmId: any(named: 'dmId'),
            senderUid: any(named: 'senderUid'),
            senderDisplayName: any(named: 'senderDisplayName'),
            recipientUid: any(named: 'recipientUid'),
            text: any(named: 'text'),
          ),
        ).thenAnswer((_) async {});

        await repo.sendMessage(
          dmId: 'a_z',
          senderUid: 'a',
          senderDisplayName: 'Alice',
          recipientUid: 'z',
          text: 'Hello',
        );

        verify(() => mockDatasource.createDm('a_z', 'a', 'z')).called(1);
      },
    );
  });

  // ── createDm failure ─────────────────────────────────────────────────────

  group('sendMessage — createDm failure', () {
    test('does NOT call datasource.sendMessage if createDm throws', () async {
      when(
        () => mockDatasource.areFriends(any(), any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockDatasource.createDm(any(), any(), any()),
      ).thenThrow(const ChatDataException('Could not create conversation'));

      await expectLater(
        () => repo.sendMessage(
          dmId: 'a_z',
          senderUid: 'a',
          senderDisplayName: 'Alice',
          recipientUid: 'z',
          text: 'Hello',
        ),
        throwsA(isA<ChatDataException>()),
      );

      verifyNever(
        () => mockDatasource.sendMessage(
          dmId: any(named: 'dmId'),
          senderUid: any(named: 'senderUid'),
          senderDisplayName: any(named: 'senderDisplayName'),
          recipientUid: any(named: 'recipientUid'),
          text: any(named: 'text'),
        ),
      );
    });
  });

  // ── markRead ─────────────────────────────────────────────────────────────

  group('markRead', () {
    test('delegates markRead to datasource with correct args', () async {
      when(
        () => mockDatasource.markRead(any(), any()),
      ).thenAnswer((_) async {});

      await repo.markRead('a_z', 'a');

      verify(() => mockDatasource.markRead('a_z', 'a')).called(1);
    });
  });

  // ── streamConversations ───────────────────────────────────────────────────

  group('streamConversations', () {
    test('emits empty list when datasource stream emits empty list', () async {
      when(
        () => mockDatasource.streamConversations(any()),
      ).thenAnswer((_) => Stream.value([]));

      final result = await repo.streamConversations('uid').first;
      expect(result, isEmpty);
    });
  });
}
