# Audit report

| Field | Value |
|---|---|
| Agent | security-reviewer |
| Date | 2026-05-16 |
| Session ID | claude-sonnet-4-6 / DeepseaMew / 2026-05-16 |
| Triggered by | feat/auth — merge to develop pre-check |
| Reviewed scope | firestore.rules, apps/mobile/lib/features/auth/, apps/mobile/lib/core/router/app_router.dart, apps/mobile/lib/core/analytics_events.dart, apps/mobile/lib/core/logger.dart, apps/mobile/lib/main.dart, apps/mobile/lib/firebase_options.dart, apps/mobile/test/features/auth/, apps/mobile/test/core/router/ |

---

## Security Reviewer section

### Critical (block merge)

- **SEC-001 — Live Firebase API keys committed in `firebase_options.dart`**
  `apps/mobile/lib/firebase_options.dart` lines 53, 62 contain two hardcoded Firebase API keys (`AIzaSyAURkDGolbdID4YNF37LddnRwnTN1F02Oc`, `AIzaSyCBhHGJrr7VdVtzCe80TFCzokPdTZzKp5A`). The file is tracked by git and is NOT excluded by `apps/mobile/.gitignore` (which correctly excludes `google-services.json` and `GoogleService-Info.plist` but not `firebase_options.dart`). The keys will propagate into develop branch history on merge. An attacker with repo read access can use them to enumerate Firebase project resources, abuse Firebase Auth quotas, or read accessible Firestore data.
  **Required fix:** (1) Add `**/lib/firebase_options.dart` to `apps/mobile/.gitignore`. (2) Rotate both API keys in the Firebase console immediately — keys already pushed to remote are compromised. (3) Inject `firebase_options.dart` at CI build time from secrets rather than committing it (release-engineer scope). This is a hard blocker for merge.

- **SEC-002 — `firebase_auth` imported outside the designated datasource file (ADR 0002 boundary violation)**
  ADR 0002 Consequences explicitly states: "`auth_datasource.dart` — wraps `FirebaseAuth`; only file allowed to import `firebase_auth`." Two files violate this:
  - `apps/mobile/lib/features/auth/data/repositories/auth_repository_impl.dart` line 1: imports `firebase_auth` to catch `FirebaseAuthException` directly in the repository layer. Firebase exception translation must happen at the datasource boundary.
  - `apps/mobile/lib/features/auth/presentation/providers/auth_state_notifier_provider.dart` lines 2, 40, 139: imports `firebase_auth` and calls `FirebaseAuth.instance.currentUser` directly, bypassing `AuthRepository` entirely. This creates an untestable hidden coupling in the presentation layer.
  Note: `apps/mobile/lib/features/auth/presentation/providers/firebase_auth_state_provider.dart` also imports `firebase_auth` and is the designated stream provider per ADR 0002 sub-decision 4 Option A — its import is architecturally intentional and should be listed as the second permitted site in an ADR 0002 amendment.
  **Required fix:** (1) Move `FirebaseAuthException` catching and translation to `AuthDatasource`; remove `firebase_auth` import from `auth_repository_impl.dart`. (2) Add `currentUser` to `AuthRepository` interface and implement via `_datasource`; replace both `FirebaseAuth.instance.currentUser` calls in `auth_state_notifier_provider.dart` with `ref.read(authRepositoryProvider).currentUser`. (3) Amend ADR 0002 to formally name `firebase_auth_state_provider.dart` as the second permitted import site. This is a hard blocker for merge.

### High (fix before release)

- **SEC-003 — Deliberate test crash does not call `FirebaseCrashlytics.instance.crash()`**
  `apps/mobile/lib/shared/screens/home_placeholder_screen.dart` lines 48–59: the debug crash button throws `Exception('Test crash')` rather than calling `FirebaseCrashlytics.instance.crash()`. The exception does reach Crashlytics via the wired `FlutterError.onError` handler, and a Crashlytics evidence screenshot exists at `docs/audit/evidence/crashlytics-test-crash.png`. However the intent ("verify Crashlytics receives data") is ambiguous — a thrown exception traversing three handler layers is not as direct as `crash()`.
  **Recommended fix:** Replace `throw Exception('Test crash')` with `FirebaseCrashlytics.instance.crash()` guarded by `kDebugMode`.

- **SEC-004 — Leading-whitespace email passes KMUTT regex (defence-in-depth gap)**
  `apps/mobile/lib/features/auth/data/repositories/auth_repository_impl.dart` line 40: regex `r'^[^@]+@(mail\.kmutt\.ac\.th|kmutt\.ac\.th)$'` uses `[^@]+` in the local-part, which matches ASCII space. Input `' user@mail.kmutt.ac.th'` (leading space) passes the KMUTT guard and reaches the Firebase datasource. Firebase Auth rejects malformed emails upstream, so no non-KMUTT registration is possible. However `authKmuttDomainRejected` is not fired for these inputs, creating a monitoring blind spot. (Documented in `auth_repository_impl_test.dart` test case 7; `sign_up_screen.dart` mitigates at call site via `.trim()`.)
  **Recommended fix:** Add `.trim()` call on `email` before the regex check in `signUp()`, or change `[^@]+` to `[^\s@]+`.

### Informational

- Firestore rules match ADR 0001 specification exactly: `isKmuttUser()` helper (lines 8–12) matches ADR 0001 lines 226–230. `users/{uid}` create rule (lines 43–54) validates required keys via `hasAll`, KMUTT email regex, `createdAt == request.time`, `updatedAt == request.time`, `hasHostedBefore == false`, `profileScore == 0.0`. Update rule (lines 56–64) uses `diff().affectedKeys().hasOnly(...)` with correct mutable field list; `uid`, `createdAt`, `email` are immutable. Delete is denied. No `allow read, write: if true` blocks anywhere. PASS.
- `users/{uid}` read permits any verified KMUTT user to read any other user's document including `fullName` (PII). This broad read is a deliberate design choice required for session/friend lookup per ADR 0001. Note for future ADR: when Profile feature lands, consider scoping `fullName` reads to friends/session members only.
- KMUTT regex runs before Firebase call — `auth_repository_impl.dart` lines 40–45 confirm the domain check and rejection precede `createUserWithEmailAndPassword` at line 49. PASS.
- No `print()` calls in `lib/` — grep confirmed zero occurrences. All output routes through `appLogger`. PASS.
- No `Image.network()` calls in `lib/` — confirmed zero occurrences. PASS.
- No PII in log statements — reviewed all auth files; no email, fullName, displayName, or uid in any `appLogger.*` call or log string. `authKmuttDomainRejected` event logged as a constant name with no email payload. PASS.
- No Crashlytics custom keys with PII — no `setCustomKey` calls found anywhere in `lib/`. PASS.
- Crashlytics wiring confirmed — `main.dart`: `FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError` and `PlatformDispatcher.instance.onError` both wired. `runZonedGuarded` provides a third layer. PASS.
- `flutter_secure_storage` NOT used by auth — confirmed. Firebase Auth default token storage used per ADR 0002. PASS.
- All analytics events declared before use — `analytics_events.dart` declares all seven events required by ADR 0002 lines 226–233. All `AnalyticsEvents.*` references in providers cross-reference declared constants. PASS.
- Router redirect guard exhaustive — `app_router.dart` uses a sealed `switch` on `AuthState`. `pendingProfileSetup` cannot reach `/home`, `/calendar`, `/messages`, `/my-sessions`. 10 redirect guard tests in `app_router_test.dart` confirm all variants. PASS.
- `google-services.json` and `GoogleService-Info.plist` are gitignored — confirmed in `apps/mobile/.gitignore`. Does not mitigate SEC-001.
- `_kmuttRegex` constant is duplicated in `auth_repository_impl.dart` line 9 and `sign_up_screen.dart` line 10. Maintenance risk: a future domain change must be applied in both files. Recommended fix: extract to a shared constant in `lib/core/` and import in both files.

### JSON report

```json
{
  "agent": "security-reviewer",
  "date": "2026-05-16",
  "findings": [
    {
      "id": "SEC-001",
      "severity": "critical",
      "title": "Live Firebase API keys committed in firebase_options.dart",
      "file": "apps/mobile/lib/firebase_options.dart",
      "lines": "53, 62",
      "description": "Two Firebase API keys hardcoded in tracked source file not covered by .gitignore. Keys will propagate to develop branch history on merge.",
      "required_action": "Add firebase_options.dart to .gitignore, rotate both API keys in Firebase console, inject via CI secrets."
    },
    {
      "id": "SEC-002",
      "severity": "critical",
      "title": "firebase_auth imported outside designated datasource file — ADR 0002 boundary violation",
      "files": [
        "apps/mobile/lib/features/auth/data/repositories/auth_repository_impl.dart:1",
        "apps/mobile/lib/features/auth/presentation/providers/auth_state_notifier_provider.dart:2,40,139"
      ],
      "description": "ADR 0002 restricts firebase_auth imports to auth_datasource.dart only. Repository catches FirebaseAuthException directly; notifier calls FirebaseAuth.instance.currentUser directly, bypassing repository interface. Creates untestable hidden coupling.",
      "required_action": "Move FirebaseAuthException handling to AuthDatasource. Add currentUser to AuthRepository interface. Replace FirebaseAuth.instance.currentUser calls in notifier with repository calls. Amend ADR 0002 to name firebase_auth_state_provider.dart as permitted second site."
    },
    {
      "id": "SEC-003",
      "severity": "high",
      "title": "Deliberate test crash does not call FirebaseCrashlytics.instance.crash()",
      "file": "apps/mobile/lib/shared/screens/home_placeholder_screen.dart",
      "lines": "48-59",
      "description": "Debug crash button throws bare Exception rather than invoking FirebaseCrashlytics.instance.crash(). Crash does reach Crashlytics via wired handler. Crashlytics evidence screenshot present.",
      "required_action": "Replace throw Exception with FirebaseCrashlytics.instance.crash() guarded by kDebugMode."
    },
    {
      "id": "SEC-004",
      "severity": "high",
      "title": "Leading-whitespace email passes KMUTT regex — defence-in-depth gap",
      "file": "apps/mobile/lib/features/auth/data/repositories/auth_repository_impl.dart",
      "line": "40",
      "description": "Regex [^@]+ allows space in local-part; ' user@mail.kmutt.ac.th' passes KMUTT guard. Firebase rejects malformed email upstream. authKmuttDomainRejected event not fired. Sign-up screen mitigates via .trim() at call site.",
      "required_action": "Add email.trim() before regex check in signUp(), or change [^@]+ to [^\\s@]+."
    },
    {
      "id": "SEC-005",
      "severity": "informational",
      "title": "_kmuttRegex constant duplicated across two files",
      "files": [
        "apps/mobile/lib/features/auth/data/repositories/auth_repository_impl.dart:9",
        "apps/mobile/lib/features/auth/presentation/screens/sign_up_screen.dart:10"
      ],
      "description": "Maintenance risk: future domain changes must be applied in both files.",
      "required_action": "Extract to a shared constant in lib/core/."
    }
  ],
  "severity_max": "critical",
  "verdict": "BLOCKED",
  "summary": "Two critical findings block merge to develop: (1) live Firebase API keys in committed firebase_options.dart must be rotated and gitignored before any push to develop; (2) firebase_auth imported directly in auth_repository_impl.dart and auth_state_notifier_provider.dart violates ADR 0002 architectural boundary and creates untestable Firebase couplings. All Firestore rules match ADR 0001 spec exactly. No PII in logs or Crashlytics keys. Router guard is exhaustive and tested. Two high findings (test crash wiring, leading-whitespace email) should be resolved before release."
}
```

### Verdict

BLOCKED — Two critical findings must be resolved before merge to develop: (1) live Firebase API keys in `firebase_options.dart` must be rotated and the file gitignored and CI-injected; (2) `firebase_auth` imported directly in `auth_repository_impl.dart` and `auth_state_notifier_provider.dart` in violation of ADR 0002 architectural boundary, creating untestable Firebase couplings in the repository and presentation layers.

---

## Re-audit — 2026-05-16

| Field | Value |
|---|---|
| Agent | security-reviewer |
| Date | 2026-05-16 |
| Triggered by | Flutter-engineer addressed SEC-002, SEC-003, SEC-004, SEC-005; user addressed SEC-001 gitignore |
| Reviewed scope | firebase_options.dart, auth_datasource.dart, auth_repository.dart, auth_repository_impl.dart, auth_state_notifier_provider.dart, kmutt_email.dart, sign_up_screen.dart, home_placeholder_screen.dart |

### SEC-001 — Live Firebase API keys in `firebase_options.dart` — PARTIAL

`apps/mobile/.gitignore` line 38 now reads `**/lib/firebase_options.dart` — the file is excluded from future commits. However `apps/mobile/lib/firebase_options.dart` still exists in the working tree and still contains the original unrotated keys (`AIzaSyAURkDGolbdID4YNF37LddnRwnTN1F02Oc` line 53, `AIzaSyCBhHGJrr7VdVtzCe80TFCzokPdTZzKp5A` line 62). The gitignore blocks future propagation but does not remediate keys already in branch history. **Key rotation in the Firebase console is still a required action before merge to develop.**

### SEC-002 — `firebase_auth` boundary violation — FIXED

Grep of `apps/mobile/lib/` confirms `package:firebase_auth/firebase_auth.dart` is imported in exactly two files: `auth_datasource.dart` and `firebase_auth_state_provider.dart`. `auth_repository_impl.dart` imports zero Firebase packages. `_mapFirebaseException` is fully implemented in `auth_datasource.dart` lines 136–148 translating `FirebaseAuthException` to typed `AuthFailure` at the datasource boundary. `AuthDatasource.create()` factory exists at line 15. `AuthRepository` interface declares `String? get currentUser;` at line 37. `auth_state_notifier_provider.dart` has zero `firebase_auth` imports; current user is accessed exclusively via `ref.read(authRepositoryProvider).currentUser` at lines 35 and 134. ADR 0002 Amendment 2 boundary is correctly enforced.

### SEC-003 — Debug crash button — FIXED

`apps/mobile/lib/shared/screens/home_placeholder_screen.dart` line 54 calls `FirebaseCrashlytics.instance.crash()` directly inside the `kDebugMode` ternary guard at line 48. No bare `throw Exception` remains.

### SEC-004 — Leading-whitespace email passes KMUTT regex — FIXED

`apps/mobile/lib/features/auth/data/repositories/auth_repository_impl.dart` line 40 assigns `final trimmedEmail = email.trim()` and line 43 applies `RegExp(kmuttEmailPattern).hasMatch(trimmedEmail)`. The shared constant in `apps/mobile/lib/core/validators/kmutt_email.dart` line 9 uses `[^\s@]+` (also closing the embedded-whitespace gap). Tests 7 and 8 in `auth_repository_impl_test.dart` assert the datasource receives the trimmed email.

### SEC-005 — Regex constant duplicated — FIXED

`apps/mobile/lib/core/validators/kmutt_email.dart` declares the single `kmuttEmailPattern` constant. Grep confirms the pattern appears in exactly three `lib/` files: `kmutt_email.dart` (definition), `auth_repository_impl.dart` (import + use), `sign_up_screen.dart` (import + use). Zero inline KMUTT regex string literals exist anywhere else in `lib/`.

### Updated JSON report

```json
{
  "agent": "security-reviewer",
  "date": "2026-05-16",
  "reaudit_date": "2026-05-16",
  "findings": [
    {
      "id": "SEC-001",
      "severity": "critical",
      "status": "PARTIAL",
      "title": "Live Firebase API keys committed in firebase_options.dart",
      "evidence": "firebase_options.dart is now gitignored (apps/mobile/.gitignore line 38) but still present in working tree with original unrotated keys at lines 53 and 62. Key rotation in Firebase console still required before merge."
    },
    {
      "id": "SEC-002",
      "severity": "critical",
      "status": "FIXED",
      "title": "firebase_auth imported outside designated datasource file",
      "evidence": "Grep confirms only auth_datasource.dart and firebase_auth_state_provider.dart import firebase_auth. AuthRepository has String? get currentUser. _mapFirebaseException in AuthDatasource. auth_state_notifier_provider.dart has zero firebase_auth imports."
    },
    {
      "id": "SEC-003",
      "severity": "high",
      "status": "FIXED",
      "title": "Deliberate test crash does not call FirebaseCrashlytics.instance.crash()",
      "evidence": "home_placeholder_screen.dart line 54 calls FirebaseCrashlytics.instance.crash() inside kDebugMode guard."
    },
    {
      "id": "SEC-004",
      "severity": "high",
      "status": "FIXED",
      "title": "Leading-whitespace email passes KMUTT regex",
      "evidence": "auth_repository_impl.dart trims email before regex; kmuttEmailPattern uses [^\\s@]+; tests 7 and 8 assert trimmed value passed to datasource."
    },
    {
      "id": "SEC-005",
      "severity": "informational",
      "status": "FIXED",
      "title": "_kmuttRegex constant duplicated across two files",
      "evidence": "kmutt_email.dart declares single kmuttEmailPattern; both auth_repository_impl.dart and sign_up_screen.dart import from it; zero inline regex literals in lib/."
    }
  ],
  "severity_max": "critical",
  "verdict": "BLOCKED",
  "summary": "SEC-001 is PARTIAL: firebase_options.dart is gitignored (future propagation blocked) but the file still exists in the working tree with the original unrotated API keys. Key rotation in the Firebase console is required before merge. SEC-002 through SEC-005 are fully FIXED."
}
```

### Updated verdict

BLOCKED — SEC-001 is PARTIAL: `firebase_options.dart` is now gitignored but still present in the working tree with the original unrotated API keys at lines 53 and 62. All other findings (SEC-002 through SEC-005) are FIXED. Once the Firebase console keys are rotated and `firebase_options.dart` is removed from the working tree (or regenerated with new keys and kept out of git), this branch is clear to merge to develop.

---

## Re-audit 2 — 2026-05-16

| Field | Value |
|---|---|
| Agent | security-reviewer |
| Date | 2026-05-16 |
| Triggered by | User deleted both leaked keys in Google Cloud Console and regenerated firebase_options.dart via flutterfire configure |
| Reviewed scope | apps/mobile/lib/firebase_options.dart, apps/mobile/.gitignore, git ls-files, git log --all |

### SEC-001 — Live Firebase API keys in `firebase_options.dart` — FIXED

Neither `AIzaSyAURkDGolbdID4YNF37LddnRwnTN1F02Oc` nor `AIzaSyCBhHGJrr7VdVtzCe80TFCzokPdTZzKp5A` appears in the current `apps/mobile/lib/firebase_options.dart`. The file now contains regenerated keys (`AIzaSyCm1yV_blm4Z0Orpo7Z7zpxt6-xZ-4Rqn8` for web, `AIzaSyBFovVmNhlEOSXJCZ5x6t9GdeudL75hFgQ` for Android). `git ls-files apps/mobile/lib/firebase_options.dart` returned empty — the file is untracked. `apps/mobile/.gitignore` line 38 contains `**/lib/firebase_options.dart` — the file is excluded from future commits.

### Git history note — Informational

`git log --oneline --all -- apps/mobile/lib/firebase_options.dart` returned three commits: `9e56390 chore: project setup — agents, skills, CI, theme, fonts, firebase`, `cbeda01 chore: monorepo scaffold complete`, and `689996d chore: monorepo scaffold with Clean Architecture`. The original leaked keys are preserved in git history at those commits. Since both keys have been deleted and revoked in Google Cloud Console they are no longer usable; however, for a pre-production audit this history should be noted. If the repo is ever made public, consider running `git filter-repo` to expunge the historical commits, or ensure the repo remains private until that is done.

### SEC-002 through SEC-005 — FIXED

Status unchanged from Re-audit 1. No re-examination performed per task scope.

### Updated JSON report

```json
{
  "agent": "security-reviewer",
  "date": "2026-05-16",
  "reaudit_2_date": "2026-05-16",
  "findings": [
    {
      "id": "SEC-001",
      "severity": "critical",
      "status": "FIXED",
      "title": "Live Firebase API keys committed in firebase_options.dart",
      "evidence": "Neither AIzaSyAURkDGolbdID4YNF37LddnRwnTN1F02Oc nor AIzaSyCBhHGJrr7VdVtzCe80TFCzokPdTZzKp5A appears in the current file. File is untracked (git ls-files empty). .gitignore line 38 excludes **/lib/firebase_options.dart. Old keys present in git history at commits 9e56390, cbeda01, 689996d — informational only; keys revoked in Google Cloud Console."
    },
    {
      "id": "SEC-002",
      "severity": "critical",
      "status": "FIXED",
      "title": "firebase_auth imported outside designated datasource file",
      "evidence": "Fixed in Re-audit 1. Not re-examined."
    },
    {
      "id": "SEC-003",
      "severity": "high",
      "status": "FIXED",
      "title": "Deliberate test crash does not call FirebaseCrashlytics.instance.crash()",
      "evidence": "Fixed in Re-audit 1. Not re-examined."
    },
    {
      "id": "SEC-004",
      "severity": "high",
      "status": "FIXED",
      "title": "Leading-whitespace email passes KMUTT regex",
      "evidence": "Fixed in Re-audit 1. Not re-examined."
    },
    {
      "id": "SEC-005",
      "severity": "informational",
      "status": "FIXED",
      "title": "_kmuttRegex constant duplicated across two files",
      "evidence": "Fixed in Re-audit 1. Not re-examined."
    }
  ],
  "severity_max": "informational",
  "verdict": "APPROVED",
  "summary": "All five findings are FIXED. SEC-001 is fully resolved: both leaked API keys have been deleted and revoked in Google Cloud Console, firebase_options.dart has been regenerated with new keys via flutterfire configure, the file is untracked, and .gitignore excludes it from future commits. The only remaining note is informational: the original keys are preserved in three historical git commits; since the keys are revoked this poses no active risk, but the repo should remain private or have its history scrubbed before any public release."
}
```

### Updated verdict

APPROVED — All critical and high findings (SEC-001 through SEC-005) are FIXED. The only open item is informational: revoked keys remain in git history at commits `9e56390`, `cbeda01`, `689996d`; no active risk since the keys are deleted in Google Cloud Console, but the repo must remain private or have history scrubbed before any public release.
