// Unit tests for RecentSearchLocalDatasource (ADR 0010 Sub-decision 3).
//
// Traces:
// - ADR 0010 Decision: "flutter_secure_storage, key search_recent_<uid>,
//   JSON array, max 10 entries, FIFO eviction"
// - ADR 0010 Decision: "UID-scoped to prevent cross-user leakage"
// - ADR 0010 Constraints: "No PII in logs"

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/search/data/datasources/recent_search_local_datasource.dart';
import 'package:mocktail/mocktail.dart';

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockFlutterSecureStorage mockStorage;
  late RecentSearchLocalDatasource datasource;

  setUp(() {
    mockStorage = _MockFlutterSecureStorage();
    datasource = RecentSearchLocalDatasource(mockStorage);
  });

  // Helper to stub a read returning null (no stored data).
  void _stubEmptyRead(String uid) {
    when(() => mockStorage.read(key: 'search_recent_$uid'))
        .thenAnswer((_) async => null);
  }

  // Helper to stub a read returning a specific JSON string.
  void _stubRead(String uid, String json) {
    when(() => mockStorage.read(key: 'search_recent_$uid'))
        .thenAnswer((_) async => json);
  }

  // Helper to stub a write call.
  void _stubWrite(String uid) {
    when(
      () => mockStorage.write(
        key: 'search_recent_$uid',
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
  }

  group('getRecentSearches', () {
    test('returns empty list when storage key does not exist', () async {
      _stubEmptyRead('uid-1');

      final result = await datasource.getRecentSearches('uid-1');

      expect(result, isEmpty);
    });

    test('returns empty list when storage value is empty string', () async {
      _stubRead('uid-1', '');

      final result = await datasource.getRecentSearches('uid-1');

      expect(result, isEmpty);
    });

    test('returns list of strings from stored JSON array', () async {
      _stubRead('uid-1', '["math","physics","calculus"]');

      final result = await datasource.getRecentSearches('uid-1');

      expect(result, equals(['math', 'physics', 'calculus']));
    });

    test('returns empty list on malformed JSON (error recovery)', () async {
      _stubRead('uid-1', 'not-valid-json');

      final result = await datasource.getRecentSearches('uid-1');

      expect(result, isEmpty);
    });
  });

  group('addRecentSearch', () {
    test('prepends new term to empty list', () async {
      _stubEmptyRead('uid-1');
      _stubWrite('uid-1');

      await datasource.addRecentSearch('uid-1', 'calculus');

      final captured = verify(
        () => mockStorage.write(
          key: 'search_recent_uid-1',
          value: captureAny(named: 'value'),
        ),
      ).captured;
      expect(captured.first as String, contains('calculus'));
    });

    test('prepends to existing list', () async {
      _stubRead('uid-1', '["physics","chemistry"]');
      _stubWrite('uid-1');

      await datasource.addRecentSearch('uid-1', 'mathematics');

      final captured = verify(
        () => mockStorage.write(
          key: 'search_recent_uid-1',
          value: captureAny(named: 'value'),
        ),
      ).captured;
      final written = captured.first as String;
      // mathematics should appear before physics in the JSON
      expect(written.indexOf('mathematics') < written.indexOf('physics'), isTrue);
    });

    test('caps list at 10 entries with FIFO eviction', () async {
      // Start with 10 existing entries
      final existing = List.generate(10, (i) => 'term$i');
      _stubRead('uid-1', '[${existing.map((t) => '"$t"').join(',')}]');
      _stubWrite('uid-1');

      await datasource.addRecentSearch('uid-1', 'new-term');

      final captured = verify(
        () => mockStorage.write(
          key: 'search_recent_uid-1',
          value: captureAny(named: 'value'),
        ),
      ).captured;
      final written = captured.first as String;
      // Count commas+1 to approximate entry count — 10 entries = 9 commas
      // More reliably: parse back as JSON
      final parsed = RegExp(r'"[^"]+"').allMatches(written).length;
      expect(parsed, equals(10));
      // Most recent term is at the front
      expect(written.indexOf('new-term') < written.indexOf('term0'), isTrue);
      // Oldest term (term9) is evicted
      expect(written.contains('term9'), isFalse);
    });

    test('deduplicates: moves existing term to front rather than duplicating',
        () async {
      _stubRead('uid-1', '["physics","mathematics","chemistry"]');
      _stubWrite('uid-1');

      await datasource.addRecentSearch('uid-1', 'mathematics');

      final captured = verify(
        () => mockStorage.write(
          key: 'search_recent_uid-1',
          value: captureAny(named: 'value'),
        ),
      ).captured;
      final written = captured.first as String;
      // 'mathematics' should appear exactly once
      expect('mathematics'.allMatches(written).length, equals(1));
      // 'mathematics' is now at the front
      expect(
        written.indexOf('mathematics') < written.indexOf('physics'),
        isTrue,
      );
    });
  });

  group('UID-scoped storage isolation', () {
    test('different UIDs use separate storage keys', () async {
      _stubEmptyRead('uid-alice');
      _stubEmptyRead('uid-bob');
      _stubWrite('uid-alice');
      _stubWrite('uid-bob');

      await datasource.addRecentSearch('uid-alice', 'linear algebra');
      await datasource.addRecentSearch('uid-bob', 'thermodynamics');

      // Alice's write went to the correct key
      verify(
        () => mockStorage.write(
          key: 'search_recent_uid-alice',
          value: any(named: 'value'),
        ),
      ).called(1);

      // Bob's write went to the correct key
      verify(
        () => mockStorage.write(
          key: 'search_recent_uid-bob',
          value: any(named: 'value'),
        ),
      ).called(1);

      // Verify alice's entry was indeed written under her key (not bob's)
      // (We already verified the write went to alice's key above.)
      // This indirectly confirms cross-contamination did not occur.
    });

    test('getRecentSearches reads from UID-specific key only', () async {
      _stubRead('uid-alice', '["study-group"]');
      _stubEmptyRead('uid-bob');

      final aliceResults = await datasource.getRecentSearches('uid-alice');
      final bobResults = await datasource.getRecentSearches('uid-bob');

      expect(aliceResults, equals(['study-group']));
      expect(bobResults, isEmpty);
    });
  });
}
