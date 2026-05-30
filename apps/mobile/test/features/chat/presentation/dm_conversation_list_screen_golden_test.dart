// Golden tests for DmConversationListScreen (ADR 0011).
//
// One golden per text scale (1.0, 1.5), locale th_TH, fixed theme.
//
// Regenerate with:
//   flutter test --update-goldens \
//     test/features/chat/presentation/dm_conversation_list_screen_golden_test.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/chat/domain/entities/dm_conversation.dart';
import 'package:mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:mobile/features/chat/presentation/screens/dm_conversation_list_screen.dart';
import 'package:mobile/features/friends/domain/entities/friend_entity.dart';
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
const _otherUid = 'golden-other';

DmConversation _stubConversation() => DmConversation(
      dmId: 'golden-me_golden-other',
      participantUids: const [_myUid, _otherUid],
      createdAt: DateTime(2026, 5, 1),
      unreadCounts: {_myUid: 2, _otherUid: 0},
      lastMessageText: 'Hey, are you joining the study session today?',
      lastMessageAt: DateTime(2026, 5, 30, 14, 30),
    );

FriendEntity _stubFriend() => FriendEntity(
      friendUid: _otherUid,
      status: 'accepted',
      initiatorUid: _otherUid,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
      friendDisplayName: 'Alice Siriporn',
    );

// ── Builder ───────────────────────────────────────────────────────────────────

Widget _buildGolden({required double textScale}) {
  return ProviderScope(
    overrides: [
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser()),
      ),
      dmConversationsProvider(_myUid).overrideWith(
        (_) => Stream.value([_stubConversation()]),
      ),
      friendsProvider(_myUid).overrideWith(
        (_) => Stream.value([_stubFriend()]),
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
        child: const DmConversationListScreen(),
      ),
    ),
  );
}

void main() {
  group('DmConversationListScreen golden', () {
    testWidgets('scale 1.0 — th locale', (tester) async {
      await tester.pumpWidget(_buildGolden(textScale: 1.0));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(DmConversationListScreen),
        matchesGoldenFile('goldens/dm_conversation_list_screen_1_0.png'),
      );
    });

    testWidgets('scale 1.5 — th locale', (tester) async {
      await tester.pumpWidget(_buildGolden(textScale: 1.5));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await expectLater(
        find.byType(DmConversationListScreen),
        matchesGoldenFile('goldens/dm_conversation_list_screen_1_5.png'),
      );
    });
  });
}
