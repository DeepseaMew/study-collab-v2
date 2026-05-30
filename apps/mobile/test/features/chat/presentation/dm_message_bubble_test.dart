// Widget tests for DmMessageBubble — senderDisplayName guard (ADR 0011).
//
// Regression tests for the fix that ensures an empty senderDisplayName
// renders the Semantics label as 'View Unknown User profile' (no double space)
// instead of 'View  profile'.
//
// Cases:
//   1. senderDisplayName: '' → Semantics label == 'View Unknown User profile'
//   2. senderDisplayName: 'Alice' → Semantics label == 'View Alice profile'

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/domain/entities/dm_message.dart';
import 'package:mobile/features/chat/presentation/widgets/dm_message_bubble.dart';

// ── Helper ────────────────────────────────────────────────────────────────────

/// Wraps [DmMessageBubble] in a minimal [MaterialApp] so that
/// [Theme.of(context)] resolves and the widget tree renders correctly.
///
/// [isMe] is always false so the avatar (and its Semantics label) is rendered.
Widget _buildBubble({required String senderDisplayName}) {
  final message = DmMessage(
    messageId: 'test-msg',
    senderUid: 'uid-other',
    senderDisplayName: senderDisplayName,
    text: 'Hello',
    sentAt: DateTime(2026, 5, 30, 14),
    readBy: const ['uid-other'],
  );

  return MaterialApp(
    home: Scaffold(body: DmMessageBubble(message: message, isMe: false)),
  );
}

void main() {
  // ── senderDisplayName guard ───────────────────────────────────────────────

  testWidgets(
    'empty senderDisplayName → Semantics label is "View Unknown User profile" '
    '(no double space)',
    (tester) async {
      // Enable the semantics tree for this test.
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_buildBubble(senderDisplayName: ''));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // The Semantics label merges the outer label with the child Text ('?'
      // initial letter), producing e.g. "View Unknown User profile\n?".
      // Match on the label prefix to verify the guard text exactly, ensuring
      // there is no double-space artifact like "View  profile".
      expect(
        find.bySemanticsLabel(RegExp(r'^View Unknown User profile')),
        findsOneWidget,
        reason:
            'Empty name must fall back to "Unknown User", '
            'not produce a double-space label like "View  profile".',
      );

      handle.dispose();
    },
  );

  testWidgets('non-empty senderDisplayName "Alice" → Semantics label is '
      '"View Alice profile"', (tester) async {
    // Enable the semantics tree for this test.
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(_buildBubble(senderDisplayName: 'Alice'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // The Semantics label merges the outer label with the child Text ('A'
    // initial letter), producing "View Alice profile\nA".
    // Match on the label prefix to verify the sender name is present exactly.
    expect(
      find.bySemanticsLabel(RegExp(r'^View Alice profile')),
      findsOneWidget,
      reason: 'Sender name must appear verbatim in the accessibility label.',
    );

    handle.dispose();
  });
}
