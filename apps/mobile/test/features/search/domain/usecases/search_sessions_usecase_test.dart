// Unit tests for SearchSessionsUseCase (ADR 0010).
//
// Traces:
// - ADR 0010 Constraints: "trims whitespace, lowercases query and hashtag,
//   throws SearchError.queryTooShort if trimmed keyword is non-empty but
//   shorter than 2 characters"
// - ADR 0010 Decision: "delegates to SearchRepository.searchSessions"
// - ADR 0010 Constraints: "online-only; throw SearchError.offlineNotSupported"

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/search_error.dart';
import 'package:mobile/features/search/domain/entities/search_filter.dart';
import 'package:mobile/features/search/domain/repositories/search_repository.dart';
import 'package:mobile/features/search/domain/usecases/search_sessions_usecase.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mocktail/mocktail.dart';

class _MockSearchRepository extends Mock implements SearchRepository {}

/// Builds a minimal valid [SessionEntity] for use in stub return values.
SessionEntity _stubSession({String id = 's1'}) => SessionEntity(
      sessionId: id,
      hostUid: 'host-uid',
      hostFaculty: 'Engineering',
      title: 'Calculus Study',
      hashtags: const ['mathematics'],
      academicLevel: 'undergraduate',
      studentYear: 2,
      visibility: 'public',
      memberUids: const ['host-uid'],
      noteCount: 0,
      status: 'scheduled',
      scheduledAt: DateTime.now().add(const Duration(hours: 2)),
      location: 'Room 101',
      capacity: 10,
      hostDisplayName: 'Alice',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  late _MockSearchRepository mockRepo;
  late SearchSessionsUseCase useCase;

  setUp(() {
    mockRepo = _MockSearchRepository();
    useCase = SearchSessionsUseCase(mockRepo);
  });

  // Register the fallback value so Mocktail can match any SearchFilter.
  setUpAll(() {
    registerFallbackValue(const SearchFilter());
  });

  group('query normalisation', () {
    test('trims whitespace and lowercases query before passing to repository',
        () async {
      when(() => mockRepo.searchSessions(any()))
          .thenAnswer((_) async => [_stubSession()]);

      await useCase(const SearchFilter(query: '  Calculus  '));

      final captured =
          verify(() => mockRepo.searchSessions(captureAny())).captured;
      final filter = captured.first as SearchFilter;
      expect(filter.query, equals('calculus'));
    });

    test('trims whitespace and lowercases hashtag before passing to repository',
        () async {
      when(() => mockRepo.searchSessions(any()))
          .thenAnswer((_) async => [_stubSession()]);

      await useCase(const SearchFilter(hashtag: '  MATH  '));

      final captured =
          verify(() => mockRepo.searchSessions(captureAny())).captured;
      final filter = captured.first as SearchFilter;
      expect(filter.hashtag, equals('math'));
    });

    test('null query remains null after normalisation', () async {
      when(() => mockRepo.searchSessions(any()))
          .thenAnswer((_) async => [_stubSession()]);

      await useCase(const SearchFilter());

      final captured =
          verify(() => mockRepo.searchSessions(captureAny())).captured;
      final filter = captured.first as SearchFilter;
      expect(filter.query, isNull);
    });

    test('whitespace-only query is treated as null (not passed to repo as empty)',
        () async {
      when(() => mockRepo.searchSessions(any()))
          .thenAnswer((_) async => [_stubSession()]);

      await useCase(const SearchFilter(query: '   '));

      final captured =
          verify(() => mockRepo.searchSessions(captureAny())).captured;
      final filter = captured.first as SearchFilter;
      expect(filter.query, isNull);
    });
  });

  group('queryTooShort validation', () {
    test('throws SearchError.queryTooShort when trimmed query is 1 character',
        () async {
      expect(
        () => useCase(const SearchFilter(query: 'a')),
        throwsA(isA<SearchQueryTooShort>()),
      );
      verifyNever(() => mockRepo.searchSessions(any()));
    });

    test('throws SearchError.queryTooShort when query trims to 1 character',
        () async {
      expect(
        () => useCase(const SearchFilter(query: '  x  ')),
        throwsA(isA<SearchQueryTooShort>()),
      );
    });

    test('does NOT throw when query is exactly 2 characters', () async {
      when(() => mockRepo.searchSessions(any()))
          .thenAnswer((_) async => [_stubSession()]);

      await expectLater(
        useCase(const SearchFilter(query: 'ab')),
        completes,
      );
    });

    test('does NOT throw when query is longer than 2 characters', () async {
      when(() => mockRepo.searchSessions(any()))
          .thenAnswer((_) async => [_stubSession()]);

      await expectLater(
        useCase(const SearchFilter(query: 'calculus')),
        completes,
      );
    });
  });

  group('delegation to repository', () {
    test('delegates to repository when filter is valid', () async {
      final sessions = [_stubSession()];
      when(() => mockRepo.searchSessions(any()))
          .thenAnswer((_) async => sessions);

      final result =
          await useCase(const SearchFilter(query: 'calculus'));

      expect(result, equals(sessions));
      verify(() => mockRepo.searchSessions(any())).called(1);
    });

    test('delegates to repository when filter has no query (browse all)',
        () async {
      when(() => mockRepo.searchSessions(any()))
          .thenAnswer((_) async => <SessionEntity>[]);

      final result = await useCase(const SearchFilter());

      expect(result, isEmpty);
      verify(() => mockRepo.searchSessions(any())).called(1);
    });
  });

  group('error propagation', () {
    test('propagates SearchError.offlineNotSupported from repository', () async {
      when(() => mockRepo.searchSessions(any()))
          .thenThrow(const SearchError.offlineNotSupported());

      expect(
        () => useCase(const SearchFilter(query: 'math')),
        throwsA(isA<SearchOfflineNotSupported>()),
      );
    });

    test('propagates SearchError.unknown from repository', () async {
      when(() => mockRepo.searchSessions(any()))
          .thenThrow(const SearchError.unknown('firebase-error'));

      expect(
        () => useCase(const SearchFilter(query: 'math')),
        throwsA(isA<SearchUnknown>()),
      );
    });
  });
}
