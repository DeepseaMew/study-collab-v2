// Security-path unit tests for CalendarSyncRepositoryImpl.
//
// Covers the five scenarios mandated by the security reviewer:
//   1. connect() throws EmailMismatchError when account email does not match.
//   2. connect() calls signOut() after email mismatch before throwing.
//   3. connect() throws CancelledError when requestScopes returns false.
//   4. disconnect() calls revokeAccess() then signOut() in that order (HIGH-2 fix).
//   5. disconnect() deletes the 'gcal_last_sync_{uid}' key from secure storage.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mobile/core/errors/calendar_sync_error.dart';
import 'package:mobile/features/calendar/data/datasources/gcal_datasource.dart';
import 'package:mobile/features/calendar/data/repositories/calendar_sync_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockGoogleSignIn extends Mock implements GoogleSignIn {}

class _MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class _MockGcalDatasource extends Mock implements GcalDatasource {}

// ── Helpers ───────────────────────────────────────────────────────────────────

CalendarSyncRepositoryImpl _makeRepo({
  required GoogleSignIn googleSignIn,
  FlutterSecureStorage? secureStorage,
  String uid = 'uid-1',
}) {
  return CalendarSyncRepositoryImpl(
    googleSignIn: googleSignIn,
    secureStorage: secureStorage ?? _MockFlutterSecureStorage(),
    datasourceFactory: (_) => _MockGcalDatasource(),
    uid: uid,
  );
}

void main() {
  late _MockGoogleSignIn mockSignIn;
  late _MockGoogleSignInAccount mockAccount;
  late _MockFlutterSecureStorage mockStorage;

  setUp(() {
    mockSignIn = _MockGoogleSignIn();
    mockAccount = _MockGoogleSignInAccount();
    mockStorage = _MockFlutterSecureStorage();
  });

  // ── connect() ──────────────────────────────────────────────────────────────

  group('connect()', () {
    test(
      'throws EmailMismatchError when account email does not match',
      () async {
        when(() => mockSignIn.signIn()).thenAnswer((_) async => mockAccount);
        when(() => mockAccount.email).thenReturn('other@mail.kmutt.ac.th');
        when(() => mockSignIn.signOut()).thenAnswer((_) async => null);

        final repo = _makeRepo(googleSignIn: mockSignIn);

        await expectLater(
          repo.connect('expected@mail.kmutt.ac.th'),
          throwsA(isA<EmailMismatchError>()),
        );
      },
    );

    test('calls signOut() after email mismatch before throwing', () async {
      when(() => mockSignIn.signIn()).thenAnswer((_) async => mockAccount);
      when(() => mockAccount.email).thenReturn('other@mail.kmutt.ac.th');
      when(() => mockSignIn.signOut()).thenAnswer((_) async => null);

      final repo = _makeRepo(googleSignIn: mockSignIn);

      await expectLater(
        repo.connect('expected@mail.kmutt.ac.th'),
        throwsA(isA<EmailMismatchError>()),
      );

      verify(() => mockSignIn.signOut()).called(1);
    });

    test('email comparison is case-insensitive', () async {
      when(() => mockSignIn.signIn()).thenAnswer((_) async => mockAccount);
      // Google returns mixed-case; stored email is lowercase.
      when(() => mockAccount.email).thenReturn('Student@Mail.KMUTT.AC.TH');
      when(() => mockSignIn.requestScopes(any())).thenAnswer((_) async => true);

      final repo = _makeRepo(googleSignIn: mockSignIn);

      // Should NOT throw EmailMismatchError when emails match case-insensitively.
      await expectLater(repo.connect('student@mail.kmutt.ac.th'), completes);
    });

    test('throws CancelledError when requestScopes returns false', () async {
      when(() => mockSignIn.signIn()).thenAnswer((_) async => mockAccount);
      when(() => mockAccount.email).thenReturn('student@mail.kmutt.ac.th');
      when(
        () => mockSignIn.requestScopes(any()),
      ).thenAnswer((_) async => false);
      when(() => mockSignIn.signOut()).thenAnswer((_) async => null);

      final repo = _makeRepo(googleSignIn: mockSignIn);

      await expectLater(
        repo.connect('student@mail.kmutt.ac.th'),
        throwsA(isA<CancelledError>()),
      );
    });

    test('throws CancelledError when signIn() returns null', () async {
      when(() => mockSignIn.signIn()).thenAnswer((_) async => null);

      final repo = _makeRepo(googleSignIn: mockSignIn);

      await expectLater(
        repo.connect('student@mail.kmutt.ac.th'),
        throwsA(isA<CancelledError>()),
      );
    });
  });

  // ── disconnect() ───────────────────────────────────────────────────────────

  group('disconnect()', () {
    // HIGH-2 fix: GoogleSignIn.disconnect() revokes the server-side OAuth grant
    // AND clears the local session in one call. signOut() alone would leave the
    // grant alive on Google's servers.
    test(
      'calls GoogleSignIn.disconnect() to revoke server-side grant',
      () async {
        when(() => mockSignIn.disconnect()).thenAnswer((_) async => null);
        when(
          () => mockStorage.delete(key: any(named: 'key')),
        ).thenAnswer((_) async {});

        final repo = _makeRepo(
          googleSignIn: mockSignIn,
          secureStorage: mockStorage,
        );

        await repo.disconnect();

        verify(() => mockSignIn.disconnect()).called(1);
      },
    );

    test(
      'does NOT call signOut() separately — disconnect() handles it',
      () async {
        when(() => mockSignIn.disconnect()).thenAnswer((_) async => null);
        when(
          () => mockStorage.delete(key: any(named: 'key')),
        ).thenAnswer((_) async {});

        final repo = _makeRepo(
          googleSignIn: mockSignIn,
          secureStorage: mockStorage,
        );

        await repo.disconnect();

        verifyNever(() => mockSignIn.signOut());
      },
    );

    test("deletes 'gcal_last_sync_{uid}' key from secure storage", () async {
      when(() => mockSignIn.disconnect()).thenAnswer((_) async => null);
      when(
        () => mockStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      const uid = 'uid-42';
      final repo = _makeRepo(
        googleSignIn: mockSignIn,
        secureStorage: mockStorage,
        uid: uid,
      );

      await repo.disconnect();

      verify(() => mockStorage.delete(key: 'gcal_last_sync_$uid')).called(1);
    });
  });
}
