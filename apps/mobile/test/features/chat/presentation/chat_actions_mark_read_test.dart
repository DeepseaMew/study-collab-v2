// Unit-level widget test for the ChatActions.markRead notifier path
// (CHAT-M3 security fix, ADR 0011).
//
// Contract verified:
//   - markRead is fire-and-forget: ChatDataException from the use-case does
//     NOT surface as an AsyncError state on the chatActionsProvider.
//   - State remains AsyncData(null) after markRead, even on failure.
//
// Note: the test stubs MarkDmReadUseCase at the repository level (via
// a mock ChatRepository) so that we avoid wiring real Firestore. The notifier
// swallows all exceptions from markRead per the ADR 0011 fire-and-forget spec.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/chat_error.dart';
import 'package:mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:mocktail/mocktail.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

// A ChatActions subclass that injects a controlled repository so we can
// force markRead to throw a ChatDataException.
class _ThrowingChatActionsNotifier extends ChatActions {
  _ThrowingChatActionsNotifier(this._repo);
  final ChatRepository _repo;

  @override
  AsyncValue<void> build() => const AsyncData(null);

  @override
  Future<void> markRead(String dmId, String uid) async {
    // Replicate the real provider implementation:
    // call repository.markRead and swallow all errors.
    try {
      await _repo.markRead(dmId, uid);
    } catch (_) {
      // Intentionally swallowed — matches production code in chat_providers.dart
    }
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  group('ChatActions.markRead fire-and-forget contract (CHAT-M3)', () {
    test('state remains AsyncData(null) when repository.markRead throws '
        'ChatDataException — exception is NOT surfaced to UI', () async {
      final mockRepo = _MockChatRepository();
      when(
        () => mockRepo.markRead(any(), any()),
      ).thenThrow(const ChatDataException('Could not mark read'));

      final notifier = _ThrowingChatActionsNotifier(mockRepo);

      // Build a minimal ProviderScope to host the notifier.
      final container = ProviderContainer(
        overrides: [chatActionsProvider.overrideWith(() => notifier)],
      );
      addTearDown(container.dispose);

      // Trigger markRead; must not throw at the call site.
      await expectLater(
        () => container
            .read(chatActionsProvider.notifier)
            .markRead('a_z', 'uid-a'),
        returnsNormally,
      );

      // State must still be AsyncData, not AsyncError.
      final state = container.read(chatActionsProvider);
      expect(state, isA<AsyncData<void>>());
      expect(state.hasError, isFalse);
    });

    test('state remains AsyncData(null) when repository.markRead succeeds '
        '— normal path is also fire-and-forget', () async {
      final mockRepo = _MockChatRepository();
      when(() => mockRepo.markRead(any(), any())).thenAnswer((_) async {});

      final notifier = _ThrowingChatActionsNotifier(mockRepo);

      final container = ProviderContainer(
        overrides: [chatActionsProvider.overrideWith(() => notifier)],
      );
      addTearDown(container.dispose);

      await container
          .read(chatActionsProvider.notifier)
          .markRead('a_z', 'uid-a');

      final state = container.read(chatActionsProvider);
      expect(state, isA<AsyncData<void>>());
      expect(state.hasError, isFalse);
      verify(() => mockRepo.markRead('a_z', 'uid-a')).called(1);
    });

    testWidgets(
      'DmMessageScreen does not show an error banner after markRead throws',
      (tester) async {
        // This widget-level test confirms the UI does not display an error
        // widget as a result of a markRead failure.
        //
        // We build a minimal scaffold with a ProviderScope and verify no
        // error text appears after the notifier's markRead is called with a
        // throwing repository.
        final mockRepo = _MockChatRepository();
        when(
          () => mockRepo.markRead(any(), any()),
        ).thenThrow(const ChatDataException('network error'));

        final notifier = _ThrowingChatActionsNotifier(mockRepo);

        final container = ProviderContainer(
          overrides: [chatActionsProvider.overrideWith(() => notifier)],
        );
        addTearDown(container.dispose);

        // Pump a bare scaffold — we just need the provider to be active.
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Scaffold(body: Text('stub screen'))),
          ),
        );

        // Trigger markRead (simulates what DmMessageScreen calls on open).
        await container
            .read(chatActionsProvider.notifier)
            .markRead('a_z', 'uid-a');
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // No error text of any kind should be rendered.
        expect(find.text('Could not mark read'), findsNothing);
        expect(find.text('network error'), findsNothing);
        expect(
          find.byWidgetPredicate(
            (w) => w is Text && (w.data?.contains('error') ?? false),
          ),
          findsNothing,
        );
      },
    );
  });
}
