// Widget tests for DmConversationListScreen (ADR 0011).
//
// Covers:
//   - Smoke test: renders without exception when stream is empty
//   - Empty state widget shown when dmConversationsProvider emits []
//   - Conversation tile visible when stream emits one DmConversation
//   - Unread badge visible when unreadCounts[myUid] > 0
//   - Search field filters tiles by display name (case-insensitive)
//   - Tapping a tile calls context.push with a path containing the other uid

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/chat/domain/entities/dm_conversation.dart';
import 'package:mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:mobile/features/chat/presentation/screens/dm_conversation_list_screen.dart';
import 'package:mobile/features/chat/presentation/widgets/dm_conversation_tile.dart';
import 'package:mobile/features/chat/presentation/widgets/dm_unread_badge.dart';
import 'package:mobile/features/friends/domain/entities/friend_entity.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeFirebaseUser extends Fake implements User {
  _FakeFirebaseUser(this._uid, this._displayName);
  final String _uid;
  final String _displayName;

  @override
  String get uid => _uid;

  @override
  String? get displayName => _displayName;
}

const _myUid = 'user-me';
const _otherUid = 'user-other';

// Lexicographic: 'user-me' vs 'user-other' → 'user-me' < 'user-other'
const _sortedDmId = 'user-me_user-other';

// ── Helpers ───────────────────────────────────────────────────────────────────

DmConversation _stubConversation({
  int unreadForMe = 0,
  String? lastMessageText,
}) => DmConversation(
      dmId: _sortedDmId,
      participantUids: const [_myUid, _otherUid],
      createdAt: DateTime(2026, 5),
      unreadCounts: {_myUid: unreadForMe, _otherUid: 0},
      lastMessageText: lastMessageText ?? 'Hello',
      lastMessageAt: DateTime(2026, 5, 1, 12),
    );

FriendEntity _stubFriend() => FriendEntity(
      friendUid: _otherUid,
      status: 'accepted',
      initiatorUid: _otherUid,
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
      friendDisplayName: 'Alice Smith',
    );

/// Builds the screen under test with the given provider overrides.
///
/// [conversationsList] defaults to an empty stream (loading skeleton not shown
/// because stream emits immediately).
Widget _buildScreen({
  List<DmConversation> conversations = const [],
  List<FriendEntity> friends = const [],
  String myUid = _myUid,
  GoRouter? router,
}) {
  final screen = ProviderScope(
    overrides: [
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser(myUid, 'Me')),
      ),
      dmConversationsProvider(myUid).overrideWith(
        (_) => Stream.value(conversations),
      ),
      friendsProvider(myUid).overrideWith(
        (_) => Stream.value(friends),
      ),
    ],
    child: const MaterialApp(
      home: DmConversationListScreen(),
    ),
  );

  if (router != null) {
    return ProviderScope(
      overrides: [
        firebaseAuthStateProvider.overrideWith(
          (_) => Stream.value(_FakeFirebaseUser(myUid, 'Me')),
        ),
        dmConversationsProvider(myUid).overrideWith(
          (_) => Stream.value(conversations),
        ),
        friendsProvider(myUid).overrideWith(
          (_) => Stream.value(friends),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  return screen;
}

void main() {
  // ── Smoke test ─────────────────────────────────────────────────────────────

  testWidgets('smoke test: renders without exception when stream is empty', (
    tester,
  ) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle(const Duration(seconds: 3));
    // No crash — test passes if we reach here.
    expect(find.byType(DmConversationListScreen), findsOneWidget);
  });

  // ── AppBar ─────────────────────────────────────────────────────────────────

  testWidgets('app bar shows "Messages" title', (tester) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('Messages'), findsOneWidget);
  });

  // ── Empty state ────────────────────────────────────────────────────────────

  testWidgets('empty state shows "No messages yet" when no conversations', (
    tester,
  ) async {
    await tester.pumpWidget(_buildScreen(conversations: []));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('No messages yet'), findsOneWidget);
  });

  testWidgets('empty state icon is present when no conversations', (
    tester,
  ) async {
    await tester.pumpWidget(_buildScreen(conversations: []));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
  });

  // ── Conversation tile ──────────────────────────────────────────────────────

  testWidgets('conversation tile visible when stream emits one DmConversation',
      (tester) async {
    await tester.pumpWidget(
      _buildScreen(
        conversations: [_stubConversation()],
        friends: [_stubFriend()],
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byType(DmConversationTile), findsOneWidget);
    expect(find.text('Alice Smith'), findsOneWidget);
  });

  testWidgets(
      'last message preview text visible in tile', (tester) async {
    await tester.pumpWidget(
      _buildScreen(
        conversations: [_stubConversation(lastMessageText: 'Hey there')],
        friends: [_stubFriend()],
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('Hey there'), findsOneWidget);
  });

  // ── Unread badge ───────────────────────────────────────────────────────────

  testWidgets('unread badge visible when unreadCounts[myUid] > 0', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildScreen(
        conversations: [_stubConversation(unreadForMe: 3)],
        friends: [_stubFriend()],
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byType(DmUnreadBadge), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('unread badge NOT visible when unreadCounts[myUid] == 0', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildScreen(
        conversations: [_stubConversation()],
        friends: [_stubFriend()],
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // DmUnreadBadge renders SizedBox.shrink when count == 0,
    // so the badge container with a count label is absent.
    // Verify no numeric badge text is shown for count > 0.
    // The DmUnreadBadge widget is still in the tree but returns
    // SizedBox.shrink — we verify no visible count text appears.
    expect(find.text('0'), findsNothing);
    // A tile is present but no badge label.
    expect(find.byType(DmConversationTile), findsOneWidget);
  });

  // ── Search / filter ────────────────────────────────────────────────────────

  testWidgets('search field is present', (tester) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('search field filters tiles by display name (case-insensitive)',
      (tester) async {
    final conv1 = DmConversation(
      dmId: 'user-me_user-other',
      participantUids: const [_myUid, _otherUid],
      createdAt: DateTime(2026, 5),
      unreadCounts: {_myUid: 0, _otherUid: 0},
      lastMessageText: 'Hi',
      lastMessageAt: DateTime(2026, 5),
    );
    final conv2 = DmConversation(
      dmId: 'bob_user-me',
      participantUids: const ['bob', _myUid],
      createdAt: DateTime(2026, 5, 2),
      unreadCounts: {_myUid: 0, 'bob': 0},
      lastMessageText: 'Hey',
      lastMessageAt: DateTime(2026, 5, 2),
    );

    final friends = [
      FriendEntity(
        friendUid: _otherUid,
        status: 'accepted',
        initiatorUid: _otherUid,
        createdAt: DateTime(2026, 5),
        updatedAt: DateTime(2026, 5),
        friendDisplayName: 'Alice Smith',
      ),
      FriendEntity(
        friendUid: 'bob',
        status: 'accepted',
        initiatorUid: 'bob',
        createdAt: DateTime(2026, 5, 2),
        updatedAt: DateTime(2026, 5, 2),
        friendDisplayName: 'Bob Jones',
      ),
    ];

    await tester.pumpWidget(
      _buildScreen(conversations: [conv1, conv2], friends: friends),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Both tiles shown initially.
    expect(find.byType(DmConversationTile), findsNWidgets(2));

    // Type a search query in lowercase.
    await tester.enterText(find.byType(TextField), 'alice');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Only Alice tile should remain.
    expect(find.byType(DmConversationTile), findsOneWidget);
    expect(find.text('Alice Smith'), findsOneWidget);
    expect(find.text('Bob Jones'), findsNothing);
  });

  testWidgets(
      '"No results found" shown when search query has no matching conversation',
      (tester) async {
    await tester.pumpWidget(
      _buildScreen(
        conversations: [_stubConversation()],
        friends: [_stubFriend()],
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await tester.enterText(find.byType(TextField), 'ZZZNOTEXIST');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('No results found'), findsOneWidget);
  });

  // ── Tile tap navigates ─────────────────────────────────────────────────────

  testWidgets('tapping a tile navigates to path containing dmId', (
    tester,
  ) async {
    String? pushedPath;

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/messages',
          builder: (_, __) => const DmConversationListScreen(),
        ),
        GoRoute(
          path: '/messages/dm/:id',
          builder: (_, state) {
            pushedPath = '/messages/dm/${state.pathParameters['id']}';
            return const Scaffold(body: Text('DM Screen'));
          },
        ),
      ],
      initialLocation: '/messages',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthStateProvider.overrideWith(
            (_) => Stream.value(_FakeFirebaseUser(_myUid, 'Me')),
          ),
          dmConversationsProvider(_myUid).overrideWith(
            (_) => Stream.value([_stubConversation()]),
          ),
          friendsProvider(_myUid).overrideWith(
            (_) => Stream.value([_stubFriend()]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await tester.tap(find.byType(DmConversationTile));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(pushedPath, contains(_sortedDmId));
  });

  // ── Unauthenticated state ─────────────────────────────────────────────────

  testWidgets('shows sign-in prompt when user is null', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthStateProvider.overrideWith(
            (_) => Stream.value(null),
          ),
        ],
        child: const MaterialApp(home: DmConversationListScreen()),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('Sign in to see your messages.'), findsOneWidget);
  });
}
