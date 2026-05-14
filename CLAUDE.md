# Study Collab V2 — Project Memory

## What this app is
Study Collab is a mobile + web app for KMUTT students to find peers for
study sessions. Built as a capstone mobile dev project following
enterprise-grade multi-agent orchestration patterns.

Single Flutter app in a monorepo. Target platforms: Android and Web.

## Stack
- **Flutter** (stable channel) + **Dart 3.x**
- **State management:** Riverpod 2.x with **code generation**
  (`@riverpod` annotations, `riverpod_generator`, `build_runner`).
  Always use `@riverpod` — never hand-write providers manually.
- **Routing:** GoRouter with authentication guards. Routes in
  `apps/mobile/lib/core/router/`.
- **Backend:** Firebase
  - Auth (university email only — `kmutt.ac.th`, `mail.kmutt.ac.th`)
  - Cloud Firestore (main database)
  - Firebase Storage (profile photos, session files)
  - Firebase Cloud Messaging (push notifications)
  - Firebase Crashlytics (error tracking)
  - Firebase Remote Config (feature flags)

## Architecture — Clean Architecture (strict)

```
apps/mobile/lib/
├── core/              # Shared utilities, constants, errors, theme, router
├── domain/            # Pure Dart — ZERO Flutter/Firebase imports
│   ├── entities/      # Plain Dart classes (immutable, no fromFirestore)
│   ├── repositories/  # Abstract interfaces only
│   └── usecases/      # Single-responsibility business logic
├── data/              # Firebase implementation
│   ├── models/        # DTOs with fromFirestore/toFirestore
│   ├── repositories/  # Concrete implementations of domain interfaces
│   └── datasources/   # Raw Firestore/Storage calls
└── presentation/      # UI + Riverpod providers
    ├── features/      # Feature-first: auth, sessions, friends, chat, etc.
    └── shared/        # Reusable widgets
```

### Layer rules (enforced — never violate)
- **Domain layer:** zero imports from `flutter`, `firebase_core`,
  `cloud_firestore`, or any package. Pure Dart only.
- **Data layer:** knows about Firebase. Implements domain repository
  interfaces. Never imported by presentation directly.
- **Presentation layer:** knows about domain entities and Riverpod
  providers. Never imports data layer directly.
- **Dependency flow:** Presentation → Domain ← Data
- UI never calls Firestore. Path is always:
  widget → provider → use case → repository interface → data repository → Firestore.

## Monorepo layout

```
study_collab_v2/
├── CLAUDE.md
├── .claude/
│   ├── agents/        # Agent definitions
│   ├── skills/        # Reusable playbooks
│   └── commands/      # Slash commands
├── apps/
│   └── mobile/        # Flutter app
├── packages/          # Shared Dart packages (empty for now)
├── tools/             # Repo scripts
└── .github/
    └── workflows/     # CI/CD
```

All Flutter commands run from `apps/mobile/`:
- `flutter run`
- `flutter test`
- `dart run build_runner build --delete-conflicting-outputs`
- `flutter analyze`

## Riverpod codegen rules
- Every provider uses `@riverpod` annotation.
- Run `dart run build_runner build --delete-conflicting-outputs` after
  any provider change to regenerate `*.g.dart` files.
- Never edit `*.g.dart` files manually.
- Provider files always have `part 'filename.g.dart';` at the top.
- `AsyncNotifier` for async state with mutations.
- `@riverpod` for simple computed/stream providers.

## Auth flow
- University email only. Allowed domains: `kmutt.ac.th`,
  `mail.kmutt.ac.th`.
- Domain check lives in `apps/mobile/lib/core/constants/auth_constants.dart`.
- After signup, Firebase sends an email verification link.
- Unverified users redirected to `/verify-email` by GoRouter guard.
- All other routes require both signed-in AND email-verified.
- `gmail.com` is allowed as a dev-only exception — remove before launch.

## Core features
1. **Auth** — KMUTT email + Firebase email verification gate.
2. **Sessions** — host creates/edits/deletes/ends; public (host
   approval required) or private (password-join).
3. **Friends** — bidirectional. Both Friend docs written atomically via
   `WriteBatch`. Live status via `watchFriendshipStatus`.
4. **Chat** — DM (friends only, 1-on-1) + Group (session members).
5. **Calendar** — view your sessions in week/month view.
6. **Filters** — search sessions by subject, student year, academic level.
7. **Ratings** — thumbs-up rating between session members after session ends.
   Immutable. Doc ID: `{sessionId}_{raterId}_{ratedUserId}`.

## Data layer rules
- All Firestore reads/writes go through `apps/mobile/lib/data/`.
- Domain entities are plain Dart classes — no Firestore types.
- Data models (`lib/data/models/`) have `fromFirestore` / `toFirestore`.
- Enums always have a safe `fromString` with fallback default (never throw).
- Denormalized fields must be updated together via batch writes.
- Friend / friendship operations always write both sides atomically.

## Conventions
- **Naming:** snake_case files, PascalCase classes, camelCase vars.
- **Errors:** custom exceptions in `lib/core/errors/`. Never throw raw strings.
- **Constants:** Firestore collection names in `lib/core/constants/`.
- **No `print()`** — use `debugPrint` for dev logs.
- **No PII in logs** — never log emails, passwords, session passwords.
- **Crashlytics:** all uncaught errors flow through Crashlytics.
  Use `FirebaseCrashlytics.instance.recordError()` for caught errors.
- **Feature flags:** Firebase Remote Config. Gate new features behind
  a flag with a documented rollback plan in `docs/feature-flags.md`.

## Security
- Never commit Firebase service account JSON or `.env` files.
- Session passwords hashed with SHA-256 + per-session salt.
- Storage rules: size + content-type limits, owner-only write.
- Firestore rules: granular RBAC using `diff().affectedKeys()`,
  role-based access, server-side timestamp validation.

## Testing
- Unit tests: `test/unit/` — domain entities, use cases, pure logic.
- Repository tests: `test/repositories/` — using `fake_cloud_firestore`.
- Widget tests: `test/widgets/` — all screens have at least one.
- Integration tests: `integration_test/` — Android and Web.
- Run: `cd apps/mobile && flutter test`

## Do-not-do list
- Never hand-write Riverpod providers — always use `@riverpod`.
- Never import Firebase/Firestore in `lib/domain/`.
- Never call Firestore directly from screens, widgets, or providers.
- Never use `print()` — use `debugPrint`.
- Never log emails, passwords, UIDs, or session passwords.
- Never commit `.env`, service account JSON, or signing keys.
- Never throw raw strings — use custom exceptions from `lib/core/errors/`.
- Never edit `*.g.dart` or `*.freezed.dart` files manually.
- Never add new state management libraries — Riverpod 2.x only.
- Never add Freezed — plain Dart classes only.
- Never use unbounded `pumpAndSettle()` in tests.
- Never self-approve: the agent that writes code never reviews it.

## Agent team
Agent definitions in `.claude/agents/`. See each file for full scope.

Writers: architect, flutter-engineer, firebase-specialist, qa-engineer, docs-writer
Reviewers: code-reviewer, security-reviewer, accessibility-auditor

## Workflows
- **Run:** `cd apps/mobile && flutter run`
- **Test:** `cd apps/mobile && flutter test`
- **Analyze:** `cd apps/mobile && flutter analyze`
- **Format:** `cd apps/mobile && dart format .`
- **Codegen:** `cd apps/mobile && dart run build_runner build --delete-conflicting-outputs`

## Do not edit
- `apps/mobile/lib/firebase_options.dart` (auto-generated).
- `**/*.g.dart`, `**/*.freezed.dart` (regenerate via codegen).
- `android/app/build/**`, `ios/Pods/**`, `.dart_tool/`, `build/`.