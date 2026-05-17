// KMUTT email domain validation tests for AuthRepositoryImpl.
//
// Regex constant source: core/validators/kmutt_email.dart
//   const kmuttEmailPattern = r'^[^\s@]+@(mail\.kmutt\.ac\.th|kmutt\.ac\.th)$';
//
// Key differences from the old inline _kmuttRegex:
//   - Local-part is now [^\s@]+ (disallows whitespace) in addition to no @.
//   - signUp() trims the email BEFORE the regex check, so leading/trailing
//     whitespace is stripped at the repository boundary.
//
// The regex has NO case-insensitive flag (/i). This matches ADR 0001 which
// specifies a case-sensitive check. Therefore uppercase domain variants
// (e.g. MAIL.KMUTT.AC.TH) MUST be rejected — see test case 3 below.
//
// Mock strategy: AuthDatasource is a concrete class; mocktail can mock it
// because it has no const constructors and all methods are non-final.
// For acceptance cases the mock must return a UserCredential whose .user.uid
// is accessible; we use a lightweight mock chain (MockUserCredential /
// MockUser) rather than pulling in Firebase test helpers.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/auth_failure.dart';
import 'package:mobile/features/auth/data/datasources/auth_datasource.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mock classes
// ---------------------------------------------------------------------------

class _MockAuthDatasource extends Mock implements AuthDatasource {}

class _MockUserCredential extends Mock implements UserCredential {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Stubs the datasource so that the full sign-up happy path completes without
/// errors. The KMUTT guard in the repository passes before any datasource call,
/// so these stubs are only reached for accepted emails.
///
/// signUp() no longer calls createUserDocument (Defect 1 fix): the Firestore
/// document is created in completeProfileSetup() after email verification.
/// signUp() now calls updateDisplayName() to persist fullName on the Firebase
/// Auth user for retrieval during profile setup.
void _stubSignUpSuccess(_MockAuthDatasource ds) {
  final mockCredential = _MockUserCredential();

  when(
    () => ds.createUserWithEmailAndPassword(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenAnswer((_) async => mockCredential);

  when(() => ds.updateDisplayName(any())).thenAnswer((_) async {});

  when(() => ds.sendEmailVerification()).thenAnswer((_) async {});
}

void main() {
  late _MockAuthDatasource mockDatasource;
  late AuthRepositoryImpl repo;

  setUp(() {
    mockDatasource = _MockAuthDatasource();
    repo = AuthRepositoryImpl(mockDatasource);
  });

  // ── REGEX SPEC CHECK ────────────────────────────────────────────────────────
  //
  // Regex: r'^[^@]+@(mail\.kmutt\.ac\.th|kmutt\.ac\.th)$'
  // Case-sensitive: YES (no /i flag). Matches ADR 0001 spec.
  // Spec deviation: NONE detected.
  //
  // ── ACCEPTED CASES ─────────────────────────────────────────────────────────

  group('signUp — accepted KMUTT emails (must reach Firebase)', () {
    test('1. standard student email: student@mail.kmutt.ac.th', () async {
      _stubSignUpSuccess(mockDatasource);

      await repo.signUp(
        fullName: 'Test Student',
        email: 'student@mail.kmutt.ac.th',
        password: 'password123',
      );

      // Datasource must have been called exactly once.
      verify(
        () => mockDatasource.createUserWithEmailAndPassword(
          email: 'student@mail.kmutt.ac.th',
          password: 'password123',
        ),
      ).called(1);
    });

    test('2. staff email: staff@kmutt.ac.th', () async {
      _stubSignUpSuccess(mockDatasource);

      await repo.signUp(
        fullName: 'Test Staff',
        email: 'staff@kmutt.ac.th',
        password: 'password123',
      );

      verify(
        () => mockDatasource.createUserWithEmailAndPassword(
          email: 'staff@kmutt.ac.th',
          password: 'password123',
        ),
      ).called(1);
    });
  });

  // ── REJECTED CASES ─────────────────────────────────────────────────────────
  //
  // For each case: assert KmuttDomainRejected is thrown AND that
  // createUserWithEmailAndPassword is NEVER called (guard fires before Firebase).

  group(
    'signUp — rejected emails (must throw KmuttDomainRejected, no Firebase call)',
    () {
      test(
        '3. uppercase domain: student@MAIL.KMUTT.AC.TH — rejected (no /i flag, matches ADR 0001)',
        () async {
          // Spec: case-sensitive regex, so uppercase domain must be rejected.
          // Implementation has no /i flag → behaviour matches spec (no deviation).
          await expectLater(
            repo.signUp(
              fullName: 'Test',
              email: 'student@MAIL.KMUTT.AC.TH',
              password: 'password123',
            ),
            throwsA(isA<KmuttDomainRejected>()),
          );

          verifyNever(
            () => mockDatasource.createUserWithEmailAndPassword(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ),
          );
        },
      );

      test('4. wrong domain: user@gmail.com', () async {
        await expectLater(
          repo.signUp(
            fullName: 'Test',
            email: 'user@gmail.com',
            password: 'password123',
          ),
          throwsA(isA<KmuttDomainRejected>()),
        );

        verifyNever(
          () => mockDatasource.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        );
      });

      test('5. lookalike subdomain: user@kmutt.ac.th.evil.com', () async {
        await expectLater(
          repo.signUp(
            fullName: 'Test',
            email: 'user@kmutt.ac.th.evil.com',
            password: 'password123',
          ),
          throwsA(isA<KmuttDomainRejected>()),
        );

        verifyNever(
          () => mockDatasource.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        );
      });

      test('6. double-@ injection: user@evil.com@mail.kmutt.ac.th', () async {
        // Regex: ^[^@]+@ — the [^@]+ local-part disallows a second @ before the
        // domain, so this address is rejected. Verifies defence against injection.
        await expectLater(
          repo.signUp(
            fullName: 'Test',
            email: 'user@evil.com@mail.kmutt.ac.th',
            password: 'password123',
          ),
          throwsA(isA<KmuttDomainRejected>()),
        );

        verifyNever(
          () => mockDatasource.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        );
      });

      test(
        '7. leading whitespace: " user@mail.kmutt.ac.th" — '
        'signUp() trims before regex; datasource receives trimmed email',
        () async {
          // After trimming, "user@mail.kmutt.ac.th" is a valid KMUTT address,
          // so the guard passes and the datasource is called with the trimmed value.
          _stubSignUpSuccess(mockDatasource);

          await repo.signUp(
            fullName: 'Test',
            email: ' user@mail.kmutt.ac.th',
            password: 'password123',
          );

          // Datasource must receive the TRIMMED email, not the raw input.
          verify(
            () => mockDatasource.createUserWithEmailAndPassword(
              email: 'user@mail.kmutt.ac.th',
              password: 'password123',
            ),
          ).called(1);
        },
      );

      test(
        '8. trailing whitespace: "user@mail.kmutt.ac.th " — '
        'signUp() trims before regex; datasource receives trimmed email',
        () async {
          // After trimming, "user@mail.kmutt.ac.th" is a valid KMUTT address.
          _stubSignUpSuccess(mockDatasource);

          await repo.signUp(
            fullName: 'Test',
            email: 'user@mail.kmutt.ac.th ',
            password: 'password123',
          );

          // Datasource must receive the TRIMMED email, not the raw input.
          verify(
            () => mockDatasource.createUserWithEmailAndPassword(
              email: 'user@mail.kmutt.ac.th',
              password: 'password123',
            ),
          ).called(1);
        },
      );

      test('9. empty string: ""', () async {
        await expectLater(
          repo.signUp(fullName: 'Test', email: '', password: 'password123'),
          throwsA(isA<KmuttDomainRejected>()),
        );

        verifyNever(
          () => mockDatasource.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        );
      });

      test('10. malformed: "not-an-email"', () async {
        await expectLater(
          repo.signUp(
            fullName: 'Test',
            email: 'not-an-email',
            password: 'password123',
          ),
          throwsA(isA<KmuttDomainRejected>()),
        );

        verifyNever(
          () => mockDatasource.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        );
      });
    },
  );
}
