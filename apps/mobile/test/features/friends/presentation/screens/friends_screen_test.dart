// Widget tests for FriendsScreen.
//
// Tests:
//   - Friends tab shows empty state when friendsProvider returns []
//   - Requests tab shows empty state when incomingRequestsProvider returns []
//   - Friends tab shows a FriendListTile when friendsProvider returns one item

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/friends/domain/entities/friend_entity.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/features/friends/presentation/providers/incoming_requests_provider.dart';
import 'package:mobile/features/friends/presentation/screens/friends_screen.dart';
import 'package:mobile/features/friends/presentation/widgets/friend_list_tile.dart';
import 'package:network_image_mock/network_image_mock.dart';

class _FakeFirebaseUser extends Fake implements User {
  _FakeFirebaseUser(this._uid);
  final String _uid;
  @override
  String get uid => _uid;
}

const _uid = 'test-uid';

FriendEntity _stubFriend() {
  final now = DateTime(2026, 5, 20);
  return FriendEntity(
    friendUid: 'friend-uid',
    status: 'accepted',
    initiatorUid: 'friend-uid',
    createdAt: now,
    updatedAt: now,
    friendDisplayName: 'Alice Smith',
  );
}

Widget _buildScreen({
  List<FriendEntity> friends = const [],
  List<FriendEntity> incomingRequests = const [],
}) {
  return ProviderScope(
    overrides: [
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser(_uid)),
      ),
      friendsProvider(_uid).overrideWith((_) => Stream.value(friends)),
      incomingRequestsProvider(
        _uid,
      ).overrideWith((_) => Stream.value(incomingRequests)),
    ],
    child: const MaterialApp(home: FriendsScreen()),
  );
}

void main() {
  testWidgets('Friends tab shows empty state when friendsProvider returns []', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Friends tab is selected by default (index 0).
      expect(
        find.text('No friends yet. Search for peers to add!'),
        findsOneWidget,
      );
    });
  });

  testWidgets(
    'Requests tab shows empty state when incomingRequestsProvider returns []',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Tap the Requests tab.
        await tester.tap(find.text('Requests'));
        await tester.pumpAndSettle(const Duration(seconds: 1));

        expect(find.text('No pending requests.'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'Friends tab shows a FriendListTile when friendsProvider returns one item',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(friends: [_stubFriend()]));
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // FriendListTile should be present.
        expect(find.byType(FriendListTile), findsOneWidget);
        // The friend's display name should appear in the tile.
        expect(find.text('Alice Smith'), findsOneWidget);
      });
    },
  );
}
