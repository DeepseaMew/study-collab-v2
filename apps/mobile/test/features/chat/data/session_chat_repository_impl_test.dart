// Unit tests for SessionChatRepositoryImpl (ADR 0012).
//
// Mocks SessionChatRemoteDatasource. Covers:
//   - sendMessage: delegates to datasource with all required params
//   - streamMessages: maps SessionMessageModel to SessionMessage entities
//   - streamGroupChatSummaries: maps GroupChatSummaryModel to GroupChatSummary

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/data/datasources/session_chat_remote_datasource.dart';
import 'package:mobile/features/chat/data/models/group_chat_summary_model.dart';
import 'package:mobile/features/chat/data/models/session_message_model.dart';
import 'package:mobile/features/chat/data/repositories/session_chat_repository_impl.dart';
import 'package:mobile/features/chat/domain/entities/group_chat_summary.dart';
import 'package:mobile/features/chat/domain/entities/session_message.dart';
import 'package:mocktail/mocktail.dart';

class _MockSessionChatRemoteDatasource extends Mock
    implements SessionChatRemoteDatasource {}

// ── Helpers ───────────────────────────────────────────────────────────────────

final _stubSentAt = DateTime(2026, 5, 1, 12);

SessionMessageModel _stubMessageModel({
  String id = 'msg-1',
  String type = 'text',
  String senderUid = 'uid-a',
  String text = 'Hello',
}) => SessionMessageModel(
  messageId: id,
  type: type,
  senderUid: senderUid,
  senderDisplayName: 'Alice',
  sentAt: _stubSentAt,
  text: text,
);

GroupChatSummaryModel _stubSummaryModel({
  String sessionId = 'session-1',
  int unreadCount = 3,
}) => GroupChatSummaryModel(
  sessionId: sessionId,
  sessionTitle: 'Study Group',
  lastMessageText: 'Hi all',
  lastMessageAt: _stubSentAt,
  unreadCount: unreadCount,
);

void main() {
  late _MockSessionChatRemoteDatasource mockDatasource;
  late SessionChatRepositoryImpl repo;

  setUp(() {
    mockDatasource = _MockSessionChatRemoteDatasource();
    repo = SessionChatRepositoryImpl(mockDatasource);
  });

  // ── sendMessage ──────────────────────────────────────────────────────────

  group('sendMessage', () {
    test('delegates to datasource with all required params', () async {
      when(
        () => mockDatasource.sendMessage(
          sessionId: any(named: 'sessionId'),
          memberUids: any(named: 'memberUids'),
          senderUid: any(named: 'senderUid'),
          senderDisplayName: any(named: 'senderDisplayName'),
          sessionTitle: any(named: 'sessionTitle'),
          text: any(named: 'text'),
        ),
      ).thenAnswer((_) async {});

      await repo.sendMessage(
        sessionId: 'session-1',
        memberUids: const ['uid-a', 'uid-b'],
        senderUid: 'uid-a',
        senderDisplayName: 'Alice',
        sessionTitle: 'Study Group',
        text: 'Hello all',
      );

      verify(
        () => mockDatasource.sendMessage(
          sessionId: 'session-1',
          memberUids: const ['uid-a', 'uid-b'],
          senderUid: 'uid-a',
          senderDisplayName: 'Alice',
          sessionTitle: 'Study Group',
          text: 'Hello all',
        ),
      ).called(1);
    });

    test('rethrows exception from datasource', () async {
      when(
        () => mockDatasource.sendMessage(
          sessionId: any(named: 'sessionId'),
          memberUids: any(named: 'memberUids'),
          senderUid: any(named: 'senderUid'),
          senderDisplayName: any(named: 'senderDisplayName'),
          sessionTitle: any(named: 'sessionTitle'),
          text: any(named: 'text'),
        ),
      ).thenThrow(Exception('Firestore error'));

      await expectLater(
        () => repo.sendMessage(
          sessionId: 'session-1',
          memberUids: const ['uid-a'],
          senderUid: 'uid-a',
          senderDisplayName: 'Alice',
          sessionTitle: 'Study Group',
          text: 'Hello',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── streamMessages ────────────────────────────────────────────────────────

  group('streamMessages', () {
    test('maps SessionMessageModel to SessionMessage domain entity', () async {
      final model = _stubMessageModel();
      when(
        () => mockDatasource.streamMessages(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) => Stream.value([model]));

      final result = await repo.streamMessages('session-1').first;

      expect(result, hasLength(1));
      final entity = result.first;
      expect(entity, isA<SessionMessage>());
      expect(entity.messageId, 'msg-1');
      expect(entity.type, 'text');
      expect(entity.senderUid, 'uid-a');
      expect(entity.senderDisplayName, 'Alice');
      expect(entity.text, 'Hello');
      expect(entity.sentAt, _stubSentAt);
    });

    test(
      'maps file_shared model to SessionMessage with fileName and downloadUrl',
      () async {
        final model = SessionMessageModel(
          messageId: 'msg-file',
          type: 'file_shared',
          senderUid: 'uid-a',
          senderDisplayName: 'Alice',
          sentAt: _stubSentAt,
          noteId: 'note-1',
          fileName: 'report.pdf',
          downloadUrl: 'https://storage.example.com/file',
        );

        when(
          () =>
              mockDatasource.streamMessages(any(), limit: any(named: 'limit')),
        ).thenAnswer((_) => Stream.value([model]));

        final result = await repo.streamMessages('session-1').first;

        final entity = result.first;
        expect(entity.type, 'file_shared');
        expect(entity.fileName, 'report.pdf');
        expect(entity.downloadUrl, 'https://storage.example.com/file');
      },
    );

    test('emits empty list when datasource emits empty list', () async {
      when(
        () => mockDatasource.streamMessages(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) => Stream.value([]));

      final result = await repo.streamMessages('session-1').first;
      expect(result, isEmpty);
    });

    test('passes sessionId to datasource unchanged', () async {
      when(
        () => mockDatasource.streamMessages(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) => Stream.value([]));

      await repo.streamMessages('my-session-id').first;

      verify(
        () => mockDatasource.streamMessages(
          'my-session-id',
          limit: any(named: 'limit'),
        ),
      ).called(1);
    });
  });

  // ── streamGroupChatSummaries ──────────────────────────────────────────────

  group('streamGroupChatSummaries', () {
    test(
      'maps GroupChatSummaryModel to GroupChatSummary domain entity',
      () async {
        final model = _stubSummaryModel();
        when(
          () => mockDatasource.streamGroupChatSummaries(any()),
        ).thenAnswer((_) => Stream.value([model]));

        final result = await repo.streamGroupChatSummaries('uid-a').first;

        expect(result, hasLength(1));
        final entity = result.first;
        expect(entity, isA<GroupChatSummary>());
        expect(entity.sessionId, 'session-1');
        expect(entity.sessionTitle, 'Study Group');
        expect(entity.lastMessageText, 'Hi all');
        expect(entity.unreadCount, 3);
      },
    );

    test('emits empty list when datasource emits empty list', () async {
      when(
        () => mockDatasource.streamGroupChatSummaries(any()),
      ).thenAnswer((_) => Stream.value([]));

      final result = await repo.streamGroupChatSummaries('uid-a').first;
      expect(result, isEmpty);
    });

    test('passes uid to datasource unchanged', () async {
      when(
        () => mockDatasource.streamGroupChatSummaries(any()),
      ).thenAnswer((_) => Stream.value([]));

      await repo.streamGroupChatSummaries('specific-uid').first;

      verify(
        () => mockDatasource.streamGroupChatSummaries('specific-uid'),
      ).called(1);
    });

    test(
      'preserves nullable lastMessageAt when model has no last message',
      () async {
        const model = GroupChatSummaryModel(
          sessionId: 'session-empty',
          sessionTitle: 'Empty Chat',
        );

        when(
          () => mockDatasource.streamGroupChatSummaries(any()),
        ).thenAnswer((_) => Stream.value([model]));

        final result = await repo.streamGroupChatSummaries('uid-a').first;
        expect(result.first.lastMessageAt, isNull);
      },
    );
  });

  // ── markSessionRead ───────────────────────────────────────────────────────

  group('markSessionRead', () {
    test('delegates to datasource with sessionId and uid', () async {
      when(
        () => mockDatasource.markSessionRead(any(), any()),
      ).thenAnswer((_) async {});

      await repo.markSessionRead('session-1', 'uid-a');

      verify(
        () => mockDatasource.markSessionRead('session-1', 'uid-a'),
      ).called(1);
    });
  });
}
