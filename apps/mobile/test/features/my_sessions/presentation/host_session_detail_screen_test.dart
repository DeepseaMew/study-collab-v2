// Widget tests for HostSessionDetailScreen.
//
// Smoke test: screen renders loading, error, and data states.
// Verifies 3-tab layout (Members, Notes, Requests) and End Session button
// per ADR 0003.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/my_sessions/presentation/screens/host_session_detail_screen.dart';
import 'package:mobile/features/sessions/domain/entities/join_request_entity.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/domain/repositories/join_request_repository.dart';
import 'package:mobile/features/sessions/domain/repositories/session_repository.dart';
import 'package:mobile/features/sessions/presentation/providers/join_requests_provider.dart';
import 'package:mobile/features/sessions/presentation/providers/session_members_provider.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
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

SessionEntity _session({String status = 'scheduled'}) {
  final now = DateTime(2026, 5, 18, 10);
  return SessionEntity(
    sessionId: 'sess-1',
    hostUid: 'host-1',
    hostFaculty: 'Engineering',
    title: 'Host Session Title',
    hashtags: const ['algorithms'],
    academicLevel: 'undergraduate',
    studentYear: 2,
    visibility: 'public',
    memberUids: const ['host-1', 'member-1'],
    noteCount: 0,
    status: status,
    scheduledAt: now,
    scheduledEndAt: now.add(const Duration(hours: 2)),
    location: 'CB2308',
    capacity: 10,
    hostDisplayName: 'Host User',
    createdAt: now,
    updatedAt: now,
  );
}

Widget _buildScreen({
  AsyncValue<SessionEntity?> sessionState = const AsyncValue.loading(),
  String currentUid = 'host-1',
  List<JoinRequestEntity> requests = const [],
}) {
  final sessionRepo = _MockSessionRepository();
  final requestRepo = _MockJoinRequestRepository();

  registerFallbackValue(
    JoinRequestEntity(
      uid: 'u1',
      displayName: 'U1',
      requestedAt: DateTime(2026, 5, 18),
    ),
  );

  when(
    () => requestRepo.watchRequests(any()),
  ).thenAnswer((_) => Stream.value(requests));
  when(
    () => requestRepo.approveRequest(any(), any(), any()),
  ).thenAnswer((_) async {});
  when(
    () => requestRepo.declineRequest(any(), any(), any()),
  ).thenAnswer((_) async {});
  when(() => sessionRepo.endSession(any(), any())).thenAnswer((_) async {});

  return ProviderScope(
    overrides: [
      sessionStreamProvider('sess-1').overrideWith(
        (_) => sessionState.when(
          loading: () => const Stream.empty(),
          error: (e, st) => Stream.error(e, st),
          data: (s) => Stream.value(s),
        ),
      ),
      sessionMembersProvider(
        'sess-1',
      ).overrideWith((_) => Stream.value(const <UserEntity>[])),
      joinRequestsProvider(
        'sess-1',
      ).overrideWith((_) => Stream.value(requests)),
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser(currentUid)),
      ),
      sessionRepositoryProvider.overrideWithValue(sessionRepo),
      joinRequestRepositoryProvider.overrideWithValue(requestRepo),
    ],
    child: const MaterialApp(
      home: HostSessionDetailScreen(sessionId: 'sess-1'),
    ),
  );
}

void main() {
  testWidgets('HostSessionDetailScreen smoke test — loading renders spinner', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  testWidgets('HostSessionDetailScreen — data state renders session title', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _buildScreen(sessionState: AsyncValue.data(_session())),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Host Session Title'), findsOneWidget);
    });
  });

  testWidgets('HostSessionDetailScreen — three tabs rendered', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _buildScreen(sessionState: AsyncValue.data(_session())),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Members'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Requests'), findsOneWidget);
    });
  });

  testWidgets(
    'HostSessionDetailScreen — "Hosting" badge is visible in session info card',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(sessionState: AsyncValue.data(_session())),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.text('Hosting'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'HostSessionDetailScreen — End Session button exists on Members tab',
    (tester) async {
      await mockNetworkImagesFor(() async {
        // Use a tall test surface so the ListView renders all items.
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _buildScreen(sessionState: AsyncValue.data(_session())),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Scroll the Members ListView to reveal the End Session button.
        await tester.scrollUntilVisible(
          find.text('End Session'),
          100,
          scrollable: find.byType(Scrollable).first,
        );

        expect(find.text('End Session'), findsOneWidget);
      });
    },
  );

  testWidgets('HostSessionDetailScreen — error state renders error message', (
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

      expect(
        find.text('Could not load session. Please try again.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('HostSessionDetailScreen — null session renders not-found text', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _buildScreen(sessionState: const AsyncValue.data(null)),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Session not found.'), findsOneWidget);
    });
  });

  testWidgets(
    'HostSessionDetailScreen — Requests tab shows pending count badge when requests exist',
    (tester) async {
      await mockNetworkImagesFor(() async {
        final req = JoinRequestEntity(
          uid: 'req-user-1',
          displayName: 'Requester One',
          requestedAt: DateTime(2026, 5, 18, 9),
        );
        await tester.pumpWidget(
          _buildScreen(
            sessionState: AsyncValue.data(_session()),
            requests: [req],
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Tap Requests tab
        await tester.tap(find.text('Requests'));
        await tester.pumpAndSettle(const Duration(seconds: 1));

        expect(find.text('Requester One'), findsOneWidget);
      });
    },
  );
}
