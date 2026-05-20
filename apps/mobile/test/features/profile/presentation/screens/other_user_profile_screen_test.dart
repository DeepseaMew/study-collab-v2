// Widget tests for OtherUserProfileScreen.
//
// Tests:
//   - Loading: CircularProgressIndicator present while userProvider is loading
//   - Error: error text present when userProvider emits an error
//   - Not found: "User not found" text when userProvider emits null
//   - Data: user.displayName text present when userProvider emits a user
//   - _FriendActionsRow absent when currentUid == user.uid

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/friends/domain/entities/friend_entity.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/features/friends/presentation/providers/incoming_requests_provider.dart';
import 'package:mobile/features/friends/presentation/providers/outgoing_requests_provider.dart';
import 'package:mobile/features/profile/presentation/providers/user_provider.dart';
import 'package:mobile/features/profile/presentation/screens/other_user_profile_screen.dart';
import 'package:network_image_mock/network_image_mock.dart';

class _FakeFirebaseUser extends Fake implements User {
  _FakeFirebaseUser(this._uid);
  final String _uid;
  @override
  String get uid => _uid;
}

const _viewerUid = 'viewer-uid';
const _targetUid = 'target-uid';

UserEntity _makeUser(String uid) => UserEntity(
      uid: uid,
      displayName: 'Display $uid',
      fullName: 'Full $uid',
      email: '$uid@mail.kmutt.ac.th',
      hasHostedBefore: false,
      studentYear: 1,
      academicLevel: 'undergraduate',
      faculty: 'Science',
      profileScore: 0.0,
    );

Widget _buildScreen({
  String viewerUid = _viewerUid,
  String targetUserId = _targetUid,
  AsyncValue<UserEntity?> targetUserState = const AsyncLoading(),
}) {
  return ProviderScope(
    overrides: [
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser(viewerUid)),
      ),
      userProvider(targetUserId).overrideWith(
        (_) => _asyncValueToStream(targetUserState),
      ),
      // Also override the viewer's user for the currentUser lookup.
      userProvider(viewerUid).overrideWith(
        (_) => Stream.value(_makeUser(viewerUid)),
      ),
      friendsProvider(viewerUid).overrideWith(
        (_) => Stream<List<FriendEntity>>.value(const []),
      ),
      incomingRequestsProvider(viewerUid).overrideWith(
        (_) => Stream<List<FriendEntity>>.value(const []),
      ),
      outgoingRequestsProvider(viewerUid).overrideWith(
        (_) => Stream<List<FriendEntity>>.value(const []),
      ),
    ],
    child: MaterialApp(
      home: OtherUserProfileScreen(userId: targetUserId),
    ),
  );
}

Stream<UserEntity?> _asyncValueToStream(AsyncValue<UserEntity?> value) {
  return value.when(
    loading: () => const Stream.empty(),
    error: (e, st) => Stream.error(e, st),
    data: (u) => Stream.value(u),
  );
}

void main() {
  testWidgets(
    'Loading state: CircularProgressIndicator present',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen());
        // Do not pumpAndSettle — we want the loading state.
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    },
  );

  testWidgets(
    'Error state: error text present when userProvider emits an error',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(
            targetUserState: AsyncValue.error(
              Exception('Firestore error'),
              StackTrace.empty,
            ),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.text('Failed to load profile'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'Not found state: "User not found" text when userProvider emits null',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(
            targetUserState: const AsyncValue.data(null),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.text('User not found'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'Data state: user.displayName text present when userProvider emits a user',
    (tester) async {
      await mockNetworkImagesFor(() async {
        final targetUser = _makeUser(_targetUid);
        await tester.pumpWidget(
          _buildScreen(
            targetUserState: AsyncValue.data(targetUser),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.text(targetUser.displayName), findsWidgets);
      });
    },
  );

  testWidgets(
    '_FriendActionsRow absent when currentUid == targetUserId (viewing own profile via other-user screen)',
    (tester) async {
      await mockNetworkImagesFor(() async {
        // Viewer and target are the same user.
        const sameUid = 'same-uid';
        final sameUser = _makeUser(sameUid);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              firebaseAuthStateProvider.overrideWith(
                (_) => Stream.value(_FakeFirebaseUser(sameUid)),
              ),
              userProvider(sameUid).overrideWith(
                (_) => Stream.value(sameUser),
              ),
              friendsProvider(sameUid).overrideWith(
                (_) => Stream<List<FriendEntity>>.value(const []),
              ),
              incomingRequestsProvider(sameUid).overrideWith(
                (_) => Stream<List<FriendEntity>>.value(const []),
              ),
              outgoingRequestsProvider(sameUid).overrideWith(
                (_) => Stream<List<FriendEntity>>.value(const []),
              ),
            ],
            child: MaterialApp(
              home: OtherUserProfileScreen(userId: sameUid),
            ),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // The friend action buttons (Add Friend / Message) must not appear
        // when viewing your own profile.
        expect(find.text('Add Friend'), findsNothing);
        expect(find.text('Message'), findsNothing);
      });
    },
  );
}
