import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/profile/presentation/providers/user_provider.dart';
import 'package:mobile/features/search/domain/entities/search_filter.dart';
import 'package:mobile/features/search/presentation/providers/filter_provider.dart';
import 'package:mobile/features/search/presentation/providers/search_filter_provider.dart';
import 'package:mobile/features/search/presentation/providers/search_provider.dart';
import 'package:mobile/features/search/presentation/screens/search_screen.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/presentation/providers/join_requests_provider.dart';
import 'package:mobile/shared/widgets/session_card.dart';
import 'package:network_image_mock/network_image_mock.dart';

class _FakeFirebaseUser extends Fake implements User {
  _FakeFirebaseUser(this._uid);
  final String _uid;
  @override
  String get uid => _uid;
}

const _uid = 'searcher-uid';

UserEntity _stubUserEntity(String uid) => UserEntity(
  uid: uid,
  displayName: 'Host',
  fullName: 'Host Name',
  email: '$uid@mail.kmutt.ac.th',
  hasHostedBefore: true,
  studentYear: 3,
  academicLevel: 'undergraduate',
  faculty: 'Engineering',
  profileScore: 0.8,
);

SessionEntity _stubSession(String id) {
  final now = DateTime(2026, 6, 1, 10);
  return SessionEntity(
    sessionId: id,
    hostUid: 'host-uid',
    hostFaculty: 'Engineering',
    title: 'Physics Study Session',
    hashtags: const ['physics'],
    academicLevel: 'undergraduate',
    studentYear: 2,
    visibility: 'public',
    memberUids: const ['host-uid'],
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

class _FakeSearchNotifier extends SearchNotifier {
  _FakeSearchNotifier(this._result);
  final List<SessionEntity> _result;

  @override
  FutureOr<List<SessionEntity>> build() => _result;

  @override
  Future<void> search(SearchFilter filter) async {}
}

class _FakeQuickFilterNotifier extends QuickFilterNotifier {
  @override
  QuickFilters build() => const QuickFilters();
}

class _FakeSubjectFilterNotifier extends SubjectFilterNotifier {
  @override
  Set<String> build() => const {};
}

class _FakeSearchFilterNotifier extends SearchFilterNotifier {
  @override
  SearchFilter build() => const SearchFilter();
}

Widget _buildScreen({List<SessionEntity> sessions = const []}) {
  return ProviderScope(
    overrides: [
      firebaseAuthStateProvider.overrideWith(
        (_) => Stream.value(_FakeFirebaseUser(_uid)),
      ),
      searchNotifierProvider.overrideWith(() => _FakeSearchNotifier(sessions)),
      quickFilterNotifierProvider.overrideWith(
        () => _FakeQuickFilterNotifier(),
      ),
      subjectFilterNotifierProvider.overrideWith(
        () => _FakeSubjectFilterNotifier(),
      ),
      searchFilterNotifierProvider.overrideWith(
        () => _FakeSearchFilterNotifier(),
      ),
      for (final s in sessions) ...[
        myPendingRequestProvider(
          s.sessionId,
          _uid,
        ).overrideWith((_) => Stream.value(false)),
        userProvider(
          s.hostUid,
        ).overrideWith((_) => Stream.value(_stubUserEntity(s.hostUid))),
      ],
    ],
    child: const MaterialApp(home: SearchScreen()),
  );
}

void main() {
  testWidgets('SearchScreen — renders with "Search sessions" title', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('Search sessions'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  testWidgets('SearchScreen — empty results show "No sessions found"', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('No sessions found'), findsOneWidget);
    });
  });

  testWidgets('SearchScreen — populated results render SessionCard', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen(sessions: [_stubSession('s1')]));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(SessionCard), findsOneWidget);
      expect(find.text('Physics Study Session'), findsOneWidget);
    });
  });
}
