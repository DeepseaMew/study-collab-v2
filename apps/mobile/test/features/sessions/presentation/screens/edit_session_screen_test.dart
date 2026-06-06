import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/domain/repositories/session_repository.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
import 'package:mobile/features/sessions/presentation/screens/edit_session_screen.dart';
import 'package:mobile/features/sessions/presentation/widgets/session_form.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

class _FakeFirebaseUser extends Fake implements User {
  _FakeFirebaseUser(this._uid);
  final String _uid;
  @override
  String get uid => _uid;
}

const _sessionId = 'sess-edit-1';

SessionEntity _stubSession({String hostUid = 'host-uid'}) {
  final now = DateTime(2026, 6, 1, 10);
  return SessionEntity(
    sessionId: _sessionId,
    hostUid: hostUid,
    hostFaculty: 'Engineering',
    title: 'Edit Me Session',
    hashtags: const ['study'],
    academicLevel: 'undergraduate',
    studentYear: 2,
    visibility: 'public',
    memberUids: [hostUid],
    noteCount: 0,
    status: 'scheduled',
    scheduledAt: now,
    scheduledEndAt: now.add(const Duration(hours: 2)),
    location: 'CB2308',
    capacity: 10,
    hostDisplayName: 'Host Name',
    createdAt: now,
    updatedAt: now,
  );
}

Widget _buildScreen({
  AsyncValue<SessionEntity?> sessionState = const AsyncValue.loading(),
  String? currentUid,
}) {
  final mockRepo = _MockSessionRepository();
  return ProviderScope(
    overrides: [
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
      sessionRepositoryProvider.overrideWithValue(mockRepo),
    ],
    child: MaterialApp(home: EditSessionScreen(sessionId: _sessionId)),
  );
}

void main() {
  testWidgets('EditSessionScreen — loading state renders spinner', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  testWidgets(
    'EditSessionScreen — null data renders "Session not found." error scaffold',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(
            sessionState: const AsyncValue.data(null),
            currentUid: 'host-uid',
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('Session not found.'), findsOneWidget);
      });
    },
  );

  testWidgets('EditSessionScreen — non-host sees "not authorised" message', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _buildScreen(
          sessionState: AsyncValue.data(_stubSession(hostUid: 'host-uid')),
          currentUid: 'other-user',
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(
        find.text('You are not authorised to edit this session.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('EditSessionScreen — host sees SessionForm', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _buildScreen(
          sessionState: AsyncValue.data(_stubSession(hostUid: 'host-uid')),
          currentUid: 'host-uid',
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(SessionForm), findsOneWidget);
    });
  });
}
