// Unit tests for NotificationPreferencesDatasource.
//
// Tests:
//   1. Returns all true defaults when storage returns null.
//   2. Persists a toggled value to storage correctly.
//   3. Reads back correctly after write.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/notifications/data/datasources/notification_preferences_datasource.dart';
import 'package:mocktail/mocktail.dart';

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockFlutterSecureStorage mockStorage;
  late NotificationPreferencesDatasource datasource;

  const kKey = 'notification_preferences';

  setUp(() {
    mockStorage = _MockFlutterSecureStorage();
    datasource = NotificationPreferencesDatasource(mockStorage);
  });

  group('readPreferences', () {
    test(
      'returns all true defaults when storage key is absent (null)',
      () async {
        when(() => mockStorage.read(key: kKey)).thenAnswer((_) async => null);

        final prefs = await datasource.readPreferences();

        expect(prefs['allNotifications'], isTrue);
        expect(prefs['joinRequestAlerts'], isTrue);
        expect(prefs['friendRequests'], isTrue);
        expect(prefs['ratingAvailable'], isTrue);
      },
    );

    test('returns all four expected keys even when value is null', () async {
      when(() => mockStorage.read(key: kKey)).thenAnswer((_) async => null);

      final prefs = await datasource.readPreferences();

      expect(
        prefs.keys,
        containsAll(<String>[
          'allNotifications',
          'joinRequestAlerts',
          'friendRequests',
          'ratingAvailable',
        ]),
      );
    });

    test(
      'merges stored values with defaults — stored value overrides default',
      () async {
        final stored = jsonEncode({
          'allNotifications': false,
          'joinRequestAlerts': true,
          'friendRequests': false,
          'ratingAvailable': true,
        });
        when(() => mockStorage.read(key: kKey)).thenAnswer((_) async => stored);

        final prefs = await datasource.readPreferences();

        expect(prefs['allNotifications'], isFalse);
        expect(prefs['joinRequestAlerts'], isTrue);
        expect(prefs['friendRequests'], isFalse);
        expect(prefs['ratingAvailable'], isTrue);
      },
    );

    test('returns defaults when stored JSON is malformed', () async {
      when(
        () => mockStorage.read(key: kKey),
      ).thenAnswer((_) async => 'NOT_VALID_JSON{{{');

      final prefs = await datasource.readPreferences();

      // Falls back to defaults on parse error.
      expect(prefs['allNotifications'], isTrue);
      expect(prefs['joinRequestAlerts'], isTrue);
    });

    test('ignores non-bool values in stored JSON', () async {
      final stored = jsonEncode({
        'allNotifications': 'yes', // not a bool — should be ignored
        'joinRequestAlerts': true,
        'friendRequests': true,
        'ratingAvailable': true,
      });
      when(() => mockStorage.read(key: kKey)).thenAnswer((_) async => stored);

      final prefs = await datasource.readPreferences();

      // 'yes' is not a bool, so 'allNotifications' reverts to the default (true).
      expect(prefs['allNotifications'], isTrue);
    });
  });

  group('writePreferences', () {
    test('persists a toggled value to storage correctly', () async {
      final updated = {
        'allNotifications': true,
        'joinRequestAlerts': false,
        'friendRequests': true,
        'ratingAvailable': true,
      };

      when(
        () => mockStorage.write(
          key: kKey,
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      await datasource.writePreferences(updated);

      final captured = verify(
        () => mockStorage.write(
          key: kKey,
          value: captureAny(named: 'value'),
        ),
      ).captured;

      expect(captured, hasLength(1));
      final decoded =
          jsonDecode(captured.first as String) as Map<String, dynamic>;
      expect(decoded['joinRequestAlerts'], isFalse);
      expect(decoded['allNotifications'], isTrue);
    });

    test('reads back correctly after write (round-trip)', () async {
      const kPrefsKey = 'notification_preferences';
      String? stored;

      // Simulate storage that persists to a local variable.
      when(
        () => mockStorage.write(
          key: kPrefsKey,
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        stored = invocation.namedArguments[const Symbol('value')] as String;
      });
      when(
        () => mockStorage.read(key: kPrefsKey),
      ).thenAnswer((_) async => stored);

      final toWrite = {
        'allNotifications': false,
        'joinRequestAlerts': false,
        'friendRequests': true,
        'ratingAvailable': false,
      };
      await datasource.writePreferences(toWrite);

      final readBack = await datasource.readPreferences();

      expect(readBack['allNotifications'], isFalse);
      expect(readBack['joinRequestAlerts'], isFalse);
      expect(readBack['friendRequests'], isTrue);
      expect(readBack['ratingAvailable'], isFalse);
    });
  });
}
