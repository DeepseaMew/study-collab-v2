import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/home/presentation/screens/home_screen.dart';
import 'package:mobile/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:mobile/features/profile/presentation/providers/user_provider.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/presentation/providers/join_requests_provider.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
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
  studentYear: 1,
  academicLevel: 'undergraduate',
  faculty: 'Engineering',
  profileScore: 0.0,
);

SessionEntity _stubSession({String sessionId = 'sess-1'}) {
  final future = DateTime(2099, 1, 1, 10);
  return SessionEntity(
    sessionId: sessionId,
    hostUid: 'host-uid',
    hostFaculty: 'Engineering',
    title: 'Calculus Study Group',
    hashtags: const ['math'],
    academicLevel: 'undergraduate',
    studentYear: 2,
    visibility: 'public',
    memberUids: const ['host-uid'],
    noteCount: 0,
    status: 'scheduled',
    scheduledAt: future,
    scheduledEndAt: future.add(const Duration(hours: 2)),
    location: 'CB2308',
    capacity: 10,
    hostDisplayName: 'Host Name',
    createdAt: future,
    updatedAt: future,
  );
}

Widget _buildScreen({
  AsyncValue<List<SessionEntity>> sessions = const AsyncValue.data([]),
}) {
  final populated = sessions is AsyncData<List<SessionEntity>>
      ? (sessions as AsyncData<List<SessionEntity>>).value
      : <SessionEntity>[];

  return ProviderScope(
    overrides: [
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser(_uid)),
      ),
      userProvider(_uid).overrideWith((_) => Stream.value(_stubUser)),
      publicSessionsStreamProvider.overrideWith(
        (_) => sessions.when(
          loading: () => const Stream.empty(),
          error: (e, st) => Stream.error(e, st),
          data: (v) => Stream.value(v),
        ),
      ),
      unreadNotificationCountProvider(_uid).overrideWith(
        (_) => Stream.value(0),
      ),
      for (final s in populated) ...[
        myPendingRequestProvider(s.sessionId, _uid).overrideWith(
          (_) => Stream.value(false),
        ),
        userProvider(s.hostUid).overrideWith(
          (_) => Stream.value(_stubUser),
        ),
      ],
    ],
    child: const MaterialApp(home: HomeScreen()),
  );
}

void main() {
  testWidgets('HomeScreen — renders without exception', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  testWidgets(
    'HomeScreen — loading state renders CircularProgressIndicator',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(sessions: const AsyncValue.loading()),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    },
  );

  testWidgets(
    'HomeScreen — empty sessions shows "All caught up!" empty state',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('All caught up!'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'HomeScreen — populated sessions render a SessionCard',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(sessions: AsyncValue.data([_stubSession()])),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.byType(SessionCard), findsOneWidget);
        expect(find.text('Calculus Study Group'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'HomeScreen — search bar placeholder text is present',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(
          find.text('Search sessions, #hashtags, @hosts...'),
          findsOneWidget,
        );
      });
    },
  );

  testWidgets('HomeScreen — "Join with PIN" button is present', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('Join with PIN'), findsOneWidget);
    });
  });

  testWidgets(
    'HomeScreen — greeting contains user first name',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.textContaining('Test'), findsWidgets);
      });
    },
  );
}
