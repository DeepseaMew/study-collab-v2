// Widget tests for MemberSessionDetailScreen.
//
// Smoke test: screen renders loading, error, and data states.
// Verifies 2-tab layout (Members, Notes) per ADR 0003.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/my_sessions/presentation/screens/member_session_detail_screen.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/presentation/providers/session_members_provider.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
import 'package:network_image_mock/network_image_mock.dart';

class _FakeFirebaseUser extends Fake implements User {
  _FakeFirebaseUser(this._uid);
  final String _uid;
  @override
  String get uid => _uid;
}

SessionEntity _session({String status = 'scheduled'}) {
  final now = DateTime(2026, 5, 18, 10);
  return SessionEntity(
    sessionId: 'sess-1',
    hostUid: 'host-1',
    hostFaculty: 'Engineering',
    title: 'Data Structures Study Group',
    hashtags: const ['algorithms'],
    academicLevel: 'undergraduate',
    studentYear: 2,
    visibility: 'public',
    memberUids: const ['member-1', 'host-1'],
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
  String currentUid = 'member-1',
}) {
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
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser(currentUid)),
      ),
    ],
    child: const MaterialApp(
      home: MemberSessionDetailScreen(sessionId: 'sess-1'),
    ),
  );
}

void main() {
  testWidgets(
    'MemberSessionDetailScreen smoke test — loading state renders spinner',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen());
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    },
  );

  testWidgets('MemberSessionDetailScreen — data state renders title', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _buildScreen(sessionState: AsyncValue.data(_session())),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Data Structures Study Group'), findsOneWidget);
    });
  });

  testWidgets('MemberSessionDetailScreen — two tabs rendered: Members, Notes', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _buildScreen(sessionState: AsyncValue.data(_session())),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Members'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
    });
  });

  testWidgets('MemberSessionDetailScreen — "Joined" status badge is visible', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _buildScreen(sessionState: AsyncValue.data(_session())),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Joined'), findsOneWidget);
    });
  });

  testWidgets('MemberSessionDetailScreen — error state renders error message', (
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

  testWidgets(
    'MemberSessionDetailScreen — null session renders not-found message',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildScreen(sessionState: const AsyncValue.data(null)),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.text('Session not found.'), findsOneWidget);
      });
    },
  );
}
