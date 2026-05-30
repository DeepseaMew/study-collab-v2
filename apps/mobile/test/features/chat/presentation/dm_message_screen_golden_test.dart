// Golden tests for DmMessageScreen (ADR 0011).
//
// One golden per text scale (1.0, 1.5), locale th_TH, fixed theme.
//
// Regenerate with:
//   flutter test --update-goldens \
//     test/features/chat/presentation/dm_message_screen_golden_test.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/chat/domain/entities/dm_message.dart';
import 'package:mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:mobile/features/chat/presentation/screens/dm_message_screen.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeFirebaseUser extends Fake implements User {
  @override
  String get uid => 'golden-me';

  @override
  String? get displayName => 'Golden Me';
}

// ── Fake ChatActions ──────────────────────────────────────────────────────────

class _StubChatActionsNotifier extends ChatActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  @override
  Future<void> sendMessage({
    required String dmId,
    required String senderUid,
    required String senderDisplayName,
    required String recipientUid,
    required String text,
  }) async {}

  @override
  Future<void> markRead(String dmId, String uid) async {}
}

// ── Stub data ──────────────────────────────────────────────────────────────────

const _myUid = 'golden-me';
const _otherUid = 'golden-other';
const _dmId = 'golden-me_golden-other';
const _displayName = 'Alice Siriporn';

List<DmMessage> _stubMessages() => [
  DmMessage(
    messageId: 'msg-1',
    senderUid: _otherUid,
    senderDisplayName: 'Alice Siriporn',
    text: 'Hey! Are you joining the study session today?',
    sentAt: DateTime(2026, 5, 30, 14),
    readBy: const [_otherUid],
  ),
  DmMessage(
    messageId: 'msg-2',
    senderUid: _myUid,
    senderDisplayName: 'Golden Me',
    text: 'Yes, I will be there! Should I bring my laptop?',
    sentAt: DateTime(2026, 5, 30, 14, 5),
    readBy: const [_myUid],
  ),
  DmMessage(
    messageId: 'msg-3',
    senderUid: _otherUid,
    senderDisplayName: 'Alice Siriporn',
    text: 'Of course! We need it for the group project.',
    sentAt: DateTime(2026, 5, 30, 14, 8),
    readBy: const [_otherUid],
  ),
];

// ── Builder ───────────────────────────────────────────────────────────────────

Widget _buildGolden({required double textScale}) {
  return ProviderScope(
    overrides: [
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser()),
      ),
      dmMessagesProvider(
        _dmId,
      ).overrideWith((_) => Stream.value(_stubMessages())),
      chatActionsProvider.overrideWith(() => _StubChatActionsNotifier()),
    ],
    child: MaterialApp(
      locale: const Locale('th', 'TH'),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          primary: AppColors.accent,
          error: AppColors.error,
          surface: AppColors.background,
        ),
        textTheme: AppTypography.textTheme,
        useMaterial3: true,
      ),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: const DmMessageScreen(
          dmId: _dmId,
          otherUid: _otherUid,
          displayName: _displayName,
        ),
      ),
    ),
  );
}

void main() {
  group('DmMessageScreen golden', () {
    testWidgets('scale 1.0 — th locale', (tester) async {
      await tester.pumpWidget(_buildGolden(textScale: 1.0));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(DmMessageScreen),
        matchesGoldenFile('goldens/dm_message_screen_1_0.png'),
      );
    });

    testWidgets('scale 1.5 — th locale', (tester) async {
      await tester.pumpWidget(_buildGolden(textScale: 1.5));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(DmMessageScreen),
        matchesGoldenFile('goldens/dm_message_screen_1_5.png'),
      );
    });
  });
}
