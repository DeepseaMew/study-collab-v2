// Widget tests for HomeScreen — additions for feat/profile-and-friends.
//
// Tests:
//   - "Join with PIN" OutlinedButton is present in the widget tree
//   - SessionCard renders "Pending..." text when myPendingRequestProvider returns true

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/home/presentation/screens/home_screen.dart';
import 'package:mobile/features/profile/presentation/providers/user_provider.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/domain/repositories/session_repository.dart';
import 'package:mobile/features/sessions/presentation/providers/join_requests_provider.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

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
  final now = DateTime(2026, 5, 20, 10);
  return SessionEntity(
    sessionId: sessionId,
    hostUid: 'host-uid',
    hostFaculty: 'Engineering',
    title: 'Algebra Study Group',
    hashtags: const ['math'],
    academicLevel: 'undergraduate',
    studentYear: 2,
    visibility: 'public',
    // Ensure current user is NOT a member so the session appears in the feed.
    memberUids: const ['host-uid'],
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

Widget _buildScreen({
  List<SessionEntity> sessions = const [],
  bool isPending = false,
  String sessionId = 'sess-1',
}) {
  final mockSessionRepo = _MockSessionRepository();
  when(
    () => mockSessionRepo.watchPublicSessions(),
  ).thenAnswer((_) => Stream.value(sessions));

  return ProviderScope(
    overrides: [
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser(_uid)),
      ),
      userProvider(_uid).overrideWith((_) => Stream.value(_stubUser)),
      publicSessionsStreamProvider.overrideWith((_) => Stream.value(sessions)),
      sessionRepositoryProvider.overrideWithValue(mockSessionRepo),
      if (sessions.isNotEmpty)
        myPendingRequestProvider(
          sessionId,
          _uid,
        ).overrideWith((_) => Stream.value(isPending)),
    ],
    child: const MaterialApp(home: HomeScreen()),
  );
}

void main() {
  testWidgets('"Join with PIN" OutlinedButton is present in the widget tree', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Join with PIN'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsAtLeastNWidgets(1));
    });
  });

  testWidgets(
    'SessionCard renders "Pending..." text when myPendingRequestProvider returns true',
    (tester) async {
      await mockNetworkImagesFor(() async {
        final session = _stubSession();
        await tester.pumpWidget(
          _buildScreen(
            sessions: [session],
            isPending: true,
            sessionId: session.sessionId,
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.text('Pending...'), findsOneWidget);
      });
    },
  );
}
