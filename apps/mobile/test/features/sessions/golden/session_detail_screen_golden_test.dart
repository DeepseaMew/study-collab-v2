// Golden tests for SessionDetailScreen.
// Two scales: 1.0 and 1.5. Fixed locale: th. Fixed theme.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/current_user_provider.dart';
import 'package:mobile/features/sessions/domain/entities/join_request_entity.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/domain/repositories/join_request_repository.dart';
import 'package:mobile/features/sessions/domain/repositories/session_repository.dart';
import 'package:mobile/features/sessions/presentation/providers/join_requests_provider.dart';
import 'package:mobile/features/sessions/presentation/providers/session_members_provider.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
import 'package:mobile/features/sessions/presentation/screens/session_detail_screen.dart';
import 'package:mobile/shared/theme/app_colors.dart';
import 'package:mobile/shared/theme/app_typography.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

class _MockJoinRequestRepository extends Mock
    implements JoinRequestRepository {}

SessionEntity _session() {
  final now = DateTime(2026, 5, 18, 10);
  return SessionEntity(
    sessionId: 'sess-golden',
    hostUid: 'host-1',
    hostFaculty: 'Engineering',
    title: 'Data Structures Study Group',
    description: 'A session about algorithms and data structures.',
    hashtags: const ['algorithms', 'datastructures'],
    academicLevel: 'undergraduate',
    studentYear: 2,
    visibility: 'public',
    memberUids: const ['host-1', 'member-1', 'member-2'],
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

Widget _buildScreen(double textScale) {
  final sessionRepo = _MockSessionRepository();
  final requestRepo = _MockJoinRequestRepository();

  when(
    () => requestRepo.watchRequests(any()),
  ).thenAnswer((_) => Stream.value(const <JoinRequestEntity>[]));
  when(
    () => sessionRepo.watchMembers(any()),
  ).thenAnswer((_) => Stream.value(const <UserEntity>[]));

  const fakeUser = UserEntity(
    uid: 'viewer-1',
    displayName: 'Viewer User',
    fullName: 'Viewer Full',
    email: 'viewer@mail.kmutt.ac.th',
    hasHostedBefore: false,
    studentYear: 2,
    academicLevel: 'undergraduate',
    faculty: 'Engineering',
    profileScore: 0.0,
  );

  return ProviderScope(
    overrides: [
      sessionStreamProvider(
        'sess-golden',
      ).overrideWith((_) => Stream.value(_session())),
      sessionMembersProvider(
        'sess-golden',
      ).overrideWith((_) => Stream.value(const <UserEntity>[])),
      joinRequestsProvider(
        'sess-golden',
      ).overrideWith((_) => Stream.value(const <JoinRequestEntity>[])),
      currentUserProvider.overrideWith((_) => Stream.value(fakeUser)),
      sessionRepositoryProvider.overrideWithValue(sessionRepo),
      joinRequestRepositoryProvider.overrideWithValue(requestRepo),
    ],
    child: MaterialApp(
      locale: const Locale('th'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          primary: AppColors.accent,
          error: AppColors.error,
          surface: AppColors.background,
        ),
        textTheme: AppTypography.textTheme,
        useMaterial3: true,
      ),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: const SessionDetailScreen(sessionId: 'sess-golden'),
      ),
    ),
  );
}

void main() {
  group('SessionDetailScreen golden', () {
    testWidgets('scale 1.0 — th locale', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(1.0));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await expectLater(
          find.byType(SessionDetailScreen),
          matchesGoldenFile('goldens/session_detail_screen_scale_1.0_th.png'),
        );
      });
    });

    testWidgets('scale 1.5 — th locale', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(1.5));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await expectLater(
          find.byType(SessionDetailScreen),
          matchesGoldenFile('goldens/session_detail_screen_scale_1.5_th.png'),
        );
      });
    });
  });
}
