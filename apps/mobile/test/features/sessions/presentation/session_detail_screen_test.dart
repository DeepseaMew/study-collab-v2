// Widget tests for SessionDetailScreen.
//
// Smoke test: screen renders in loading, error, and data states.
// Verifies public pre-join view elements per ADR 0003.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/profile/presentation/providers/user_provider.dart';
import 'package:mobile/features/sessions/domain/entities/join_request_entity.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/domain/repositories/join_request_repository.dart';
import 'package:mobile/features/sessions/domain/repositories/session_repository.dart';
import 'package:mobile/features/sessions/presentation/providers/join_requests_provider.dart';
import 'package:mobile/features/sessions/presentation/providers/session_members_provider.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
import 'package:mobile/features/sessions/presentation/screens/session_detail_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

class _FakeFirebaseUser extends Fake implements User {
  _FakeFirebaseUser(this._uid);
  final String _uid;
  @override
  String get uid => _uid;
}

class _MockSessionRepository extends Mock implements SessionRepository {}

class _MockJoinRequestRepository extends Mock
    implements JoinRequestRepository {}

SessionEntity _session({
  String id = 'sess-1',
  String hostUid = 'host-1',
  List<String> memberUids = const [],
  String visibility = 'public',
}) {
  final now = DateTime(2026, 5, 18, 10);
  return SessionEntity(
    sessionId: id,
    hostUid: hostUid,
    hostFaculty: 'Engineering',
    title: 'Data Structures Study Group',
    description: 'A session about algorithms.',
    hashtags: const ['algorithms'],
    academicLevel: 'undergraduate',
    studentYear: 2,
    visibility: visibility,
    memberUids: memberUids,
    noteCount: 0,
    status: 'scheduled',
    scheduledAt: now,
    scheduledEndAt: now.add(const Duration(hours: 2)),
    location: 'CB2308',
    capacity: 10,
    hostDisplayName: 'Host User',
    createdAt: now,
    updatedAt: now,
  );
}

UserEntity _user(String uid) => UserEntity(
  uid: uid,
  displayName: 'User $uid',
  fullName: 'Full Name',
  email: '$uid@mail.kmutt.ac.th',
  hasHostedBefore: false,
  studentYear: 2,
  academicLevel: 'undergraduate',
  faculty: 'Engineering',
  profileScore: 0.0,
);

Widget _buildScreen({
  AsyncValue<SessionEntity?> sessionState = const AsyncValue.loading(),
  UserEntity? currentUser,
  String sessionId = 'sess-1',
}) {
  final sessionRepo = _MockSessionRepository();
  final requestRepo = _MockJoinRequestRepository();

  when(
    () => requestRepo.watchRequests(any()),
  ).thenAnswer((_) => Stream.value(const <JoinRequestEntity>[]));
  when(
    () => sessionRepo.watchMembers(any()),
  ).thenAnswer((_) => Stream.value(const <UserEntity>[]));

  final overrides = <Override>[
    sessionStreamProvider(sessionId).overrideWith(
      (_) => sessionState.when(
        loading: () => const Stream.empty(),
        error: (e, st) => Stream.error(e, st),
        data: (s) => Stream.value(s),
      ),
    ),
    sessionMembersProvider(
      sessionId,
    ).overrideWith((_) => Stream.value(const <UserEntity>[])),
    joinRequestsProvider(
      sessionId,
    ).overrideWith((_) => Stream.value(const <JoinRequestEntity>[])),
    firebaseAuthStateProvider.overrideWith(
      (_) => Stream.value(
        currentUser != null ? _FakeFirebaseUser(currentUser.uid) : null,
      ),
    ),
    sessionRepositoryProvider.overrideWithValue(sessionRepo),
    joinRequestRepositoryProvider.overrideWithValue(requestRepo),
  ];

  if (currentUser != null) {
    overrides.add(
      userProvider(currentUser.uid).overrideWith(
        (_) => Stream.value(currentUser),
      ),
    );
  }

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: SessionDetailScreen(sessionId: sessionId)),
  );
}

void main() {
  testWidgets(
    'SessionDetailScreen smoke test — loading state renders spinner',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen());
        // Do not pumpAndSettle — we want the loading state.
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    },
  );

  testWidgets('SessionDetailScreen — not-found state renders message', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _buildScreen(sessionState: const AsyncValue.data(null)),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Session not found'), findsOneWidget);
    });
  });

  testWidgets('SessionDetailScreen — data state renders session title', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _buildScreen(
          sessionState: AsyncValue.data(_session()),
          currentUser: _user('other-user'),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Data Structures Study Group'), findsWidgets);
    });
  });

  testWidgets(
    'SessionDetailScreen — non-member sees "Request to Join" button for public session',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(
            sessionState: AsyncValue.data(_session()),
            currentUser: _user('other-user'),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.text('Request to Join'), findsOneWidget);
      });
    },
  );

  testWidgets('SessionDetailScreen — member sees "Joined" badge', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _buildScreen(
          sessionState: AsyncValue.data(
            _session(memberUids: const ['member-1']),
          ),
          currentUser: _user('member-1'),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Joined'), findsOneWidget);
    });
  });

  testWidgets('SessionDetailScreen — host sees 3-dot menu', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _buildScreen(
          sessionState: AsyncValue.data(_session()),
          currentUser: _user('host-1'),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });
  });

  testWidgets(
    'SessionDetailScreen — private session shows "Join with Password" button',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(
            sessionState: AsyncValue.data(_session(visibility: 'private')),
            currentUser: _user('other-user'),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.text('Join with Password'), findsOneWidget);
      });
    },
  );

  testWidgets('SessionDetailScreen — error state renders error scaffold', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _buildScreen(
          sessionState: AsyncValue.error(
            Exception('Firestore error'),
            StackTrace.empty,
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Session not found'), findsOneWidget);
    });
  });
}
