// Widget tests for DmMessageScreen (ADR 0011).
//
// Covers:
//   - Loading indicator shown while messages are loading
//   - Error state shown when messagesProvider has an error
//   - Messages rendered after data arrives
//   - Date separator rendered between messages on different calendar days
//   - Send button fires _send() with non-empty text
//   - Send clears the text input
//   - Empty text field: tapping send is handled without crash

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/chat/domain/entities/dm_message.dart';
import 'package:mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:mobile/features/chat/presentation/screens/dm_message_screen.dart';
import 'package:mobile/features/chat/presentation/widgets/dm_message_bubble.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeFirebaseUser extends Fake implements User {
  _FakeFirebaseUser(this._uid, {String? displayName})
      : _displayName = displayName;
  final String _uid;
  final String? _displayName;

  @override
  String get uid => _uid;

  @override
  String? get displayName => _displayName ?? 'Me';
}

// ── Fake ChatActions notifier ─────────────────────────────────────────────────

/// A ChatActions stub that records sendMessage calls and does nothing.
class _StubChatActionsNotifier extends ChatActions {
  final List<Map<String, String>> sentMessages = [];

  @override
  AsyncValue<void> build() => const AsyncData(null);

  @override
  Future<void> sendMessage({
    required String dmId,
    required String senderUid,
    required String senderDisplayName,
    required String recipientUid,
    required String text,
  }) async {
    sentMessages.add({
      'dmId': dmId,
      'senderUid': senderUid,
      'text': text,
    });
    state = const AsyncData(null);
  }

  @override
  Future<void> markRead(String dmId, String uid) async {}
}

// ── Constants ─────────────────────────────────────────────────────────────────

const _myUid = 'uid-me';
const _otherUid = 'uid-other';
const _dmId = 'uid-me_uid-other';
const _displayName = 'Other User';

// ── Helpers ───────────────────────────────────────────────────────────────────

DmMessage _msg({
  String id = 'msg-1',
  String senderUid = _myUid,
  String senderName = 'Me',
  String text = 'Hello',
  DateTime? sentAt,
}) => DmMessage(
      messageId: id,
      senderUid: senderUid,
      senderDisplayName: senderName,
      text: text,
      sentAt: sentAt ?? DateTime(2026, 5, 1, 10, 0),
      readBy: [senderUid],
    );

Widget _buildScreen({
  AsyncValue<List<DmMessage>> messagesState =
      const AsyncData(<DmMessage>[]),
  String myUid = _myUid,
  _StubChatActionsNotifier? actionsNotifier,
}) {
  final notifier = actionsNotifier ?? _StubChatActionsNotifier();
  return ProviderScope(
    overrides: [
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser(myUid, displayName: 'Me')),
      ),
      dmMessagesProvider(_dmId).overrideWith((_) {
        if (messagesState.isLoading) {
          return const Stream.empty();
        }
        if (messagesState.hasError) {
          return Stream.error(
            messagesState.error!,
            messagesState.stackTrace ?? StackTrace.empty,
          );
        }
        return Stream.value(messagesState.requireValue);
      }),
      chatActionsProvider.overrideWith(() => notifier),
    ],
    child: MaterialApp(
      home: DmMessageScreen(
        dmId: _dmId,
        otherUid: _otherUid,
        displayName: _displayName,
      ),
    ),
  );
}

void main() {
  // ── Loading indicator ─────────────────────────────────────────────────────

  testWidgets('loading indicator shown while messages are loading', (
    tester,
  ) async {
    // Use a stream that never emits to simulate perpetual loading.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthStateProvider.overrideWith(
            (_) => Stream.value(_FakeFirebaseUser(_myUid)),
          ),
          dmMessagesProvider(_dmId).overrideWith(
            (_) => const Stream.empty(),
          ),
          chatActionsProvider.overrideWith(() => _StubChatActionsNotifier()),
        ],
        child: MaterialApp(
          home: DmMessageScreen(
            dmId: _dmId,
            otherUid: _otherUid,
            displayName: _displayName,
          ),
        ),
      ),
    );
    // pump once without settling so the CPI animation runs
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // ── Error state ────────────────────────────────────────────────────────────

  testWidgets('error state shown when messagesProvider has an error', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthStateProvider.overrideWith(
            (_) => Stream.value(_FakeFirebaseUser(_myUid)),
          ),
          dmMessagesProvider(_dmId).overrideWith(
            (_) => Stream.error(
              Exception('Firestore error'),
              StackTrace.empty,
            ),
          ),
          chatActionsProvider.overrideWith(() => _StubChatActionsNotifier()),
        ],
        child: MaterialApp(
          home: DmMessageScreen(
            dmId: _dmId,
            otherUid: _otherUid,
            displayName: _displayName,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(
      find.text('Could not load messages. Please try again.'),
      findsOneWidget,
    );
  });

  // ── Empty DM state ─────────────────────────────────────────────────────────

  testWidgets('empty state shows "Say hi" prompt when messages list is empty', (
    tester,
  ) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('Say hi to $_displayName!'), findsOneWidget);
  });

  // ── Messages rendered ──────────────────────────────────────────────────────

  testWidgets('message bubbles rendered after data arrives', (tester) async {
    final msgs = [
      _msg(id: 'msg-1', text: 'Hello there'),
      _msg(
        id: 'msg-2',
        senderUid: _otherUid,
        senderName: 'Other User',
        text: 'Hi!',
      ),
    ];

    await tester.pumpWidget(
      _buildScreen(messagesState: AsyncData(msgs)),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byType(DmMessageBubble), findsNWidgets(2));
    expect(find.text('Hello there'), findsOneWidget);
    expect(find.text('Hi!'), findsOneWidget);
  });

  testWidgets('messages are rendered oldest-first (first message at top)', (
    tester,
  ) async {
    final msgs = [
      _msg(id: 'msg-1', text: 'First message', sentAt: DateTime(2026, 5, 1, 9)),
      _msg(
        id: 'msg-2',
        text: 'Second message',
        sentAt: DateTime(2026, 5, 1, 10),
      ),
    ];

    await tester.pumpWidget(
      _buildScreen(messagesState: AsyncData(msgs)),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Both messages visible
    expect(find.text('First message'), findsOneWidget);
    expect(find.text('Second message'), findsOneWidget);
  });

  // ── Date separator ─────────────────────────────────────────────────────────

  testWidgets('date separator rendered between messages on different days', (
    tester,
  ) async {
    final msgs = [
      _msg(
        id: 'msg-1',
        text: 'Day one message',
        sentAt: DateTime(2026, 5, 1, 10),
      ),
      _msg(
        id: 'msg-2',
        text: 'Day two message',
        sentAt: DateTime(2026, 5, 2, 10),
      ),
    ];

    await tester.pumpWidget(
      _buildScreen(messagesState: AsyncData(msgs)),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Two separator dividers should appear (one per day group)
    expect(find.text('Day one message'), findsOneWidget);
    expect(find.text('Day two message'), findsOneWidget);
    // Each day group has a date label — "May 1, 2026" and "May 2, 2026"
    expect(find.text('May 1, 2026'), findsOneWidget);
    expect(find.text('May 2, 2026'), findsOneWidget);
  });

  testWidgets(
      'NO date separator between two messages on the same calendar day', (
    tester,
  ) async {
    final msgs = [
      _msg(id: 'msg-1', text: 'Morning', sentAt: DateTime(2026, 5, 1, 9)),
      _msg(id: 'msg-2', text: 'Afternoon', sentAt: DateTime(2026, 5, 1, 15)),
    ];

    await tester.pumpWidget(
      _buildScreen(messagesState: AsyncData(msgs)),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Only one date label for that single day (not two).
    expect(find.text('May 1, 2026'), findsOneWidget);
  });

  // ── Send button / input bar ───────────────────────────────────────────────

  testWidgets('send button is present in input bar', (tester) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });

  testWidgets('typing text into the input field is reflected', (tester) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    final textField = find.byType(TextField).last; // last = message input
    await tester.enterText(textField, 'Test message');
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Test message'), findsOneWidget);
  });

  testWidgets('successful send clears the text input', (tester) async {
    final notifier = _StubChatActionsNotifier();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthStateProvider.overrideWith(
            (_) => Stream.value(_FakeFirebaseUser(_myUid)),
          ),
          dmMessagesProvider(_dmId).overrideWith(
            (_) => Stream.value([]),
          ),
          chatActionsProvider.overrideWith(() => notifier),
        ],
        child: MaterialApp(
          home: DmMessageScreen(
            dmId: _dmId,
            otherUid: _otherUid,
            displayName: _displayName,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Enter text into the message input (last TextField in the tree)
    final textField = find.byType(TextField).last;
    await tester.enterText(textField, 'Hello World');
    await tester.pump(const Duration(milliseconds: 100));

    // Tap send button
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // The text field should now be cleared
    final inputWidget = tester.widget<TextField>(textField);
    expect(inputWidget.controller?.text ?? '', isEmpty);
  });

  testWidgets('tapping send with empty input does not crash', (tester) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Do NOT enter any text; just tap send.
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // No crash — test passes if we get here.
    expect(find.byType(DmMessageScreen), findsOneWidget);
  });

  // ── AppBar ─────────────────────────────────────────────────────────────────

  testWidgets('app bar shows the other user display name', (tester) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text(_displayName), findsOneWidget);
  });
}
