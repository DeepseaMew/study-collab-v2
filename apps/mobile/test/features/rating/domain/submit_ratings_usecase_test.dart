// Unit tests for SubmitRatingsUseCase (ADR 0009).
//
// Verifies:
//   - Throws RatingError.submitFailed when rateeUids is empty
//   - Throws RatingError.selfRatingNotAllowed when current user UID is in rateeUids
//   - Throws RatingError.rateeNotMember when a rateeUid is not in sessionMemberUids
//   - Delegates to repository when submission is valid
//   - Handles multiple non-members, rejecting the whole submission

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/rating_error.dart';
import 'package:mobile/features/rating/domain/entities/rating_submission.dart';
import 'package:mobile/features/rating/domain/repositories/rating_repository.dart';
import 'package:mobile/features/rating/domain/usecases/submit_ratings_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockRatingRepository extends Mock implements RatingRepository {}

const _currentUid = 'user-current';
const _member1 = 'user-member-1';
const _member2 = 'user-member-2';
final _allMembers = [_currentUid, _member1, _member2];

RatingSubmission _submission({
  String sessionId = 'sess-1',
  List<String> rateeUids = const [_member1],
}) => RatingSubmission(sessionId: sessionId, rateeUids: rateeUids);

void main() {
  late _MockRatingRepository repo;
  late SubmitRatingsUseCase useCase;

  setUp(() {
    repo = _MockRatingRepository();
    useCase = SubmitRatingsUseCase(repo, _currentUid);
    when(() => repo.submitRatings(any(), any())).thenAnswer((_) async {});
  });

  group('SubmitRatingsUseCase — empty ratee list', () {
    test('throws RatingSubmitFailed when rateeUids is empty', () async {
      final sub = _submission(rateeUids: const []);

      await expectLater(
        useCase.call(sub, _allMembers),
        throwsA(isA<RatingSubmitFailed>()),
      );
      verifyNever(() => repo.submitRatings(any(), any()));
    });

    test('RatingSubmitFailed message is empty_ratee_list', () async {
      final sub = _submission(rateeUids: const []);

      try {
        await useCase.call(sub, _allMembers);
        fail('Expected RatingSubmitFailed');
      } on RatingSubmitFailed catch (e) {
        expect(e.message, 'empty_ratee_list');
      }
    });
  });

  group('SubmitRatingsUseCase — self-rating guard', () {
    test('throws selfRatingNotAllowed when current user is sole ratee', () async {
      final sub = _submission(rateeUids: const [_currentUid]);

      await expectLater(
        useCase.call(sub, _allMembers),
        throwsA(isA<RatingSelfRatingNotAllowed>()),
      );
      verifyNever(() => repo.submitRatings(any(), any()));
    });

    test('throws selfRatingNotAllowed when current user is one of multiple ratees', () async {
      final sub = _submission(rateeUids: const [_member1, _currentUid]);

      await expectLater(
        useCase.call(sub, _allMembers),
        throwsA(isA<RatingSelfRatingNotAllowed>()),
      );
      verifyNever(() => repo.submitRatings(any(), any()));
    });
  });

  group('SubmitRatingsUseCase — ratee membership guard', () {
    test('throws rateeNotMember when rateeUid is not in sessionMemberUids', () async {
      final sub = _submission(rateeUids: const ['outsider-uid']);

      await expectLater(
        useCase.call(sub, _allMembers),
        throwsA(isA<RatingRateeNotMember>()),
      );
      verifyNever(() => repo.submitRatings(any(), any()));
    });

    test('throws rateeNotMember when one of multiple ratees is not a member', () async {
      final sub = _submission(rateeUids: const [_member1, 'outsider-uid']);

      await expectLater(
        useCase.call(sub, _allMembers),
        throwsA(isA<RatingRateeNotMember>()),
      );
      verifyNever(() => repo.submitRatings(any(), any()));
    });

    test('throws rateeNotMember when sessionMemberUids is empty', () async {
      final sub = _submission();

      await expectLater(
        useCase.call(sub, const []),
        throwsA(isA<RatingRateeNotMember>()),
      );
      verifyNever(() => repo.submitRatings(any(), any()));
    });
  });

  group('SubmitRatingsUseCase — happy path delegation', () {
    test('delegates to repository when submission is valid (single ratee)', () async {
      const sessionId = 'sess-delegate';
      final sub = _submission(sessionId: sessionId);

      await useCase.call(sub, _allMembers);

      verify(() => repo.submitRatings(sessionId, const [_member1])).called(1);
    });

    test('delegates to repository with multiple valid ratees', () async {
      const sessionId = 'sess-multi';
      final sub = _submission(
        sessionId: sessionId,
        rateeUids: const [_member1, _member2],
      );

      await useCase.call(sub, _allMembers);

      verify(
        () => repo.submitRatings(sessionId, const [_member1, _member2]),
      ).called(1);
    });

    test('propagates RatingError.submitFailed from repository', () async {
      when(
        () => repo.submitRatings(any(), any()),
      ).thenAnswer((_) => Future.error(const RatingError.submitFailed('test')));
      final sub = _submission();

      await expectLater(
        useCase.call(sub, _allMembers),
        throwsA(isA<RatingSubmitFailed>()),
      );
    });

    test('propagates RatingError.alreadyRated from repository', () async {
      when(
        () => repo.submitRatings(any(), any()),
      ).thenAnswer((_) => Future.error(const RatingError.alreadyRated()));
      final sub = _submission();

      await expectLater(
        useCase.call(sub, _allMembers),
        throwsA(isA<RatingAlreadyRated>()),
      );
    });

    test('propagates RatingError.offlineNotSupported from repository', () async {
      when(
        () => repo.submitRatings(any(), any()),
      ).thenAnswer(
        (_) => Future.error(const RatingError.offlineNotSupported()),
      );
      final sub = _submission();

      await expectLater(
        useCase.call(sub, _allMembers),
        throwsA(isA<RatingOfflineNotSupported>()),
      );
    });
  });

  group('SubmitRatingsUseCase — guard precedence', () {
    test('empty check fires before self-rating check', () async {
      // Ratee list is empty — expect submitFailed (empty), not selfRatingNotAllowed
      final sub = _submission(
        rateeUids: const [],
      );

      await expectLater(
        useCase.call(sub, _allMembers),
        throwsA(isA<RatingSubmitFailed>()),
      );
    });

    test('self-rating check fires before membership check', () async {
      // Current user is in list and also not a member (edge case: memberUids excludes them)
      final sub = _submission(rateeUids: const [_currentUid, 'outsider-uid']);
      final membersWithoutCurrent = [_member1, _member2];

      await expectLater(
        useCase.call(sub, membersWithoutCurrent),
        throwsA(isA<RatingSelfRatingNotAllowed>()),
      );
    });
  });
}
