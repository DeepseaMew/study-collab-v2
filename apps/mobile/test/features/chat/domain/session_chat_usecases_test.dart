// Unit tests for session (group) chat domain use cases (ADR 0012).
//
// Covers:
//   - SendSessionMessage: delegates to repository with all required params
//   - MarkSessionRead: delegates to repository with sessionId and uid
//   - StreamSessionMessages: delegates stream to repository
//   - StreamGroupChatSummaries: delegates stream to repository

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/domain/entities/group_chat_summary.dart';
import 'package:mobile/features/chat/domain/entities/session_message.dart';
import 'package:mobile/features/chat/domain/repositories/session_chat_repository.dart';
import 'package:mobile/features/chat/domain/usecases/mark_session_read.dart';
import 'package:mobile/features/chat/domain/usecases/send_session_message.dart';
import 'package:mobile/features/chat/domain/usecases/stream_group_chat_summaries.dart';
import 'package:mobile/features/chat/domain/usecases/stream_session_messages.dart';
import 'package:mocktail/mocktail.dart';

class _MockSessionChatRepository extends Mock
    implements SessionChatRepository {}

// ── Helpers ───────────────────────────────────────────────────────────────────

SessionMessage _stubMessage() => SessionMessage(
  messageId: 'msg-1',
  type: 'text',
  senderUid: 'uid-a',
  senderDisplayName: 'Alice',
  sentAt: DateTime(2026, 5, 1, 12),
  text: 'Hello',
);

GroupChatSummary _stubSummary() => GroupChatSummary(
  sessionId: 'session-1',
  sessionTitle: 'Study Group',
  lastMessageText: 'Hi',
  lastMessageAt: DateTime(2026, 5, 1, 12),
  unreadCount: 2,
);

void main() {
  late _MockSessionChatRepository mockRepo;

  setUp(() {
    mockRepo = _MockSessionChatRepository();
  });

  // ── SendSessionMessage ────────────────────────────────────────────────────

  group('SendSessionMessage', () {
    late SendSessionMessage useCase;

    setUp(() {
      useCase = SendSessionMessage(mockRepo);
    });

    test(
      'delegates execute to repository.sendMessage with all params',
      () async {
        when(
          () => mockRepo.sendMessage(
            sessionId: any(named: 'sessionId'),
            memberUids: any(named: 'memberUids'),
            senderUid: any(named: 'senderUid'),
            senderDisplayName: any(named: 'senderDisplayName'),
            sessionTitle: any(named: 'sessionTitle'),
            text: any(named: 'text'),
          ),
        ).thenAnswer((_) async {});

        await useCase.execute(
          sessionId: 'session-1',
          memberUids: const ['uid-a', 'uid-b'],
          senderUid: 'uid-a',
          senderDisplayName: 'Alice',
          sessionTitle: 'Study Group',
          text: 'Hello',
        );

        verify(
          () => mockRepo.sendMessage(
            sessionId: 'session-1',
            memberUids: const ['uid-a', 'uid-b'],
            senderUid: 'uid-a',
            senderDisplayName: 'Alice',
            sessionTitle: 'Study Group',
            text: 'Hello',
          ),
        ).called(1);
      },
    );

    test('propagates exception from repository', () async {
      when(
        () => mockRepo.sendMessage(
          sessionId: any(named: 'sessionId'),
          memberUids: any(named: 'memberUids'),
          senderUid: any(named: 'senderUid'),
          senderDisplayName: any(named: 'senderDisplayName'),
          sessionTitle: any(named: 'sessionTitle'),
          text: any(named: 'text'),
        ),
      ).thenThrow(Exception('send failed'));

      await expectLater(
        () => useCase.execute(
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

  // ── MarkSessionRead ───────────────────────────────────────────────────────

  group('MarkSessionRead', () {
    late MarkSessionRead useCase;

    setUp(() {
      useCase = MarkSessionRead(mockRepo);
    });

    test(
      'delegates to repository.markSessionRead with sessionId and uid',
      () async {
        when(
          () => mockRepo.markSessionRead(any(), any()),
        ).thenAnswer((_) async {});

        await useCase.execute('session-1', 'uid-a');

        verify(() => mockRepo.markSessionRead('session-1', 'uid-a')).called(1);
      },
    );
  });

  // ── StreamSessionMessages ─────────────────────────────────────────────────

  group('StreamSessionMessages', () {
    late StreamSessionMessages useCase;

    setUp(() {
      useCase = StreamSessionMessages(mockRepo);
    });

    test('emits messages returned by repository', () async {
      final msg = _stubMessage();
      when(
        () => mockRepo.streamMessages(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) => Stream.value([msg]));

      final result = await useCase.execute('session-1').first;
      expect(result, hasLength(1));
      expect(result.first.messageId, 'msg-1');
    });

    test('emits empty list when repository stream emits empty list', () async {
      when(
        () => mockRepo.streamMessages(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) => Stream.value([]));

      final result = await useCase.execute('session-1').first;
      expect(result, isEmpty);
    });

    test('passes sessionId to repository unchanged', () async {
      when(
        () => mockRepo.streamMessages(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) => Stream.value([]));

      await useCase.execute('my-session').first;

      verify(
        () => mockRepo.streamMessages('my-session', limit: any(named: 'limit')),
      ).called(1);
    });
  });

  // ── StreamGroupChatSummaries ──────────────────────────────────────────────

  group('StreamGroupChatSummaries', () {
    late StreamGroupChatSummaries useCase;

    setUp(() {
      useCase = StreamGroupChatSummaries(mockRepo);
    });

    test('emits summaries returned by repository', () async {
      final summary = _stubSummary();
      when(
        () => mockRepo.streamGroupChatSummaries(any()),
      ).thenAnswer((_) => Stream.value([summary]));

      final result = await useCase.execute('uid-a').first;
      expect(result, hasLength(1));
      expect(result.first.sessionId, 'session-1');
    });

    test('emits empty list when repository stream emits empty list', () async {
      when(
        () => mockRepo.streamGroupChatSummaries(any()),
      ).thenAnswer((_) => Stream.value([]));

      final result = await useCase.execute('uid-a').first;
      expect(result, isEmpty);
    });

    test('passes uid to repository unchanged', () async {
      when(
        () => mockRepo.streamGroupChatSummaries(any()),
      ).thenAnswer((_) => Stream.value([]));

      await useCase.execute('specific-uid').first;

      verify(() => mockRepo.streamGroupChatSummaries('specific-uid')).called(1);
    });
  });
}
