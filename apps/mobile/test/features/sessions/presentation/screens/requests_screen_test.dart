import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/sessions/domain/entities/join_request_entity.dart';
import 'package:mobile/features/sessions/domain/repositories/join_request_repository.dart';
import 'package:mobile/features/sessions/presentation/providers/join_requests_provider.dart';
import 'package:mobile/features/sessions/presentation/screens/requests_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

class _MockJoinRequestRepository extends Mock
    implements JoinRequestRepository {}

class _FakeFirebaseUser extends Fake implements User {
  _FakeFirebaseUser(this._uid);
  final String _uid;
  @override
  String get uid => _uid;
}

const _sessionId = 'sess-req-1';
const _callerUid = 'host-uid';

JoinRequestEntity _stubRequest({
  String uid = 'requester-1',
  String name = 'Dan Lee',
}) {
  return JoinRequestEntity(
    uid: uid,
    displayName: name,
    requestedAt: DateTime(2026, 5, 20),
  );
}

Widget _buildScreen({
  AsyncValue<List<JoinRequestEntity>> requestsState = const AsyncValue.data([]),
  bool authenticated = true,
}) {
  final mockRepo = _MockJoinRequestRepository();
  when(
    () => mockRepo.approveRequest(any(), any(), any()),
  ).thenAnswer((_) async {});
  when(
    () => mockRepo.declineRequest(any(), any(), any()),
  ).thenAnswer((_) async {});
  when(() => mockRepo.watchRequests(any())).thenAnswer((_) => Stream.value([]));

  return ProviderScope(
    overrides: [
      firebaseAuthStateProvider.overrideWith(
        (_) =>
            Stream.value(authenticated ? _FakeFirebaseUser(_callerUid) : null),
      ),
      joinRequestsProvider(_sessionId).overrideWith(
        (_) => requestsState.when(
          loading: () => const Stream.empty(),
          error: (e, st) => Stream.error(e, st),
          data: (v) => Stream.value(v),
        ),
      ),
      joinRequestRepositoryProvider.overrideWithValue(mockRepo),
    ],
    child: const MaterialApp(home: RequestsScreen(sessionId: _sessionId)),
  );
}

void main() {
  testWidgets('RequestsScreen — renders "Join Requests" title', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('Join Requests'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  testWidgets('RequestsScreen — unauthenticated shows sign-in prompt', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen(authenticated: false));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('Sign in to view requests.'), findsOneWidget);
    });
  });

  testWidgets(
    'RequestsScreen — loading state renders CircularProgressIndicator',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(requestsState: const AsyncValue.loading()),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    },
  );

  testWidgets('RequestsScreen — empty list shows "No pending requests."', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('No pending requests.'), findsOneWidget);
    });
  });

  testWidgets('RequestsScreen — error state shows "Could not load requests."', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _buildScreen(
          requestsState: AsyncValue.error(
            Exception('Firestore error'),
            StackTrace.empty,
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('Could not load requests.'), findsOneWidget);
    });
  });

  testWidgets(
    'RequestsScreen — populated list renders Approve and Decline buttons',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(requestsState: AsyncValue.data([_stubRequest()])),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('Dan Lee'), findsOneWidget);
        expect(find.text('Approve'), findsOneWidget);
        expect(find.text('Decline'), findsOneWidget);
      });
    },
  );
}
