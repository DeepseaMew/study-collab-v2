// Unit tests for CheckHasRatedUseCase (ADR 0009).
//
// Verifies:
//   - Returns true when repository.hasRatedInSession returns true
//   - Returns false when repository.hasRatedInSession returns false
//   - Passes sessionId and raterUid through to the repository unchanged
//   - Propagates exceptions from the repository

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/rating/domain/repositories/rating_repository.dart';
import 'package:mobile/features/rating/domain/usecases/check_has_rated_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockRatingRepository extends Mock implements RatingRepository {}

void main() {
  late _MockRatingRepository repo;
  late CheckHasRatedUseCase useCase;

  setUp(() {
    repo = _MockRatingRepository();
    useCase = CheckHasRatedUseCase(repo);
  });

  group('CheckHasRatedUseCase — return value', () {
    test('returns true when repository returns true', () async {
      when(
        () => repo.hasRatedInSession(any(), any()),
      ).thenAnswer((_) async => true);

      final result = await useCase.call('sess-1', 'user-1');

      expect(result, isTrue);
    });

    test('returns false when repository returns false', () async {
      when(
        () => repo.hasRatedInSession(any(), any()),
      ).thenAnswer((_) async => false);

      final result = await useCase.call('sess-1', 'user-1');

      expect(result, isFalse);
    });
  });

  group('CheckHasRatedUseCase — delegation', () {
    test('passes sessionId and raterUid to repository', () async {
      const sessionId = 'sess-delegate';
      const raterUid = 'rater-delegate';
      when(
        () => repo.hasRatedInSession(any(), any()),
      ).thenAnswer((_) async => false);

      await useCase.call(sessionId, raterUid);

      verify(() => repo.hasRatedInSession(sessionId, raterUid)).called(1);
    });

    test('propagates exception from repository', () async {
      when(
        () => repo.hasRatedInSession(any(), any()),
      ).thenAnswer((_) => Future.error(Exception('Firestore unavailable')));

      await expectLater(
        useCase.call('sess-1', 'user-1'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
