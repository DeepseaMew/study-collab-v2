// Unit tests for GcalDatasource.
//
// Verifies:
//   1. SHA-1 event ID is deterministic: always 'sc' + sha1hex(sessionId).
//   2. events.patch is called with correct field mapping.
//   3. ApiFailureError is thrown on DetailedApiRequestError from the API.
//
// FirebaseCrashlytics is injected via the GcalDatasource constructor so these
// tests run without Firebase initialisation.
//
// Uses mocktail mocks — does NOT call real Google Calendar API.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:mobile/core/errors/calendar_sync_error.dart';
import 'package:mobile/features/calendar/data/datasources/gcal_datasource.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockCalendarApi extends Mock implements CalendarApi {}

class _MockEventsResource extends Mock implements EventsResource {}

class _MockCrashlytics extends Mock implements FirebaseCrashlytics {}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Replicates the same SHA-1 logic as GcalDatasource._eventId for assertions.
String _expectedEventId(String sessionId) {
  final bytes = utf8.encode(sessionId);
  final digest = sha1.convert(bytes);
  return 'sc$digest';
}

SessionEntity _session({
  String id = 'session-abc',
  String status = 'scheduled',
}) {
  final now = DateTime(2026, 5, 20, 14);
  return SessionEntity(
    sessionId: id,
    hostUid: 'host-1',
    hostFaculty: 'Engineering',
    title: 'Test Study Session',
    description: 'A test description',
    hashtags: const ['math'],
    academicLevel: 'undergraduate',
    studentYear: 2,
    visibility: 'public',
    memberUids: const ['host-1', 'member-1'],
    noteCount: 0,
    status: status,
    scheduledAt: now,
    scheduledEndAt: now.add(const Duration(hours: 2)),
    location: 'Room 101',
    capacity: 10,
    hostDisplayName: 'Host User',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(Event());
    registerFallbackValue(StackTrace.empty);
  });

  group('GcalDatasource — SHA-1 event ID', () {
    test('event ID starts with sc prefix', () {
      final id = _expectedEventId('session-abc');
      expect(id.startsWith('sc'), isTrue);
    });

    test('event ID is deterministic for the same sessionId', () {
      final id1 = _expectedEventId('session-xyz');
      final id2 = _expectedEventId('session-xyz');
      expect(id1, id2);
    });

    test('different sessionIds produce different event IDs', () {
      final id1 = _expectedEventId('session-A');
      final id2 = _expectedEventId('session-B');
      expect(id1, isNot(id2));
    });

    test('event ID is exactly 42 chars (2 prefix + 40 sha1hex)', () {
      final id = _expectedEventId('any-session-id');
      expect(id.length, 42);
    });

    test('event ID only contains lowercase alphanumeric chars', () {
      final id = _expectedEventId('my-session-id-1234');
      final valid = RegExp(r'^[a-z0-9]+$');
      expect(valid.hasMatch(id), isTrue);
    });
  });

  group('GcalDatasource.patchEvent — happy path', () {
    late _MockCalendarApi mockApi;
    late _MockEventsResource mockEvents;
    late GcalDatasource datasource;

    setUp(() {
      mockApi = _MockCalendarApi();
      mockEvents = _MockEventsResource();
      datasource = GcalDatasource(mockApi, crashlytics: _MockCrashlytics());
      when(() => mockApi.events).thenReturn(mockEvents);
    });

    test('calls events.patch with correct calendarId=primary', () async {
      when(
        () => mockEvents.patch(any(), 'primary', any()),
      ).thenAnswer((_) async => Event());

      await datasource.patchEvent(_session());

      verify(() => mockEvents.patch(any(), 'primary', any())).called(1);
    });

    test('calls events.patch with correct deterministic event ID', () async {
      const sessionId = 'session-abc';
      final expectedId = _expectedEventId(sessionId);
      String? capturedId;

      when(() => mockEvents.patch(any(), 'primary', any())).thenAnswer((
        invocation,
      ) async {
        capturedId = invocation.positionalArguments[2] as String;
        return Event();
      });

      await datasource.patchEvent(_session());

      expect(capturedId, expectedId);
    });

    test('maps session title to event summary', () async {
      Event? captured;
      when(() => mockEvents.patch(any(), 'primary', any())).thenAnswer((
        inv,
      ) async {
        captured = inv.positionalArguments[0] as Event;
        return Event();
      });

      await datasource.patchEvent(_session());

      expect(captured?.summary, 'Test Study Session');
    });

    test('maps session location to event location', () async {
      Event? captured;
      when(() => mockEvents.patch(any(), 'primary', any())).thenAnswer((
        inv,
      ) async {
        captured = inv.positionalArguments[0] as Event;
        return Event();
      });

      await datasource.patchEvent(_session());

      expect(captured?.location, 'Room 101');
    });

    test('maps hostDisplayName and status into description', () async {
      Event? captured;
      when(() => mockEvents.patch(any(), 'primary', any())).thenAnswer((
        inv,
      ) async {
        captured = inv.positionalArguments[0] as Event;
        return Event();
      });

      await datasource.patchEvent(_session());

      expect(captured?.description, contains('Host User'));
      expect(captured?.description, contains('scheduled'));
    });

    test('does not set event source (source.url omitted per ADR 0007)', () async {
      Event? captured;
      when(() => mockEvents.patch(any(), 'primary', any())).thenAnswer((
        inv,
      ) async {
        captured = inv.positionalArguments[0] as Event;
        return Event();
      });

      await datasource.patchEvent(_session());

      expect(captured?.source, isNull);
    });
  });

  group('GcalDatasource.patchEvent — error path', () {
    late _MockCalendarApi mockApi;
    late _MockEventsResource mockEvents;
    late _MockCrashlytics mockCrashlytics;
    late GcalDatasource datasource;

    setUp(() {
      mockApi = _MockCalendarApi();
      mockEvents = _MockEventsResource();
      mockCrashlytics = _MockCrashlytics();
      datasource = GcalDatasource(mockApi, crashlytics: mockCrashlytics);
      when(() => mockApi.events).thenReturn(mockEvents);
      when(
        () => mockCrashlytics.recordError(
          any<Object?>(),
          any<StackTrace?>(),
          fatal: any<bool>(named: 'fatal'),
        ),
      ).thenAnswer((_) async {});
    });

    test('throws ApiFailureError on DetailedApiRequestError', () async {
      when(
        () => mockEvents.patch(any(), any(), any()),
      ).thenThrow(DetailedApiRequestError(403, 'Forbidden'));

      await expectLater(
        () => datasource.patchEvent(_session()),
        throwsA(isA<ApiFailureError>()),
      );
    });

    test(
      'ApiFailureError message contains error code on API failure',
      () async {
        when(
          () => mockEvents.patch(any(), any(), any()),
        ).thenThrow(DetailedApiRequestError(403, 'Forbidden'));

        ApiFailureError? caught;
        try {
          await datasource.patchEvent(_session());
        } on ApiFailureError catch (e) {
          caught = e;
        }

        expect(caught, isNotNull);
        expect(caught!.message, contains('403'));
      },
    );

    test('calls crashlytics.recordError on API failure', () async {
      when(
        () => mockEvents.patch(any(), any(), any()),
      ).thenThrow(DetailedApiRequestError(500, 'Server Error'));

      try {
        await datasource.patchEvent(_session());
      } on ApiFailureError {
        // expected
      }

      verify(
        () => mockCrashlytics.recordError(
          any<Object?>(),
          any<StackTrace?>(),
          fatal: any<bool>(named: 'fatal'),
        ),
      ).called(1);
    });
  });

  group('GcalDatasource.syncSessions', () {
    late _MockCalendarApi mockApi;
    late _MockEventsResource mockEvents;
    late _MockCrashlytics mockCrashlytics;
    late GcalDatasource datasource;

    setUp(() {
      mockApi = _MockCalendarApi();
      mockEvents = _MockEventsResource();
      mockCrashlytics = _MockCrashlytics();
      datasource = GcalDatasource(mockApi, crashlytics: mockCrashlytics);
      when(() => mockApi.events).thenReturn(mockEvents);
      when(
        () => mockCrashlytics.recordError(
          any<Object?>(),
          any<StackTrace?>(),
          fatal: any<bool>(named: 'fatal'),
        ),
      ).thenAnswer((_) async {});
    });

    test('calls patchEvent once per session', () async {
      when(
        () => mockEvents.patch(any(), any(), any()),
      ).thenAnswer((_) async => Event());

      final sessions = [
        _session(id: 'sess-1'),
        _session(id: 'sess-2'),
        _session(id: 'sess-3'),
      ];

      await datasource.syncSessions(sessions);

      verify(() => mockEvents.patch(any(), any(), any())).called(3);
    });

    test(
      'no duplicate patch calls for same sessionId across two sync calls',
      () async {
        when(
          () => mockEvents.patch(any(), any(), any()),
        ).thenAnswer((_) async => Event());

        final session = _session(id: 'sess-unique');

        await datasource.syncSessions([session]);
        await datasource.syncSessions([session]);

        verify(
          () => mockEvents.patch(
            any(),
            'primary',
            _expectedEventId('sess-unique'),
          ),
        ).called(2);
      },
    );

    test('counts synced and failed correctly when one session fails', () async {
      var callCount = 0;
      when(() => mockEvents.patch(any(), any(), any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 2) throw DetailedApiRequestError(500, 'error');
        return Event();
      });

      final result = await datasource.syncSessions([
        _session(id: 'sess-1'),
        _session(id: 'sess-2'),
        _session(id: 'sess-3'),
      ]);

      expect(result.syncedCount, 2);
      expect(result.failedCount, 1);
    });

    test('returns SyncResult with syncedAt set', () async {
      when(
        () => mockEvents.patch(any(), any(), any()),
      ).thenAnswer((_) async => Event());

      final result = await datasource.syncSessions([_session()]);

      expect(result.syncedAt, isA<DateTime>());
    });

    test(
      'returns syncedCount=0 failedCount=0 for empty session list',
      () async {
        final result = await datasource.syncSessions([]);
        expect(result.syncedCount, 0);
        expect(result.failedCount, 0);
      },
    );
  });
}
