// Widget tests for ProfileScreen.
//
// Tests:
//   - Smoke test: pumps without exception when userProvider returns a valid UserEntity
//   - Back button visible when Navigator.canPop is true
//   - Back button hidden when ProfileScreen is the root route
//   - Session History shows SessionCard when upcomingSessionsProvider returns sessions
//   - Session History shows empty state icon when both session providers return []

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/friends/domain/entities/friend_entity.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/features/my_sessions/presentation/providers/completed_sessions_provider.dart';
import 'package:mobile/features/my_sessions/presentation/providers/upcoming_sessions_provider.dart';
import 'package:mobile/features/profile/presentation/providers/avatar_upload_provider.dart';
import 'package:mobile/features/profile/presentation/providers/user_provider.dart';
import 'package:mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/shared/widgets/session_card.dart';
import 'package:network_image_mock/network_image_mock.dart';

class _FakeFirebaseUser extends Fake implements User {
  _FakeFirebaseUser(this._uid);
  final String _uid;
  @override
  String get uid => _uid;
}

const _uid = 'test-uid';

const _stubUser = UserEntity(
  uid: _uid,
  displayName: 'Test Student',
  fullName: 'Test Student',
  email: 'test@mail.kmutt.ac.th',
  hasHostedBefore: false,
  studentYear: 2,
  academicLevel: 'undergraduate',
  faculty: 'Engineering',
  profileScore: 0.0,
);

SessionEntity _stubSession({String sessionId = 'sess-1'}) {
  final now = DateTime(2026, 5, 20, 10);
  return SessionEntity(
    sessionId: sessionId,
    hostUid: _uid,
    hostFaculty: 'Engineering',
    title: 'Algebra Review',
    hashtags: const ['math'],
    academicLevel: 'undergraduate',
    studentYear: 2,
    visibility: 'public',
    memberUids: const [_uid],
    noteCount: 0,
    status: 'scheduled',
    scheduledAt: now,
    location: 'CB2308',
    capacity: 10,
    hostDisplayName: 'Test Student',
    createdAt: now,
    updatedAt: now,
  );
}

List<Override> _baseOverrides({
  UserEntity? user = _stubUser,
  List<SessionEntity> upcoming = const [],
  List<SessionEntity> completed = const [],
  List<FriendEntity> friends = const [],
}) {
  return [
    firebaseAuthStateProvider.overrideWith(
      (_) => Stream.value(_FakeFirebaseUser(_uid)),
    ),
    userProvider(_uid).overrideWith((_) => Stream.value(user)),
    friendsProvider(_uid).overrideWith((_) => Stream.value(friends)),
    upcomingSessionsProvider(_uid).overrideWith((_) => Stream.value(upcoming)),
    completedSessionsProvider(
      _uid,
    ).overrideWith((_) => Stream.value(completed)),
    avatarUploadProvider.overrideWith(() => _FakeAvatarUpload()),
    localBytesStreamProvider(_uid).overrideWith((_) => Stream.value(null)),
  ];
}

class _FakeAvatarUpload extends AvatarUpload {
  @override
  AsyncValue<void> build() => const AsyncData(null);
}

/// A minimal GoRouter that renders [ProfileScreen] at '/profile'.
/// GoRouter context is required because ProfileScreen calls context.go()
/// in a postFrameCallback when auth state is initially loading (uid == null).
/// The redirect intercepts any navigation to '/sign-in' and keeps the router
/// at '/profile' so the test never leaves the profile screen.
GoRouter _stubRouter() => GoRouter(
  initialLocation: '/profile',
  redirect: (_, state) {
    if (state.uri.path == '/sign-in') return '/profile';
    return null;
  },
  routes: [
    GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    GoRoute(path: '/sign-in', builder: (_, __) => const Scaffold()),
  ],
);

Widget _buildRootScreen({List<Override>? overrides}) {
  return ProviderScope(
    overrides: overrides ?? _baseOverrides(),
    child: MaterialApp.router(routerConfig: _stubRouter()),
  );
}

void main() {
  testWidgets('smoke test — pumps without exception for valid UserEntity', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildRootScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byType(Scaffold), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('back button hidden when ProfileScreen is the root route', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildRootScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
    });
  });

  testWidgets(
    'back button visible when ProfileScreen is pushed on top of another route',
    (tester) async {
      await mockNetworkImagesFor(() async {
        // Use a plain MaterialApp + Navigator.push (not GoRouter) for this test.
        // ProfileScreen.build checks Navigator.canPop(context) which reflects
        // the standard Navigator stack. A GoRouter stub is still needed for
        // context.go('/sign-in') calls, so we wrap with a Router widget.
        //
        // However, mixing MaterialApp (navigator) and MaterialApp.router (GoRouter)
        // in the same widget tree is not straightforward, so we test the
        // Navigator.canPop outcome directly:
        // When ProfileScreen is the root route, canPop is false (covered above).
        // When pushed via Navigator, canPop is true.
        //
        // We build a MaterialApp with GoRouter at '/profile', then verify
        // with a Navigator-wrapped push that the back icon appears.
        await tester.pumpWidget(
          ProviderScope(
            overrides: _baseOverrides(),
            child: MaterialApp.router(
              routerConfig: GoRouter(
                initialLocation: '/stub',
                redirect: (_, state) {
                  if (state.uri.path == '/sign-in') return '/stub';
                  return null;
                },
                routes: [
                  GoRoute(
                    path: '/stub',
                    // The 'stub' page uses a Navigator to push ProfileScreen
                    // so that Navigator.canPop returns true.
                    builder: (ctx, __) => Scaffold(
                      body: Builder(
                        builder: (innerCtx) => ElevatedButton(
                          onPressed: () => Navigator.of(innerCtx).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ProfileScreen(),
                            ),
                          ),
                          child: const Text('Push Profile'),
                        ),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: '/sign-in',
                    builder: (_, __) => const Scaffold(),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // Tap to push ProfileScreen onto the Navigator stack.
        await tester.tap(find.text('Push Profile'));
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
      });
    },
  );

  testWidgets(
    'Session History shows SessionCard when upcomingSessionsProvider returns sessions',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildRootScreen(
            overrides: _baseOverrides(upcoming: [_stubSession()]),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.byType(SessionCard), findsOneWidget);
      });
    },
  );

  testWidgets(
    'Session History shows empty state icon when both session providers return []',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildRootScreen());
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.byIcon(Icons.history_outlined), findsOneWidget);
        expect(find.text('No session history yet'), findsOneWidget);
      });
    },
  );
}
