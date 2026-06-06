// Widget tests for RatingBottomSheet (ADR 0009 Sub-decision 2).
//
// Verifies:
//   - Pops and shows snackbar when ratingEnabled is false
//   - Pops silently when hasRated is true
//   - Renders member list excluding current user
//   - "Submit" disabled when no member is toggled
//   - "Submit" enabled when at least one member is toggled
//   - Tapping X (close) closes the sheet
//   - Tapping "Skip" closes the sheet
//   - AsyncLoading state disables Submit and shows CircularProgressIndicator
//   - AsyncError state renders inline error banner with correct message

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/rating/domain/entities/rating_entity.dart';
import 'package:mobile/features/rating/domain/repositories/rating_repository.dart';
import 'package:mobile/features/rating/presentation/providers/has_rated_provider.dart';
import 'package:mobile/features/rating/presentation/providers/rating_flag_provider.dart';
import 'package:mobile/features/rating/presentation/providers/rating_provider.dart';
import 'package:mobile/features/rating/presentation/providers/rating_repository_provider.dart';
import 'package:mobile/features/rating/presentation/providers/session_ratings_provider.dart';
import 'package:mobile/features/rating/presentation/widgets/rating_bottom_sheet.dart';
import 'package:mobile/core/errors/rating_error.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

class _MockRatingRepository extends Mock implements RatingRepository {}

const _sessionId = 'sess-bs';
const _currentUid = 'user-current';
const _hostUid = 'user-host';
const _member1Uid = 'user-member-1';
const _member2Uid = 'user-member-2';

UserEntity _user(String uid, {String? name, String? photoUrl}) => UserEntity(
  uid: uid,
  displayName: name ?? 'User $uid',
  fullName: 'Full $uid',
  email: '$uid@mail.kmutt.ac.th',
  hasHostedBefore: false,
  studentYear: 2,
  academicLevel: 'undergraduate',
  faculty: 'Engineering',
  profileScore: 0.0,
  photoUrl: photoUrl,
);

final _members = [
  _user(_currentUid, name: 'Current User'),
  _user(_hostUid, name: 'Host User'),
  _user(_member1Uid, name: 'Member One'),
  _user(_member2Uid, name: 'Member Two'),
];

/// Opens a RatingBottomSheet via [showModalBottomSheet] on a minimal scaffold.
Widget _buildApp({
  bool ratingEnabled = true,
  bool hasRated = false,
  AsyncValue<void> ratingState = const AsyncValue.data(null),
  List<RatingEntity> sessionRatings = const [],
  _MockRatingRepository? repo,
}) {
  final mockRepo = repo ?? _MockRatingRepository();
  when(() => mockRepo.submitRatings(any(), any())).thenAnswer((_) async {});
  when(
    () => mockRepo.watchSessionRatings(any()),
  ).thenAnswer((_) => Stream.value(const []));
  when(
    () => mockRepo.hasRatedInSession(any(), any()),
  ).thenAnswer((_) async => hasRated);

  return ProviderScope(
    overrides: [
      ratingEnabledProvider.overrideWithValue(ratingEnabled),
      hasRatedProvider(
        _sessionId,
        _currentUid,
      ).overrideWith((_) async => hasRated),
      ratingRepositoryProvider.overrideWithValue(mockRepo),
      sessionRatingsProvider(
        _sessionId,
      ).overrideWith((_) => Stream.value(sessionRatings)),
      ratingNotifierProvider(
        _sessionId,
      ).overrideWith(() => _FakeRatingNotifier(ratingState)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: ctx,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => RatingBottomSheet(
                  sessionId: _sessionId,
                  members: _members,
                  currentUserId: _currentUid,
                  hostUid: _hostUid,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Fake notifier that returns a fixed state for testing.
class _FakeRatingNotifier extends RatingNotifier {
  _FakeRatingNotifier(this._fixedState);
  final AsyncValue<void> _fixedState;

  @override
  AsyncValue<void> build(String sessionId) => _fixedState;

  @override
  Future<void> submitRatings(
    List<String> rateeUids,
    List<String> sessionMemberUids,
  ) async {
    state = const AsyncValue.loading();
  }
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  group('RatingBottomSheet — disabled / already-rated guards', () {
    testWidgets('pops and shows snackbar when ratingEnabled is false', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(ratingEnabled: false));
      await _openSheet(tester);
      await tester.pumpAndSettle();

      // Sheet should not be visible
      expect(find.text('Rate Session Members'), findsNothing);
      // Snackbar with "not available" text
      expect(find.textContaining('not available'), findsOneWidget);
    });

    testWidgets('pops silently when hasRated is true', (tester) async {
      await tester.pumpWidget(_buildApp(hasRated: true));
      await _openSheet(tester);
      await tester.pumpAndSettle();

      expect(find.text('Rate Session Members'), findsNothing);
    });
  });

  group('RatingBottomSheet — member list', () {
    testWidgets('renders members excluding current user', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildApp());
        await _openSheet(tester);

        // Current user should NOT appear
        expect(find.text('Current User'), findsNothing);
        // Other members should appear
        expect(find.text('Host User'), findsOneWidget);
        expect(find.text('Member One'), findsOneWidget);
        expect(find.text('Member Two'), findsOneWidget);
      });
    });

    testWidgets('renders "Host" badge on host member row', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildApp());
        await _openSheet(tester);

        expect(find.text('Host'), findsOneWidget);
      });
    });

    testWidgets('shows search field', (tester) async {
      await tester.pumpWidget(_buildApp());
      await _openSheet(tester);

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('search filters member list by name', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildApp());
        await _openSheet(tester);

        await tester.enterText(find.byType(TextField), 'Host');
        await tester.pump();

        expect(find.text('Host User'), findsOneWidget);
        expect(find.text('Member One'), findsNothing);
        expect(find.text('Member Two'), findsNothing);
      });
    });

    testWidgets('shows "No members found." when search yields no results', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp());
      await _openSheet(tester);

      await tester.enterText(find.byType(TextField), 'ZZZNOTEXIST');
      await tester.pump();

      expect(find.text('No members found.'), findsOneWidget);
    });
  });

  group('RatingBottomSheet — Submit button state', () {
    testWidgets('Submit is disabled initially (no member toggled)', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildApp());
        await _openSheet(tester);

        final submitBtn = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Submit'),
        );
        expect(submitBtn.onPressed, isNull);
      });
    });

    testWidgets('Submit is enabled after toggling one member', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildApp());
        await _openSheet(tester);

        // Tap the thumbs-up icon for the first rateable member
        final thumbIcons = find.byIcon(Icons.thumb_up_outlined);
        await tester.tap(thumbIcons.first);
        await tester.pump();

        final submitBtn = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Submit'),
        );
        expect(submitBtn.onPressed, isNotNull);
      });
    });

    testWidgets('Submit is disabled again after un-toggling the only member', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildApp());
        await _openSheet(tester);

        final icon = find.byIcon(Icons.thumb_up_outlined).first;
        await tester.tap(icon);
        await tester.pump();

        // Now toggle it back off
        await tester.tap(find.byIcon(Icons.thumb_up).first);
        await tester.pump();

        final submitBtn = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Submit'),
        );
        expect(submitBtn.onPressed, isNull);
      });
    });
  });

  group('RatingBottomSheet — close actions', () {
    testWidgets('tapping the X button closes the sheet', (tester) async {
      await tester.pumpWidget(_buildApp());
      await _openSheet(tester);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Rate Session Members'), findsNothing);
    });

    testWidgets('tapping Skip closes the sheet', (tester) async {
      await tester.pumpWidget(_buildApp());
      await _openSheet(tester);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Rate Session Members'), findsNothing);
    });
  });

  group('RatingBottomSheet — AsyncLoading state', () {
    // CircularProgressIndicator has an infinite animation; use pump(Duration)
    // instead of pumpAndSettle to avoid the 100-frame timeout.
    Future<void> openSheetForLoading(WidgetTester tester) async {
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets(
      'Submit is disabled and shows CircularProgressIndicator while loading',
      (tester) async {
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            _buildApp(ratingState: const AsyncValue.loading()),
          );
          await openSheetForLoading(tester);

          // In AsyncLoading the FilledButton shows a CPI, not "Submit" text.
          // Locate it by type — there is exactly one FilledButton in the sheet.
          final submitBtn = tester.widget<FilledButton>(
            find.byType(FilledButton),
          );
          expect(submitBtn.onPressed, isNull);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        });
      },
    );

    testWidgets('X button is disabled while loading', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildApp(ratingState: const AsyncValue.loading()),
        );
        await openSheetForLoading(tester);

        final closeBtn = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.close),
        );
        expect(closeBtn.onPressed, isNull);
      });
    });

    testWidgets('Skip button is disabled while loading', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildApp(ratingState: const AsyncValue.loading()),
        );
        await openSheetForLoading(tester);

        final skipBtn = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Skip'),
        );
        expect(skipBtn.onPressed, isNull);
      });
    });
  });

  group('RatingBottomSheet — AsyncError state', () {
    testWidgets('renders inline error banner for submit failed', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildApp(
            ratingState: const AsyncValue.error(
              RatingError.submitFailed('test_error'),
              StackTrace.empty,
            ),
          ),
        );
        await _openSheet(tester);

        expect(find.textContaining('Could not submit ratings'), findsOneWidget);
      });
    });

    testWidgets('renders inline error banner for offline error', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildApp(
            ratingState: const AsyncValue.error(
              RatingError.offlineNotSupported(),
              StackTrace.empty,
            ),
          ),
        );
        await _openSheet(tester);

        expect(find.textContaining('internet connection'), findsOneWidget);
      });
    });

    testWidgets('renders inline error banner for already rated', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildApp(
            ratingState: const AsyncValue.error(
              RatingError.alreadyRated(),
              StackTrace.empty,
            ),
          ),
        );
        await _openSheet(tester);

        expect(find.textContaining('already rated'), findsOneWidget);
      });
    });

    testWidgets('Submit remains enabled after error (can retry)', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildApp(
            ratingState: const AsyncValue.error(
              RatingError.submitFailed('retry'),
              StackTrace.empty,
            ),
          ),
        );
        await _openSheet(tester);

        // Toggle a member to enable submit
        await tester.tap(find.byIcon(Icons.thumb_up_outlined).first);
        await tester.pump();

        final submitBtn = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Submit'),
        );
        expect(submitBtn.onPressed, isNotNull);
      });
    });
  });

  group('RatingBottomSheet — Semantics (accessibility)', () {
    testWidgets('each rateable member has a Semantics "Rate [name]" label', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildApp());
        await _openSheet(tester);

        // Find any Semantics node with label matching 'Rate Host User'
        final semanticsNodes = tester.getSemantics(
          find.bySemanticsLabel(RegExp('Rate Host User')),
        );
        expect(semanticsNodes.label, contains('Rate Host User'));
      });
    });

    testWidgets('Close button has Semantics label "Close rating"', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp());
      await _openSheet(tester);

      expect(find.bySemanticsLabel('Close rating'), findsOneWidget);
    });

    // Known gaps (tracked for next sprint):
    //   androidTapTargetGuideline — thumb-up icon button renders at 40×40dp;
    //     needs minimum 48dp touch target.
    //   labeledTapTargetGuideline — same icon button has no semantic label
    //     beyond the per-member "Rate [name]" node already tested above.
  });
}
