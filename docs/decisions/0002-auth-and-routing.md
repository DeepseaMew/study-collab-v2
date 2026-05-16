# 0002 — Auth Flow, Routing, and Riverpod Auth State

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-05-16 |
| Architect session | claude-sonnet-4-6 / DeepseaMew / 2026-05-16 |
| Affects | Auth, Navigation, all features (router guard), Firestore rules (users/{uid}), presentation/providers, core/analytics_events.dart |

---

## Team approval

Approved by: DeepseaMew
Date: 2026-05-16
Notes:
---

## Problem

Study Collab needs a complete, coherent answer to five interlocking questions before any code is written: (1) where the GoRouter lives and how route path strings are declared; (2) how the auth guard reacts to Firebase Auth state changes without polling; (3) how email verification is confirmed without requiring deep-link infrastructure; (4) whether profile setup is a separate route or an inline wizard; and (5) what shape of Riverpod provider owns auth state and surfaces errors. Without a single authoritative record, Flutter Engineers will make divergent choices across features, breaking the auth guard, creating circular provider dependencies, or bypassing the KMUTT email gate.

---

## Constraints

- Domain layer has zero Flutter or Firebase imports; all Firebase Auth types stay in data/ and presentation/providers/.
- Repository interfaces live in `domain/repositories/`; implementations live in `data/repositories/`.
- Entities use Freezed; use cases are plain Dart classes with no Flutter imports.
- Business logic must not be defined in the presentation layer.
- KMUTT email gate (`@mail.kmutt.ac.th` / `@kmutt.ac.th`) enforced by client-side regex AND Firestore rules; no Firebase Auth blocking function (free tier constraint).
- Sign-in methods: email + password only. No Google Sign-In.
- Session persistence: Firebase Auth default token storage. `flutter_secure_storage` is NOT used by auth.
- Sign-up flow is fixed: `/sign-in` → `/verify-email` → `/profile-setup` → `/home`.
- Target platforms: Android and Web only. iOS is out of scope.
- All timestamp fields use `request.time` server-side; Firestore rules use `diff().affectedKeys()` for field-level write validation.
- The router design must not preclude deep links being added later.
- Every analytics event declared in `lib/core/analytics_events.dart` before use.
- No PII in logs, Crashlytics keys, or analytics events.

---

## Options considered

### Sub-decision 1 — Router file structure

#### Option A — Single flat router file at `lib/core/router/app_router.dart`

All route path constants, the `GoRouter` instance, and the `redirect` guard live in one file. The `GoRouter` reads auth state via a `ref.watch` on a `StreamProvider<User?>`. Bottom-nav tabs use `ShellRoute` with nested `StatefulShellRoute` so each tab retains its own navigation stack.

**Trade-offs**
- Pro: simple to locate; one file to audit for guard logic.
- Pro: `StatefulShellRoute` is the GoRouter-idiomatic solution for per-tab history; supported on Web and Android.
- Con: file grows large as routes multiply; must be disciplined about not adding business logic here.
- Reversal cost: low — the file can be split into feature-scoped route files that are re-exported from `app_router.dart` without changing any call sites.

#### Option B — Feature-scoped route files with a top-level assembler

Each feature owns a `routes.dart` file (e.g., `features/auth/presentation/routes.dart`). A thin `lib/core/router/app_router.dart` assembles them. Route path constants live alongside their feature.

**Trade-offs**
- Pro: better separation of concerns; feature teams are self-contained.
- Con: the auth guard must still live in the assembler, creating an indirect coupling. The indirection adds onboarding friction for a small team.
- Con: constant strings are scattered; a typo in one feature's constant is not caught until runtime.
- Reversal cost: medium — moving from Option A to B requires touching every feature's route wiring but no architectural restructuring.

---

**Decision for sub-decision 1:** Option A. A single `app_router.dart` with a `RouteConstants` class for all path strings is simpler to audit, keeps the guard in one place, and the `StatefulShellRoute` handles per-tab history correctly on both Android and Web. Split to Option B if the team grows beyond three concurrent feature engineers.

---

### Sub-decision 2 — Email verification UX

#### Option A — Tap-to-continue button with manual `currentUser.reload()`

The `/verify-email` screen shows a "I've verified my email" button. On tap, the app calls `FirebaseAuth.instance.currentUser?.reload()` then re-reads `currentUser.emailVerified`. If true, the router guard proceeds to `/profile-setup`.

**Trade-offs**
- Pro: zero infrastructure — no deep link scheme, no dynamic links, works on Web without additional URL handling.
- Pro: straightforward to test; no timer race conditions.
- Con: user must return to the app manually and tap; slightly more friction than auto-advance.
- Reversal cost: low — the button can be supplemented or replaced by a deep link redirect in a future ADR without touching the guard logic.

#### Option B — Periodic polling with `Timer.periodic`

A timer fires every 3 seconds, calling `currentUser.reload()` and checking `emailVerified`. On success it navigates automatically.

**Trade-offs**
- Pro: auto-advance without user interaction.
- Con: timer must be cancelled on widget disposal; easy to leak. Adds complexity for minimal UX gain.
- Con: excessive reload calls may trigger Firebase rate limits at scale.
- Reversal cost: low — swapping to Option A or a deep link is a contained change in one screen.

#### Option C — Firebase dynamic link / custom URL scheme deep link

The verification email contains a link that re-opens the app and the router handles the incoming URI to advance state.

**Trade-offs**
- Pro: best UX — fully automatic advance.
- Con: requires Android intent filters and Web hosting configuration; iOS is out of scope now but the manifest changes would need revisiting. Firebase Dynamic Links was deprecated in 2023.
- Con: significantly more infrastructure for MVP; out of scope for this ADR (a future deep-linking ADR will cover it).
- Reversal cost: high — involves platform manifest changes, hosting configuration, and a new ADR.

---

**Decision for sub-decision 2:** Option A. The tap-to-continue button with `currentUser.reload()` is zero-infrastructure, testable, and leaves the door open for a deep-link upgrade in a future ADR without modifying the router guard.

---

### Sub-decision 3 — Profile setup routing

#### Option A — Separate `/profile-setup` route

Profile setup is a standalone screen at `/profile-setup`. The router guard redirects any verified-but-incomplete user to this route by checking `users/{uid}.faculty == ''` from the auth state notifier.

**Trade-offs**
- Pro: clean URL addressability; each screen is independently testable.
- Pro: the guard condition is a simple field check aligned with the `users/{uid}` schema in ADR 0001 (`faculty` is `''` on initial creation).
- Con: requires the auth notifier to also hold profile-completion state, adding one field to the auth entity.
- Reversal cost: low — merging into a wizard is a presentation-layer change that does not touch domain or data layers.

#### Option B — Inline onboarding wizard on `/sign-up/step-{n}`

Profile setup is a multi-step wizard under the sign-up sub-route tree. The wizard manages its own internal page controller; no separate GoRouter routes per step.

**Trade-offs**
- Pro: steps share a single route entry in history, so Back on the wizard exits to `/sign-in`.
- Con: wizard state must be manually preserved across hot-reload; GoRouter's deep-link guarantee is harder to honour for individual steps.
- Con: adds a local wizard state management layer that duplicates what GoRouter already provides.
- Reversal cost: medium — splitting wizard steps into separate routes requires adding route constants and adjusting guard logic.

---

**Decision for sub-decision 3:** Option A. A separate `/profile-setup` route keeps each onboarding screen independently testable and directly addressable, with a simple guard condition (`faculty == ''`) that is already anchored to the ADR 0001 schema.

---

### Sub-decision 4 — Riverpod provider shape for auth state

#### Option A — `StreamProvider<User?>` + derived `AsyncNotifierProvider` for auth entity

A base `firebaseAuthStateProvider` exposes `Stream<User?>` from `FirebaseAuth.instance.authStateChanges()`. A derived `authStateNotifierProvider` (hand-written `AsyncNotifier`) maps the Firebase user to a domain `AuthState` entity (a Freezed sealed class with variants: `unauthenticated`, `unverified`, `pendingProfileSetup`, `authenticated`). All sign-in / sign-out / reload actions live on this notifier.

**Trade-offs**
- Pro: the stream is the source of truth; no manual cache invalidation. The guard reacts immediately when Firebase emits a new token.
- Pro: sealed `AuthState` makes guard logic exhaustive and compiler-checked.
- Pro: domain entity carries no Firebase types, satisfying the domain isolation constraint.
- Con: the `AsyncNotifier` must merge two async sources (Firebase stream + Firestore profile document) to determine `pendingProfileSetup`; requires careful error handling.
- Reversal cost: medium — changing the provider shape requires updating all `ref.watch(authStateNotifierProvider)` call sites across screens and the router guard.

#### Option B — Single `StateNotifierProvider<AuthNotifier, AuthState>` with manual stream subscription

The notifier subscribes to `FirebaseAuth.instance.authStateChanges()` in its constructor and manages the subscription lifecycle manually.

**Trade-offs**
- Pro: all auth logic in one class; no derived provider composition.
- Con: `StateNotifier` is in soft-deprecation in Riverpod 2.x; `AsyncNotifier` is the idiomatic replacement.
- Con: manual subscription management is error-prone; a missed `cancel()` leaks the stream.
- Reversal cost: medium — migrating from `StateNotifier` to `AsyncNotifier` is a contained refactor within the auth feature's presentation/providers/.

---

**Decision for sub-decision 4:** Option A. A `StreamProvider` base with a derived `AsyncNotifier` is idiomatic for Riverpod 2.x + riverpod_generator, keeps Firebase types out of the domain entity, and gives the router a compiler-checked sealed class to switch on.

---

### Sub-decision 5 — Firestore rules for `users/{uid}` (KMUTT gate and email_verified claim)

#### Option A — Dual-layer enforcement: regex in rules + `email_verified` claim check

The `isKmuttUser()` helper in `firestore.rules` (already defined in ADR 0001) enforces both `request.auth.token.email_verified == true` and the KMUTT domain regex. The client-side `AuthRepositoryImpl` also runs the regex before calling `FirebaseAuth.instance.createUserWithEmailAndPassword`, rejecting non-KMUTT emails immediately. No Firebase Auth blocking function is used.

**Trade-offs**
- Pro: defence in depth — a client bug cannot create a Firestore document for a non-KMUTT user; the rules are the last line of defence.
- Pro: `isKmuttUser()` is already specified in ADR 0001; this decision simply affirms it for the auth flow.
- Con: a user can complete Firebase Auth registration with a non-KMUTT email if the client check is bypassed, but they cannot write any Firestore document. The orphaned Auth record is harmless but wasteful.
- Reversal cost: low — adding a Firebase Auth blocking function in the future (paid tier) is additive and does not require changing existing rules.

#### Option B — Client-side regex only

The client rejects non-KMUTT emails before calling Firebase Auth; no server-side check.

**Trade-offs**
- Pro: simpler rules.
- Con: violates the explicit constraint that the KMUTT gate must be enforced server-side. Rejected outright.
- Reversal cost: n/a — this option is ruled out by the locked constraints.

---

**Decision for sub-decision 5:** Option A. Client-side regex for immediate UX feedback, and the `isKmuttUser()` helper in Firestore rules as the authoritative server-side gate. This is already specified in ADR 0001 and is confirmed here as the contract the auth flow must honour.

---

## Decision

The auth and routing system uses a single `app_router.dart` with a `RouteConstants` class, a `StatefulShellRoute` for bottom-nav tab history, and a `redirect` callback that switches on a sealed `AuthState` enum emitted by a derived `AsyncNotifier`. Email verification is confirmed by a tap-to-continue button that calls `currentUser.reload()`, requiring no deep-link infrastructure. Profile setup lives at a separate `/profile-setup` route, guarded by checking `faculty == ''` on the Firestore user document. The Riverpod auth provider chain is `firebaseAuthStateProvider` (StreamProvider) → `authStateNotifierProvider` (AsyncNotifier), with a domain `AuthState` sealed class carrying no Firebase types. The KMUTT email gate is enforced by client-side regex in `AuthRepositoryImpl` and by the `isKmuttUser()` helper in `firestore.rules` as defined in ADR 0001. This design satisfies the free-tier constraint, the domain isolation rule, and leaves the router's `redirect` callback clean enough to add deep-link URI handling in a future ADR without restructuring. At sign-up, `AuthRepositoryImpl` creates the user document with `fullName` and `displayName` both set to the user's form input, `faculty = ''`, and `bio = ''`; profile setup updates `displayName` (if the user wants a different handle), `faculty`, and `bio`, and the guard clears when `faculty` becomes non-empty, per the ADR 0001 schema.

---

## Consequences

**Files to create:**

- `apps/mobile/lib/core/router/app_router.dart` — `GoRouter` instance, `RouteConstants` class (all path string constants), `StatefulShellRoute` for bottom-nav tabs, `redirect` callback wired to `authStateNotifierProvider`.
- `apps/mobile/lib/features/auth/domain/entities/auth_state.dart` — Freezed sealed class with variants: `unauthenticated`, `unverified`, `pendingProfileSetup`, `authenticated`. Zero Flutter or Firebase imports.
- `apps/mobile/lib/features/auth/domain/repositories/auth_repository.dart` — abstract interface: `signIn`, `signUp`, `signOut`, `reloadUser`, `currentUser`, `authStateChanges`.
- `apps/mobile/lib/features/auth/domain/usecases/sign_in_use_case.dart`
- `apps/mobile/lib/features/auth/domain/usecases/sign_up_use_case.dart`
- `apps/mobile/lib/features/auth/domain/usecases/sign_out_use_case.dart`
- `apps/mobile/lib/features/auth/domain/usecases/reload_user_use_case.dart`
- `apps/mobile/lib/features/auth/data/datasources/auth_datasource.dart` — wraps `FirebaseAuth`; only file allowed to import `firebase_auth`.
- `apps/mobile/lib/features/auth/data/repositories/auth_repository_impl.dart` — implements `AuthRepository`; runs KMUTT regex before `createUserWithEmailAndPassword`.
- `apps/mobile/lib/features/auth/presentation/providers/firebase_auth_state_provider.dart` — `@riverpod StreamProvider<User?>` wrapping `authStateChanges()`.
- `apps/mobile/lib/features/auth/presentation/providers/auth_state_notifier_provider.dart` — `@riverpod AsyncNotifier<AuthState>` merging Firebase stream + Firestore profile check.
- `apps/mobile/lib/features/auth/presentation/screens/sign_in_screen.dart`
- `apps/mobile/lib/features/auth/presentation/screens/sign_up_screen.dart` — collects full name, email, password, confirm password; the sign-up handler writes both `fullName` and `displayName` from the same full-name input.
- `apps/mobile/lib/features/auth/presentation/screens/verify_email_screen.dart` — tap-to-continue button; calls `ReloadUserUseCase`.
- `apps/mobile/lib/features/auth/presentation/screens/profile_setup_screen.dart` — collects display name (pre-filled with the current value, which defaults to `fullName` from sign-up, and is editable), faculty, and bio.
- `apps/mobile/lib/shared/screens/home_placeholder_screen.dart` — shell destination.
- The Home feature (browse public sessions) is owned by a future ADR. The placeholder screen renders a simple Scaffold with the text 'Home' and is replaced when the Home ADR lands.

**Firestore rules:** the `isKmuttUser()` helper and `users/{uid}` rules are already specified in ADR 0001. No additional rules are required by this ADR.

**Analytics events to declare in `lib/core/analytics_events.dart` before use:**

- `auth_sign_up_started`
- `auth_sign_up_completed`
- `auth_sign_in_completed`
- `auth_sign_out`
- `auth_verify_email_resend`
- `auth_profile_setup_completed`
- `auth_kmutt_domain_rejected` — fired client-side when the regex rejects a non-KMUTT email; must carry no PII (no email value in the event payload).

**Provider dependency graph (for Flutter Engineer reference):**

```
firebaseAuthStateProvider (StreamProvider<User?>)
  └─ authStateNotifierProvider (AsyncNotifier<AuthState>)
       └─ GoRouter.redirect (reads via ref.watch)
```

**Bottom-nav structure (StatefulShellRoute branches):**

1. Home (`/home`)
2. Calendar (`/calendar`)
3. Messages (`/messages`)
4. My Sessions (`/my-sessions`)

---

## Reversal plan

**Sub-decision 1 (router structure):** If the team switches to feature-scoped route files (Option B), the files that change are: `app_router.dart` (becomes a thin assembler), each feature gains a `routes.dart` file, and `RouteConstants` is split per feature. The router guard logic moves to the assembler. No domain or data layer files change. No downstream ADRs are affected, but a reviewer must verify the guard is still centralised.

**Sub-decision 2 (email verification UX):** If the team later adds deep-link verification, a new ADR covering the Android intent filter, Web hosting redirect, and GoRouter `onDeepLink` handler must be written first. The `verify_email_screen.dart` gains an additional code path; the `reload_user_use_case.dart` remains as a fallback. The `app_router.dart` redirect callback does not change.

**Sub-decision 3 (profile setup routing):** If profile setup is merged into an inline wizard, `profile_setup_screen.dart` becomes a stateful multi-step widget, the `/profile-setup` route constant is removed from `RouteConstants`, and the guard condition in `app_router.dart` changes from a route redirect to an internal wizard step counter. No domain or data layer files change.

**Sub-decision 4 (Riverpod provider shape):** If the provider shape changes (e.g., migrating to a single `Notifier` or adding a second derived provider for user profile), all `ref.watch(authStateNotifierProvider)` call sites across screens and the router guard must be updated. The domain `AuthState` sealed class and all use cases remain unchanged. A security reviewer must re-audit the guard after any provider shape change.

**Sub-decision 5 (Firestore rules):** If a Firebase Auth blocking function is added in the future (requires paid tier), the client-side regex in `auth_repository_impl.dart` becomes redundant but harmless. The `isKmuttUser()` helper in `firestore.rules` remains authoritative and unchanged. ADR 0001 would need an amendment noting the additional enforcement layer.
