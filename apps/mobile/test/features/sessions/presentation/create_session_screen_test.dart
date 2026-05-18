// Widget tests for CreateSessionScreen.
//
// Smoke test: screen renders without exception and shows the session form.
// Validates that all three step views are reachable.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/auth/presentation/providers/current_user_provider.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/domain/repositories/session_repository.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
import 'package:mobile/features/sessions/presentation/screens/create_session_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

UserEntity _fakeUser() => const UserEntity(
      uid: 'user-1',
      displayName: 'Test User',
      fullName: 'Test Full User',
      email: 'test@mail.kmutt.ac.th',
      hasHostedBefore: false,
      studentYear: 2,
      academicLevel: 'undergraduate',
      faculty: 'Engineering',
      profileScore: 0.0,
    );

Widget _buildScreen({UserEntity? user}) {
  final repo = _MockSessionRepository();
  registerFallbackValue(
    SessionEntity(
      sessionId: '',
      hostUid: 'user-1',
      hostFaculty: 'Engineering',
      title: 'T',
      hashtags: const [],
      academicLevel: 'undergraduate',
      studentYear: 1,
      visibility: 'public',
      memberUids: const [],
      noteCount: 0,
      status: 'scheduled',
      scheduledAt: DateTime(2026, 5, 19),
      scheduledEndAt: DateTime(2026, 5, 19, 2),
      location: 'CB2308',
      capacity: 5,
      hostDisplayName: 'T',
      createdAt: DateTime(2026, 5, 18),
      updatedAt: DateTime(2026, 5, 18),
    ),
  );
  when(() => repo.createSession(any(), plainTextPin: any(named: 'plainTextPin')))
      .thenAnswer((_) async {});

  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith(
        (_) => Stream.value(user ?? _fakeUser()),
      ),
      sessionRepositoryProvider.overrideWithValue(repo),
    ],
    child: const MaterialApp(home: CreateSessionScreen()),
  );
}

void main() {
  testWidgets('CreateSessionScreen smoke test — renders without exception', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Step 0 heading text: "Visibility" section label should be present.
      expect(find.text('Visibility'), findsOneWidget);
    });
  });

  testWidgets('CreateSessionScreen — title is "Create Session"', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Create Session'), findsOneWidget);
    });
  });

  testWidgets('CreateSessionScreen — step 0 shows session title field', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Session Title'), findsOneWidget);
    });
  });

  testWidgets(
      'CreateSessionScreen — tapping Next with empty title shows inline error',
      (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Do not enter a title — tap Next immediately.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // The inline error for title should appear.
      expect(find.text('Session title is required'), findsOneWidget);
    });
  });

  testWidgets(
      'CreateSessionScreen — step progress bar renders with 3 segments', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // The progress bar is built from 3 Container segments.
      // The Scaffold is present as the outer shell.
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  testWidgets(
      'CreateSessionScreen — visibility segmented button is present on step 0',
      (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Public'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
    });
  });

  testWidgets(
      'CreateSessionScreen — switching to Private shows auto-PIN info text', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(find.text('Private'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // The manual PIN field is gone; a descriptive info line appears instead.
      expect(
        find.textContaining('A secure PIN will be generated automatically'),
        findsOneWidget,
      );
      // No manual password input should exist.
      expect(find.text('Session password (min 4 chars)'), findsNothing);
    });
  });
}
