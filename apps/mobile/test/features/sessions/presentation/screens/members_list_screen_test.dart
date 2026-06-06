import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/presentation/providers/session_members_provider.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
import 'package:mobile/features/sessions/presentation/screens/members_list_screen.dart';
import 'package:network_image_mock/network_image_mock.dart';

class _FakeFirebaseUser extends Fake implements User {
  _FakeFirebaseUser(this._uid);
  final String _uid;
  @override
  String get uid => _uid;
}

const _sessionId = 'sess-members-1';
const _hostUid = 'host-uid';

SessionEntity _stubSession() {
  final now = DateTime(2026, 6, 1, 10);
  return SessionEntity(
    sessionId: _sessionId,
    hostUid: _hostUid,
    hostFaculty: 'Engineering',
    title: 'Members Session',
    hashtags: const [],
    academicLevel: 'undergraduate',
    studentYear: 2,
    visibility: 'public',
    memberUids: const [_hostUid],
    noteCount: 0,
    status: 'scheduled',
    scheduledAt: now,
    location: 'CB2308',
    capacity: 10,
    hostDisplayName: 'Host Name',
    createdAt: now,
    updatedAt: now,
  );
}

UserEntity _stubUser(String uid, {String name = 'Alice'}) => UserEntity(
      uid: uid,
      displayName: name,
      fullName: name,
      email: '$uid@mail.kmutt.ac.th',
      hasHostedBefore: false,
      studentYear: 2,
      academicLevel: 'undergraduate',
      faculty: 'Engineering',
      profileScore: 0.0,
    );

Widget _buildScreen({
  AsyncValue<List<UserEntity>> membersState = const AsyncValue.data([]),
  AsyncValue<SessionEntity?> sessionState = const AsyncValue.data(null),
  String? currentUid,
}) {
  return ProviderScope(
    overrides: [
      sessionMembersProvider(_sessionId).overrideWith(
        (_) => membersState.when(
          loading: () => const Stream.empty(),
          error: (e, st) => Stream.error(e, st),
          data: (v) => Stream.value(v),
        ),
      ),
      sessionStreamProvider(_sessionId).overrideWith(
        (_) => sessionState.when(
          loading: () => const Stream.empty(),
          error: (e, st) => Stream.error(e, st),
          data: (s) => Stream.value(s),
        ),
      ),
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(
          currentUid != null ? _FakeFirebaseUser(currentUid) : null,
        ),
      ),
    ],
    child: MaterialApp(home: MembersListScreen(sessionId: _sessionId)),
  );
}

void main() {
  testWidgets('MembersListScreen — AppBar title is "Members"', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('Members'), findsOneWidget);
    });
  });

  testWidgets(
    'MembersListScreen — loading state renders spinner',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(membersState: const AsyncValue.loading()),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    },
  );

  testWidgets(
    'MembersListScreen — empty members list shows empty state',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(
          membersState: const AsyncValue.data([]),
          sessionState: AsyncValue.data(_stubSession()),
        ));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('No members yet.'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'MembersListScreen — error state shows "Could not load members."',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(
          membersState: AsyncValue.error(
            Exception('Firestore error'),
            StackTrace.empty,
          ),
        ));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('Could not load members.'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'MembersListScreen — populated list renders member display names',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(
          membersState: AsyncValue.data([
            _stubUser(_hostUid, name: 'Alice Host'),
            _stubUser('member-2', name: 'Bob Member'),
          ]),
          sessionState: AsyncValue.data(_stubSession()),
          currentUid: 'member-2',
        ));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('Alice Host'), findsOneWidget);
        expect(find.text('Bob Member'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'MembersListScreen — host member gets "Host" badge',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(
          membersState: AsyncValue.data([
            _stubUser(_hostUid, name: 'Alice Host'),
          ]),
          sessionState: AsyncValue.data(_stubSession()),
          currentUid: 'member-2',
        ));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('Host'), findsOneWidget);
      });
    },
  );
}
