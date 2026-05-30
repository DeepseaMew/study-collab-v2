// Unit tests for Chat domain use cases (ADR 0011).
//
// Covers:
//   - SendDmMessageUseCase: empty/whitespace text is a no-op, delegates on
//     valid text, truncates at 4 000 chars, propagates NotFriendsException
//   - MarkDmReadUseCase: delegates to repository with correct args
//   - StreamDmConversationsUseCase: delegates stream to repository
//   - StreamDmMessagesUseCase: delegates stream to repository

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/chat_error.dart';
import 'package:mobile/features/chat/domain/entities/dm_conversation.dart';
import 'package:mobile/features/chat/domain/entities/dm_message.dart';
import 'package:mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:mobile/features/chat/domain/usecases/mark_dm_read.dart';
import 'package:mobile/features/chat/domain/usecases/send_dm_message.dart';
import 'package:mobile/features/chat/domain/usecases/stream_dm_conversations.dart';
import 'package:mobile/features/chat/domain/usecases/stream_dm_messages.dart';
import 'package:mocktail/mocktail.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

// ── Helpers ───────────────────────────────────────────────────────────────────

DmConversation _stubConversation() => DmConversation(
      dmId: 'a_z',
      participantUids: const ['a', 'z'],
      createdAt: DateTime(2026, 5, 1),
      unreadCounts: const {'a': 0, 'z': 1},
      lastMessageText: 'Hello',
      lastMessageAt: DateTime(2026, 5, 1, 12),
    );

DmMessage _stubMessage() => DmMessage(
      messageId: 'msg-1',
      senderUid: 'a',
      senderDisplayName: 'Alice',
      text: 'Hello',
      sentAt: DateTime(2026, 5, 1, 12),
      readBy: const ['a'],
    );

void main() {
  late _MockChatRepository mockRepo;

  setUp(() {
    mockRepo = _MockChatRepository();
  });

  // ── SendDmMessageUseCase ─────────────────────────────────────────────────

  group('SendDmMessageUseCase', () {
    late SendDmMessageUseCase useCase;

    setUp(() {
      useCase = SendDmMessageUseCase(mockRepo);
    });

    test('is a no-op (does NOT call repository) when text is empty', () async {
      await useCase.execute(
        dmId: 'a_z',
        senderUid: 'a',
        senderDisplayName: 'Alice',
        recipientUid: 'z',
        text: '',
      );

      verifyNever(
        () => mockRepo.sendMessage(
          dmId: any(named: 'dmId'),
          senderUid: any(named: 'senderUid'),
          senderDisplayName: any(named: 'senderDisplayName'),
          recipientUid: any(named: 'recipientUid'),
          text: any(named: 'text'),
        ),
      );
    });

    test('is a no-op when text is whitespace only', () async {
      await useCase.execute(
        dmId: 'a_z',
        senderUid: 'a',
        senderDisplayName: 'Alice',
        recipientUid: 'z',
        text: '   ',
      );

      verifyNever(
        () => mockRepo.sendMessage(
          dmId: any(named: 'dmId'),
          senderUid: any(named: 'senderUid'),
          senderDisplayName: any(named: 'senderDisplayName'),
          recipientUid: any(named: 'recipientUid'),
          text: any(named: 'text'),
        ),
      );
    });

    test('delegates to repository with trimmed text on valid input', () async {
      when(
        () => mockRepo.sendMessage(
          dmId: any(named: 'dmId'),
          senderUid: any(named: 'senderUid'),
          senderDisplayName: any(named: 'senderDisplayName'),
          recipientUid: any(named: 'recipientUid'),
          text: any(named: 'text'),
        ),
      ).thenAnswer((_) async {});

      await useCase.execute(
        dmId: 'a_z',
        senderUid: 'a',
        senderDisplayName: 'Alice',
        recipientUid: 'z',
        text: '  Hello World  ',
      );

      verify(
        () => mockRepo.sendMessage(
          dmId: 'a_z',
          senderUid: 'a',
          senderDisplayName: 'Alice',
          recipientUid: 'z',
          text: 'Hello World',
        ),
      ).called(1);
    });

    test('truncates text at 4 000 chars', () async {
      when(
        () => mockRepo.sendMessage(
          dmId: any(named: 'dmId'),
          senderUid: any(named: 'senderUid'),
          senderDisplayName: any(named: 'senderDisplayName'),
          recipientUid: any(named: 'recipientUid'),
          text: any(named: 'text'),
        ),
      ).thenAnswer((_) async {});

      final veryLong = 'X' * 5000;
      await useCase.execute(
        dmId: 'a_z',
        senderUid: 'a',
        senderDisplayName: 'Alice',
        recipientUid: 'z',
        text: veryLong,
      );

      final captured = verify(
        () => mockRepo.sendMessage(
          dmId: any(named: 'dmId'),
          senderUid: any(named: 'senderUid'),
          senderDisplayName: any(named: 'senderDisplayName'),
          recipientUid: any(named: 'recipientUid'),
          text: captureAny(named: 'text'),
        ),
      ).captured;
      expect((captured.first as String).length, SendDmMessageUseCase.maxTextLength);
    });

    test('propagates NotFriendsException from repository', () async {
      when(
        () => mockRepo.sendMessage(
          dmId: any(named: 'dmId'),
          senderUid: any(named: 'senderUid'),
          senderDisplayName: any(named: 'senderDisplayName'),
          recipientUid: any(named: 'recipientUid'),
          text: any(named: 'text'),
        ),
      ).thenThrow(const NotFriendsException());

      await expectLater(
        () => useCase.execute(
          dmId: 'a_z',
          senderUid: 'a',
          senderDisplayName: 'Alice',
          recipientUid: 'z',
          text: 'Hello',
        ),
        throwsA(isA<NotFriendsException>()),
      );
    });
  });

  // ── MarkDmReadUseCase ────────────────────────────────────────────────────

  group('MarkDmReadUseCase', () {
    late MarkDmReadUseCase useCase;

    setUp(() {
      useCase = MarkDmReadUseCase(mockRepo);
    });

    test('delegates to repository with correct dmId and uid', () async {
      when(
        () => mockRepo.markRead(any(), any()),
      ).thenAnswer((_) async {});

      await useCase.execute('a_z', 'a');

      verify(() => mockRepo.markRead('a_z', 'a')).called(1);
    });
  });

  // ── StreamDmConversationsUseCase ─────────────────────────────────────────

  group('StreamDmConversationsUseCase', () {
    late StreamDmConversationsUseCase useCase;

    setUp(() {
      useCase = StreamDmConversationsUseCase(mockRepo);
    });

    test('emits empty list when repository stream emits empty', () async {
      when(
        () => mockRepo.streamConversations(any()),
      ).thenAnswer((_) => Stream.value([]));

      final result = await useCase.execute('uid').first;
      expect(result, isEmpty);
    });

    test('emits conversations returned by repository', () async {
      final conv = _stubConversation();
      when(
        () => mockRepo.streamConversations(any()),
      ).thenAnswer((_) => Stream.value([conv]));

      final result = await useCase.execute('uid').first;
      expect(result, hasLength(1));
      expect(result.first.dmId, 'a_z');
    });

    test('passes uid to repository unchanged', () async {
      when(
        () => mockRepo.streamConversations(any()),
      ).thenAnswer((_) => Stream.value([]));

      await useCase.execute('specific-uid').first;

      verify(() => mockRepo.streamConversations('specific-uid')).called(1);
    });
  });

  // ── StreamDmMessagesUseCase ──────────────────────────────────────────────

  group('StreamDmMessagesUseCase', () {
    late StreamDmMessagesUseCase useCase;

    setUp(() {
      useCase = StreamDmMessagesUseCase(mockRepo);
    });

    test('emits empty list when repository stream emits empty', () async {
      when(
        () => mockRepo.streamMessages(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) => Stream.value([]));

      final result = await useCase.execute('a_z').first;
      expect(result, isEmpty);
    });

    test('emits messages returned by repository', () async {
      final msg = _stubMessage();
      when(
        () => mockRepo.streamMessages(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) => Stream.value([msg]));

      final result = await useCase.execute('a_z').first;
      expect(result, hasLength(1));
      expect(result.first.messageId, 'msg-1');
    });

    test('passes dmId to repository unchanged', () async {
      when(
        () => mockRepo.streamMessages(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) => Stream.value([]));

      await useCase.execute('a_z').first;

      verify(() => mockRepo.streamMessages('a_z', limit: any(named: 'limit')))
          .called(1);
    });
  });

  // ── DmConversation entity helpers ─────────────────────────────────────────

  group('DmConversation entity', () {
    test('unreadCountForUid returns count for given uid', () {
      final conv = _stubConversation();
      expect(conv.unreadCountForUid('z'), 1);
      expect(conv.unreadCountForUid('a'), 0);
    });

    test('unreadCountForUid returns 0 for unknown uid', () {
      final conv = _stubConversation();
      expect(conv.unreadCountForUid('unknown'), 0);
    });

    test('otherUid returns the uid that is not myUid', () {
      final conv = _stubConversation();
      expect(conv.otherUid('a'), 'z');
      expect(conv.otherUid('z'), 'a');
    });
  });

  // ── ChatError hierarchy ──────────────────────────────────────────────────

  group('ChatError hierarchy', () {
    test('NotFriendsException is a ChatError', () {
      const e = NotFriendsException();
      expect(e, isA<ChatError>());
    });

    test('NotFriendsException has default message', () {
      const e = NotFriendsException();
      expect(e.message, isNotEmpty);
    });

    test('ChatDataException preserves message', () {
      const e = ChatDataException('Something went wrong');
      expect(e.message, 'Something went wrong');
    });
  });
}
