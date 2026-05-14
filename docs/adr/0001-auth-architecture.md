## ADR 0001 — Authentication Architecture (Firebase Auth + Biometric + KMUTT Email Gate)

- **Status:** Accepted
- **Date:** 2026-05-14
- **Owner:** architect
- **Implementation hand-off:** firebase-specialist (data layer), flutter-engineer (presentation layer)

---

### Context

Study Collab V2 must authenticate KMUTT students before any feature of the app is accessible. The capstone rubric and CLAUDE.md impose the following non-negotiable requirements on the auth subsystem:

1. **Firebase Auth as identity provider.** Email + password sign-in only. No social providers in v1.
2. **University email domain restriction.** Allowed primary domains: `kmutt.ac.th`, `mail.kmutt.ac.th`. The dev-only exception `gmail.com` is allowed behind a build-time flag and must be removed before launch.
3. **Email verification gate.** After signup Firebase sends a verification email. Unverified users are redirected to `/verify-email`. All other routes require both `signedIn == true` AND `emailVerified == true`.
4. **Biometric authentication ** The user must be able to re-authenticate on subsequent app launches using device biometrics (fingerprint, face) instead of typing a password every time. Biometrics is required, not optional.
5. **Secret management.** No passwords, tokens, or PII may be logged. Credentials cached for biometric unlock must live in OS-backed secure storage only — never in `SharedPreferences`, Firestore, or memory across app restarts.
6. **Clean Architecture (strict).** Domain layer has zero Flutter/Firebase imports. Presentation never touches Firebase. Path is always: widget → provider → use case → repository interface → data repository → datasource → Firebase.
7. **Riverpod codegen only.** All providers use `@riverpod`. No hand-written providers.
8. **No email enumeration.** Sign-in error surface must not let an attacker distinguish "user does not exist" from "wrong password". A single generic message is returned for both.

The legacy reference code (`docs/references/auth_screen/`) violated Clean Architecture: screens read a single `authServiceProvider` that mixed Firebase Auth, Firestore writes, and validation. We are rebuilding this from scratch with clear layer boundaries.

---

### Decision

Auth is split across the four standard layers with the following responsibilities. Each bullet is a contract — implementations may not exceed its scope.

#### Layer responsibilities

- **`core/`** owns: allowed email domain constants, validators (regex), typed exceptions (`AuthException` and friends), GoRouter guards. No business logic.
- **`domain/`** owns: the `User` entity, the `AuthRepository` interface, and one use case per business operation (`SignInUseCase`, `SignUpUseCase`, `SignOutUseCase`, `SendEmailVerificationUseCase`, `ReloadUserUseCase`, `EnableBiometricUseCase`, `DisableBiometricUseCase`, `SignInWithBiometricUseCase`, `WatchAuthStateUseCase`). Pure Dart. Imports nothing outside `dart:*` and `domain/`.
- **`data/`** owns: `UserModel` (Firestore DTO), `AuthDatasource` (raw Firebase Auth + local_auth + flutter_secure_storage calls), `AuthRepositoryImpl` (orchestrates datasource calls, maps `FirebaseAuthException` codes to `AuthException` subclasses, returns domain entities).
- **`presentation/features/auth/`** owns: `@riverpod` providers that wrap use cases, screens (sign-in, sign-up, verify-email, splash), and biometric prompt widgets. Never touches Firebase directly.

#### Biometric flow (explicit — this is the load-bearing part of the ADR)

Biometric authentication on this app does NOT replace Firebase identity. `local_auth` only proves that the device's current user is the legitimate owner of the device. Firebase still requires real credentials to mint an ID token. The flow is therefore:

**One-time biometric enrollment (after a successful password sign-in):**
1. User signs in with email + password via Firebase Auth.
2. If sign-in succeeds AND `emailVerified == true`, presentation layer asks: "Enable biometric unlock on this device?"
3. If user accepts, `EnableBiometricUseCase` runs:
   - `local_auth` performs a biometric check to confirm the current device user.
   - On success, `AuthDatasource` writes `email` and `password` into `flutter_secure_storage` under namespaced keys (`auth.biometric.email`, `auth.biometric.password`). Storage is configured with `AndroidOptions(encryptedSharedPreferences: true)` on Android and Keychain `accessible: first_unlock_this_device_only` on iOS/macOS.
   - A boolean flag `auth.biometric.enabled = true` is written to secure storage.
4. The password is never written to Firestore, SharedPreferences, or logs.

**Biometric sign-in (subsequent app launches):**
1. Splash screen reads `auth.biometric.enabled` from secure storage via the repository.
2. If enabled and the user is signed out, the sign-in screen shows a "Sign in with biometrics" button.
3. On tap, `SignInWithBiometricUseCase` runs:
   - `local_auth.authenticate()` prompts for fingerprint/face. If the user cancels or fails, return `AuthException.biometricFailed`.
   - On success, datasource reads `email` and `password` from secure storage.
   - Datasource calls `FirebaseAuth.signInWithEmailAndPassword(...)` with those credentials.
   - If Firebase rejects the credentials (e.g. user changed password from another device), datasource wipes the biometric cache and returns `AuthException.biometricCredentialsStale`. The user is forced back to password sign-in.
4. On Firebase success, the normal auth state stream emits and the router redirects to `/home`.

**Disabling biometric / signing out:**
- `SignOutUseCase` always wipes the biometric cache (`flutter_secure_storage.deleteAll()` scoped to the `auth.*` namespace) so a shared device cannot be reopened by the next physical user.
- `DisableBiometricUseCase` wipes the cache without touching the Firebase session.

**Web target:** `local_auth` is not supported on web. The repository's `isBiometricSupported()` returns false on web, and the presentation layer hides the biometric controls. Web users always sign in with password. This is documented behavior, not a bug.

#### Email domain validation (defense in depth)

Validation runs at three layers — each is enforced independently:

1. **Client (presentation).** The sign-up form's email validator (from `core/utils/validators.dart`) rejects any email whose domain is not in `AuthConstants.allowedEmailDomains`. This is a UX layer — fast feedback, no network round-trip.
2. **Use case (domain).** `SignUpUseCase.execute()` re-validates the domain before delegating to the repository. This is the authoritative client-side check; the screen-level validator is allowed to be bypassed (e.g. dev tools) but the use case cannot. Throws `AuthException.invalidEmailDomain` on rejection.
3. **Firestore security rules (server).** The `users/{uid}` document's create rule requires `request.auth.token.email` to end with `@kmutt.ac.th` or `@mail.kmutt.ac.th` (and `@gmail.com` while the dev flag is on). This is the trust boundary — even a tampered client cannot create a Firestore user document with a non-KMUTT email. firebase-specialist owns the exact rule.

If the `gmail.com` dev exception is removed before launch, all three layers must be updated together. The constant in `core/constants/auth_constants.dart` is the single source of truth on the client; the Firestore rule must mirror it.

#### Credential storage (where secrets live)

| Secret | Stored in | Lifetime |
|--------|-----------|----------|
| Firebase ID token | Firebase Auth SDK internal storage (managed by SDK) | Until sign-out or token refresh failure |
| Email + password for biometric unlock | `flutter_secure_storage` only (Keystore on Android, Keychain on iOS) | Until sign-out, biometric disable, or stale-credentials detection |
| Session/Firestore data | Firestore (no credentials ever) | Per Firestore rules |
| In-memory password during sign-in | Local variable inside `AuthDatasource.signIn`; never assigned to a field, never logged | Single call frame |

**Forbidden storage locations** (enforced by code review): `SharedPreferences`, Firestore, Realtime Database, app memory beyond one call, log output (Crashlytics, debugPrint, analytics events), filesystem outside Keystore/Keychain.

#### Error surface (no email enumeration)

`AuthRepositoryImpl` maps `FirebaseAuthException` codes as follows. The presentation layer displays `exception.message` directly; the message is the contract.

| Firebase code | Mapped to | Displayed message |
|---|---|---|
| `user-not-found` | `AuthException.invalidCredentials` | "Email or password is incorrect." |
| `wrong-password` | `AuthException.invalidCredentials` | "Email or password is incorrect." |
| `invalid-credential` | `AuthException.invalidCredentials` | "Email or password is incorrect." |
| `email-already-in-use` | `AuthException.emailAlreadyInUse` | "An account with this email already exists." |
| `weak-password` | `AuthException.weakPassword` | "Password is too weak. Use at least 8 characters." |
| `network-request-failed` | `AuthException.network` | "Network error. Check your connection." |
| `too-many-requests` | `AuthException.rateLimited` | "Too many attempts. Try again in a few minutes." |
| `user-disabled` | `AuthException.accountDisabled` | "This account has been disabled. Contact support." |
| (any other) | `AuthException.unknown` | "Sign-in failed. Please try again." |

`user-not-found` and `wrong-password` MUST share an identical message and identical exception subtype. Any divergence is a security bug. This is verified by a unit test in `test/unit/auth/auth_error_mapping_test.dart` (owned by qa-engineer).

PII rule: exception messages never contain the email being signed in. Crashlytics calls in the data layer pass `reason: 'auth.signIn'` with no PII payload.

---

### Layer contracts

The following files will be created. This list is the complete inventory for the auth feature; nothing else may be added without a follow-up ADR. Method signatures are illustrative Dart — the implementation agents (firebase-specialist, flutter-engineer) own the final syntax but must preserve the public API shape.

#### Core (shared)

```
core/constants/auth_constants.dart
  class AuthConstants {
    static const List<String> allowedEmailDomains;       // ['kmutt.ac.th', 'mail.kmutt.ac.th', 'gmail.com' (dev)]
    static const String biometricEnabledKey;             // 'auth.biometric.enabled'
    static const String biometricEmailKey;               // 'auth.biometric.email'
    static const String biometricPasswordKey;            // 'auth.biometric.password'
    static const Duration emailVerificationPollInterval; // 3 seconds
  }

core/errors/app_exceptions.dart                          (extend existing AppException)
  sealed class AuthException implements AppException {
    final String message;
    const factory AuthException.invalidCredentials() = _InvalidCredentials;
    const factory AuthException.invalidEmailDomain() = _InvalidEmailDomain;
    const factory AuthException.emailAlreadyInUse() = _EmailAlreadyInUse;
    const factory AuthException.weakPassword() = _WeakPassword;
    const factory AuthException.emailNotVerified() = _EmailNotVerified;
    const factory AuthException.biometricUnavailable() = _BiometricUnavailable;
    const factory AuthException.biometricFailed() = _BiometricFailed;
    const factory AuthException.biometricNotEnrolled() = _BiometricNotEnrolled;
    const factory AuthException.biometricCredentialsStale() = _BiometricCredentialsStale;
    const factory AuthException.network() = _Network;
    const factory AuthException.rateLimited() = _RateLimited;
    const factory AuthException.accountDisabled() = _AccountDisabled;
    const factory AuthException.unknown() = _Unknown;
  }

core/router/app_router.dart
  GoRouter with redirect():
    if !signedIn          → /sign-in
    if signedIn && !emailVerified → /verify-email
    if signedIn && emailVerified && currentLocation in auth routes → /home
```

#### Domain (pure Dart — zero Flutter/Firebase imports)

```
domain/entities/user.dart
  class User {
    final String uid;
    final String email;
    final String username;
    final String? photoUrl;
    final String faculty;
    final String academicLevel;     // enum-as-string; safe parsing in data layer
    final int studentYear;
    final bool emailVerified;
    final DateTime createdAt;
    final DateTime updatedAt;
    const User({...});
    User copyWith({...});
  }

domain/repositories/auth_repository.dart
  abstract class AuthRepository {
    Stream<User?> watchAuthState();
    Future<User> signIn({required String email, required String password});
    Future<User> signUp({
      required String email,
      required String password,
      required String username,
    });
    Future<void> signOut();
    Future<void> sendEmailVerification();
    Future<User> reloadCurrentUser();                    // forces Firebase to refresh emailVerified
    Future<bool> isBiometricSupported();                 // device capability + platform check
    Future<bool> isBiometricEnabled();                   // user opted in on this device
    Future<void> enableBiometric({required String email, required String password});
    Future<void> disableBiometric();
    Future<User> signInWithBiometric();
  }

domain/usecases/auth/sign_in_usecase.dart
  class SignInUseCase {
    SignInUseCase(this._repo);
    final AuthRepository _repo;
    Future<User> execute({required String email, required String password});
    // Responsibility: validate domain, delegate to repo. No UI, no Firebase.
  }

domain/usecases/auth/sign_up_usecase.dart
  class SignUpUseCase {
    Future<User> execute({
      required String email,
      required String password,
      required String username,
    });
    // Validates email domain + password strength + username format.
  }

domain/usecases/auth/sign_out_usecase.dart
  class SignOutUseCase {
    Future<void> execute();
    // Always wipes biometric cache via repo.disableBiometric() before Firebase sign-out.
  }

domain/usecases/auth/send_email_verification_usecase.dart
  class SendEmailVerificationUseCase {
    Future<void> execute();
  }

domain/usecases/auth/reload_user_usecase.dart
  class ReloadUserUseCase {
    Future<User> execute();
  }

domain/usecases/auth/enable_biometric_usecase.dart
  class EnableBiometricUseCase {
    Future<void> execute({required String email, required String password});
  }

domain/usecases/auth/disable_biometric_usecase.dart
  class DisableBiometricUseCase {
    Future<void> execute();
  }

domain/usecases/auth/sign_in_with_biometric_usecase.dart
  class SignInWithBiometricUseCase {
    Future<User> execute();
  }

domain/usecases/auth/watch_auth_state_usecase.dart
  class WatchAuthStateUseCase {
    Stream<User?> execute();
  }
```

#### Data (Firebase + local_auth + secure storage)

```
data/models/user_model.dart
  class UserModel {
    // mirrors User but with Firestore types (Timestamp).
    factory UserModel.fromFirestore(DocumentSnapshot doc);
    factory UserModel.fromFirebaseAuth(fb.User firebaseUser, {Map<String, dynamic>? profile});
    Map<String, dynamic> toFirestore();
    User toEntity();
  }

data/datasources/auth_datasource.dart
  class AuthDatasource {
    AuthDatasource({
      required FirebaseAuth firebaseAuth,
      required FirebaseFirestore firestore,
      required LocalAuthentication localAuth,
      required FlutterSecureStorage secureStorage,
    });

    // Firebase Auth
    Stream<fb.User?> authStateChanges();
    Future<fb.UserCredential> signInWithEmailAndPassword(String email, String password);
    Future<fb.UserCredential> createUserWithEmailAndPassword(String email, String password);
    Future<void> sendEmailVerification();
    Future<void> reloadCurrentUser();
    Future<void> signOut();
    fb.User? get currentFirebaseUser;

    // Firestore user profile (writes only — reads go through user_repository)
    Future<void> createUserProfile(UserModel model);

    // local_auth
    Future<bool> isBiometricDeviceCapable();             // canCheckBiometrics && isDeviceSupported
    Future<bool> authenticateBiometric({required String reason});

    // flutter_secure_storage
    Future<void> writeBiometricCredentials({required String email, required String password});
    Future<({String email, String password})?> readBiometricCredentials();
    Future<void> clearBiometricCredentials();
    Future<bool> isBiometricEnabledFlag();
  }

data/repositories/auth_repository_impl.dart
  class AuthRepositoryImpl implements AuthRepository {
    AuthRepositoryImpl(this._datasource);
    final AuthDatasource _datasource;

    @override Stream<User?> watchAuthState();             // merges authStateChanges + Firestore profile fetch
    @override Future<User> signIn({...});                 // wraps datasource, maps errors to AuthException
    @override Future<User> signUp({...});                 // create user → send verification → write Firestore profile
    @override Future<void> signOut();                     // clearBiometricCredentials() then datasource.signOut()
    @override Future<void> sendEmailVerification();
    @override Future<User> reloadCurrentUser();
    @override Future<bool> isBiometricSupported();        // false on web; delegates to datasource elsewhere
    @override Future<bool> isBiometricEnabled();
    @override Future<void> enableBiometric({...});        // local_auth prompt → secure_storage write
    @override Future<void> disableBiometric();
    @override Future<User> signInWithBiometric();         // local_auth → read creds → Firebase sign-in
  }
```

#### Presentation (Riverpod codegen + screens)

```
presentation/features/auth/providers/auth_dependencies.dart
  @riverpod AuthRepository authRepository(AuthRepositoryRef ref);
  // Wires the concrete AuthRepositoryImpl with its datasource. The only place
  // where data/ is imported in presentation/. All other providers depend on
  // AuthRepository (the abstract interface) — never the impl.

presentation/features/auth/providers/auth_usecases.dart
  @riverpod SignInUseCase signInUseCase(SignInUseCaseRef ref);
  @riverpod SignUpUseCase signUpUseCase(SignUpUseCaseRef ref);
  @riverpod SignOutUseCase signOutUseCase(SignOutUseCaseRef ref);
  @riverpod SendEmailVerificationUseCase sendEmailVerificationUseCase(...);
  @riverpod ReloadUserUseCase reloadUserUseCase(...);
  @riverpod EnableBiometricUseCase enableBiometricUseCase(...);
  @riverpod DisableBiometricUseCase disableBiometricUseCase(...);
  @riverpod SignInWithBiometricUseCase signInWithBiometricUseCase(...);
  @riverpod WatchAuthStateUseCase watchAuthStateUseCase(...);

presentation/features/auth/providers/auth_state_provider.dart
  @riverpod Stream<User?> authState(AuthStateRef ref);
  // Exposes WatchAuthStateUseCase. Used by GoRouter redirect.

presentation/features/auth/providers/biometric_availability_provider.dart
  @riverpod Future<bool> biometricSupported(BiometricSupportedRef ref);
  @riverpod Future<bool> biometricEnabled(BiometricEnabledRef ref);

presentation/features/auth/providers/auth_controller.dart
  @riverpod class AuthController extends _$AuthController {
    @override FutureOr<void> build();                    // idle state
    Future<void> signIn({required String email, required String password});
    Future<void> signUp({required String email, required String password, required String username});
    Future<void> signOut();
    Future<void> resendVerificationEmail();
    Future<void> checkEmailVerified();
    Future<void> enableBiometric({required String email, required String password});
    Future<void> disableBiometric();
    Future<void> signInWithBiometric();
  }
  // AsyncNotifier — state is AsyncValue<void>. Screens read AsyncValue to drive
  // loading spinners and error banners. Never throws to the UI directly.

presentation/features/auth/screens/splash_screen.dart        → route: /
presentation/features/auth/screens/sign_in_screen.dart       → route: /sign-in
presentation/features/auth/screens/sign_up_screen.dart       → route: /sign-up
presentation/features/auth/screens/verify_email_screen.dart  → route: /verify-email

presentation/features/auth/widgets/biometric_prompt_button.dart
presentation/features/auth/widgets/email_domain_hint.dart
presentation/features/auth/widgets/auth_error_banner.dart
```

---

### Dependency diagram

```
SignInScreen (presentation/features/auth/screens/)
  └── AuthController (@riverpod AsyncNotifier)
        ├── SignInUseCase
        │     └── AuthRepository (abstract — domain/)
        │           └── AuthRepositoryImpl (data/)
        │                 ├── AuthDatasource
        │                 │     ├── FirebaseAuth.signInWithEmailAndPassword
        │                 │     └── FirebaseFirestore.users.doc(uid).get
        │                 └── UserModel.toEntity()
        └── SignInWithBiometricUseCase
              └── AuthRepository (abstract — domain/)
                    └── AuthRepositoryImpl (data/)
                          └── AuthDatasource
                                ├── LocalAuthentication.authenticate
                                ├── FlutterSecureStorage.read('auth.biometric.email')
                                ├── FlutterSecureStorage.read('auth.biometric.password')
                                └── FirebaseAuth.signInWithEmailAndPassword
```

```
SignUpScreen
  └── AuthController
        └── SignUpUseCase
              ├── validates domain via AuthConstants.allowedEmailDomains
              └── AuthRepository (abstract)
                    └── AuthRepositoryImpl
                          └── AuthDatasource
                                ├── FirebaseAuth.createUserWithEmailAndPassword
                                ├── FirebaseAuth.currentUser.sendEmailVerification
                                └── FirebaseFirestore.users.doc(uid).set(UserModel.toFirestore())
```

```
GoRouter.redirect (core/router/app_router.dart)
  └── authStateProvider (@riverpod Stream<User?>)
        └── WatchAuthStateUseCase
              └── AuthRepository.watchAuthState()
                    └── AuthRepositoryImpl
                          └── AuthDatasource.authStateChanges()
                                └── FirebaseAuth.authStateChanges
```

The arrows above show the only legal call paths. Any deviation (e.g. a screen importing `cloud_firestore`, or a provider calling `FirebaseAuth.instance` directly) is a layer violation and must be rejected by code-reviewer.

---

### Consequences

**Positive**

- Auth subsystem is fully testable. Use cases unit-test against a fake `AuthRepository` with no Firebase dependency. Data layer tests use `fake_cloud_firestore` and a mocked `LocalAuthentication`. Widget tests override `authRepositoryProvider` with a fake.
- Email-enumeration class of vulnerabilities is closed at the mapping layer; one unit test in qa-engineer's suite locks it.
- Biometric is treated as a UX shortcut over Firebase, not a parallel identity system. There is no second source of truth for "who the user is" — Firebase remains canonical.
- Secret-storage policy is centralized in `AuthDatasource`. Adding a new credential type later only touches one file.
- Router guard reads exactly one provider (`authStateProvider`); navigation logic doesn't fan out across screens.

**Negative / cost**

- Nine use cases for one feature feels heavy. Justification: rubric requires biometric, and biometric introduces three new operations (enable, disable, sign-in-with). The flutter-engineer should not collapse these into the controller — the use cases are the seam for unit testing.
- The web build silently disables biometric. This must be in the docs the docs-writer produces; a user toggling biometric on Android and then opening web will see no biometric button, by design.
- `flutter_secure_storage` adds a native dependency; CI must run on both Android and Web. Web target uses the package's IndexedDB fallback, but we explicitly do not write credentials there — `isBiometricSupported()` returns false on web before any write is attempted.
- The dev-only `gmail.com` exception lives in three places (client constant, use case validator, Firestore rule). Removing it pre-launch is a coordinated change — tracked as a launch checklist item, not a feature flag.

**Follow-ups required (not in this ADR)**

- ADR 0002 — Firestore schema for `users/{uid}` (firebase-specialist).
- ADR 0003 — Firestore security rules covering the KMUTT-domain create rule (firebase-specialist + security-reviewer).
- `docs/feature-flags.md` entry for `auth.allowGmailDev` with a rollback plan (docs-writer).

---

### Alternatives considered

1. **Firebase Anonymous → link with credential.** Sign in anonymously on first launch, then link to email/password later. Rejected: email verification gate becomes harder (anonymous users have no email), and the KMUTT domain check has to happen at link time rather than sign-up time, which complicates the UX. No measurable benefit for this app.

2. **Platform keystore directly (no `flutter_secure_storage`).** Implement Android Keystore and iOS Keychain via platform channels. Rejected: `flutter_secure_storage` is a thin, well-audited wrapper over exactly those APIs. Reimplementing it is scope creep with no security gain. We do, however, configure it with the strict options (`encryptedSharedPreferences: true`, `first_unlock_this_device_only`) so we get the same guarantees.

3. **Biometric as a second-factor for every sign-in.** Require biometric on every launch even if the user just opened the app. Rejected: misreads rubric R1, which asks for biometric *as* a sign-in method. Forcing it on top of password sign-in degrades UX without raising the security bar (the password sign-in already authenticated). The chosen design uses biometric as a faster path to the same Firebase identity.

4. **Store a long-lived Firebase custom token instead of email+password.** On enable-biometric, mint a long-lived token via a Cloud Function and store that instead of the password. Rejected for v1: requires a Cloud Function (no Functions runtime is provisioned), and storing a long-lived token is not measurably safer than storing the password since both are equally sensitive in Keystore. Revisit if we add Cloud Functions for other reasons.

5. **Domain validation only at Firestore rules.** Skip client-side validation and rely entirely on the security rule. Rejected: poor UX (user fills out the whole form, hits submit, gets a generic "permission denied"). Client validation gives instant feedback; rule validation is the trust boundary. We keep both.

6. **One mega `AuthService` (legacy pattern from `docs/references/`).** Single class, all responsibilities. Rejected: that is exactly the pattern that made the legacy app untestable. The reference code is included only for UI inspiration, not for architecture.

7. **Riverpod `StateNotifier` instead of `@riverpod` codegen.** Rejected: CLAUDE.md mandates codegen. No exception.

---

### Hand-off

- **firebase-specialist** owns: `data/models/user_model.dart`, `data/datasources/auth_datasource.dart`, `data/repositories/auth_repository_impl.dart`, and the Firestore rule for `users/{uid}` create (in ADR 0003).
- **flutter-engineer** owns: everything in `presentation/features/auth/`, `core/router/app_router.dart`, `core/constants/auth_constants.dart`, `core/errors/app_exceptions.dart` additions, and the domain entity + repository interface + use cases under `domain/`. (Domain is plain Dart and conventionally lives on the flutter-engineer's plate since it has no Firebase calls.)
- **qa-engineer** owns: error-mapping test, biometric flow widget test (with mocked `LocalAuthentication`), and an integration test of the full sign-up → verify → sign-in path on Android.
- **security-reviewer** must sign off on: error mapping (no enumeration), secure storage configuration, log scrubbing, and the Firestore rule before merge.

Implementation is blocked on human approval of this ADR.
