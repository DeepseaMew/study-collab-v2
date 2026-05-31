// Golden tests for the Groups tab within DmConversationListScreen (ADR 0012).
//
// One golden per text scale (1.0, 1.5), locale th_TH, fixed app theme.
// Goldens live in test/features/chat/presentation/goldens/.
//
// Regenerate with:
//   flutter test --update-goldens \
//     test/features/chat/presentation/groups_tab_golden_test.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/chat/domain/entities/group_chat_summary.dart';
import 'package:mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:mobile/features/chat/presentation/providers/session_chat_providers.dart';
import 'package:mobile/features/chat/presentation/screens/dm_conversation_list_screen.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeFirebaseUser extends Fake implements User {
  @override
  String get uid => 'golden-me';

  @override
  String? get displayName => 'Golden Me';
}

// ── Stub data ──────────────────────────────────────────────────────────────────

const _myUid = 'golden-me';

final _stubSummaries = <GroupChatSummary>[
  GroupChatSummary(
    sessionId: 'session-calculus',
    sessionTitle: 'Calculus Study Group',
    lastMessageText: 'พร้อมแล้วค่ะ จะมาตอนสามโมง',
    lastMessageAt: DateTime(2026, 5, 30, 14, 30),
    unreadCount: 3,
  ),
  GroupChatSummary(
    sessionId: 'session-physics',
    sessionTitle: 'Physics Lab Team',
    lastMessageText: 'ใครเอา report ส่งแล้วบ้าง?',
    lastMessageAt: DateTime(2026, 5, 30, 10),
    unreadCount: 0,
  ),
];

class _StubSessionChatActionsNotifier extends SessionChatActionsNotifier {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  @override
  Future<void> sendMessage({
    required String sessionId,
    required List<String> memberUids,
    required String senderUid,
    required String senderDisplayName,
    required String sessionTitle,
    required String text,
  }) async {
    state = const AsyncData(null);
  }

  @override
  Future<void> markSessionRead(String sessionId, String uid) async {}
}

// ── Builder ───────────────────────────────────────────────────────────────────

Widget _buildGolden({required double textScale}) {
  return ProviderScope(
    overrides: [
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser()),
      ),
      dmConversationsProvider(_myUid).overrideWith((_) => Stream.value([])),
      friendsProvider(_myUid).overrideWith((_) => Stream.value([])),
      groupChatSummariesProvider(
        _myUid,
      ).overrideWith((_) => Stream.value(_stubSummaries)),
      sessionChatActionsNotifierProvider.overrideWith(
        () => _StubSessionChatActionsNotifier(),
      ),
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
        // Wrap in a widget that taps the Groups tab after initial frame.
        child: const _GroupsTabOpener(),
      ),
    ),
  );
}

/// Helper widget that programmatically switches to the Groups tab (index 1)
/// in the post-frame callback so the golden captures the Groups tab content.
class _GroupsTabOpener extends StatefulWidget {
  const _GroupsTabOpener();

  @override
  State<_GroupsTabOpener> createState() => _GroupsTabOpenerState();
}

class _GroupsTabOpenerState extends State<_GroupsTabOpener> {
  @override
  Widget build(BuildContext context) {
    return const DmConversationListScreen();
  }
}

void main() {
  group('Groups tab golden', () {
    testWidgets('scale 1.0 — th locale', (tester) async {
      await tester.pumpWidget(_buildGolden(textScale: 1.0));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Switch to Groups tab.
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await expectLater(
        find.byType(DmConversationListScreen),
        matchesGoldenFile('goldens/groups_tab_1_0.png'),
      );
    });

    testWidgets('scale 1.5 — th locale', (tester) async {
      await tester.pumpWidget(_buildGolden(textScale: 1.5));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await expectLater(
        find.byType(DmConversationListScreen),
        matchesGoldenFile('goldens/groups_tab_1_5.png'),
      );
    });
  });
}
