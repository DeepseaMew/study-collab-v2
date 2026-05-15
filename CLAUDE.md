# Study Collab — house rules

## Project overview
Study Collab is a cross-platform mobile app (iOS, Android, Web) for KMUTT
students to find peers for study sessions.

## Repo structure
```
.
├── CLAUDE.md
├── .claude/
│   ├── settings.json
│   ├── agents/          ← architect, flutter-engineer, qa-engineer, security-reviewer, release-engineer
│   └── commands/        ← /new-feature, /pr-review, /qa-sweep, /release
├── apps/
│   └── mobile/          ← Flutter app (run all flutter commands from here)
│       ├── lib/
│       ├── test/
│       ├── integration_test/
│       ├── android/
│       └── ios/
├── packages/            ← shared Dart packages (design system, auth, networking)
├── tools/               ← repo scripts (codegen, release)
└── docs/
    ├── decisions/        ← Architecture Decision Records (ADRs)
    ├── audit/            ← structured reviewer audit reports
    │   └── evidence/     ← screenshots, Crashlytics dashboard, golden images
    └── runbooks/         ← release.md and operational guides
```


## Stack
| Concern | Package |
|---|---|
| State | flutter_riverpod + riverpod_generator |
| Navigation | go_router |
| Images | cached_network_image |
| Secrets | flutter_secure_storage |
| Models | freezed + json_serializable |
| Auth | Firebase Authentication |
| Database | Cloud Firestore |
| Observability | Firebase Crashlytics + lib/core/logger.dart |

## Architecture
Feature-first Clean Architecture. Each feature folder contains domain/, data/, presentation/.

```
apps/mobile/lib/
  features/<name>/
    data/
      datasources/     ← Firestore calls, DTOs
      models/          ← Freezed models with JSON serialization
      repositories/    ← implements domain interfaces
    domain/
      entities/        ← pure Dart classes, zero Flutter or Firebase imports
      repositories/    ← abstract interfaces
      usecases/        ← single-responsibility use case classes
    presentation/
      providers/       ← Riverpod providers (@riverpod code gen)
      screens/         ← GoRouter screen widgets
      widgets/         ← feature-scoped reusable widgets
  shared/
    widgets/           ← app-wide reusable components
    theme/             ← ThemeData, typography, color tokens
  core/
    errors/            ← sealed error classes
    logger.dart        ← structured logging, only call site in codebase
    analytics_events.dart ← all analytics events declared here
```

Every architecture decision is recorded in docs/decisions/.
Flutter Engineer must read the relevant decision record before implementing any feature.
A human must set Status to Accepted in the decision record before implementation starts.

## Features
### Auth
- KMUTT email domain gate: @mail.kmutt.ac.th and @kmutt.ac.th only.
- Email verification required before accessing any feature.
- Session persistence via flutter_secure_storage.

### Sessions
- Host creates, edits, deletes, and ends sessions.
- Two visibility types: public (anyone can request to join, host approves)
  and private (PIN or invite code required, host still approves).
- A session belongs to exactly one host; host role is scoped to that session only.

### Friends
- Users can send, accept, decline friend requests, and unfriend.
- Friendship is bidirectional; both users must agree.

### Chat
- DM: one-on-one, available between friends only.
- Group chat: session members only, created from a session, not standalone.
- Message history persists; users see previous messages on reopen.

### Search and filtering
- Search sessions by session name, hashtag, academic level, and student year.
- Hashtags are free-text typed by the host, stored as List<String>, lowercase.
- Search is online-only; no offline support.

### Rating
- Thumbs-up rating between session members after a session ends.
- Profile score calculated as percentage of thumbs-up across all sessions.
- Rating is only available after the host ends the session.
- Rating is online-only; requires server-side timestamp validation.
- 
## Agents
Role-scoped agents live in .claude/agents/. Specify which agent is active at the start of every session.

- architect — system design, schema, ADRs, review only. Cannot write feature code.
- flutter-engineer — implements all three layers (domain, data, presentation). Does not approve own work.
- qa-engineer — owns test matrix, accessibility sweeps, performance checks. Does not write feature code.
- security-reviewer — audits auth flows, Firestore rules, secrets. Read-only.
- release-engineer — owns CI/CD pipeline, changelog, tag cutting.

The agent that writes code must not be the agent that approves it.

## Planning workflow
Every non-trivial feature follows this pipeline before any code is written:

1. **Architect** writes a decision record to docs/decisions/NNNN-slug.md using docs/decisions/_template.md.
2. A human reads the record, fills the Human Approval section, and sets Status to Accepted.
3. **Flutter Engineer** implements strictly following the approved decisions. No scope creep beyond what the spec describes.
4. Submit for review to **architect** or **qa-engineer** — never the same agent that wrote the code. Reviewer checks implementation against the decisions.
5. For any task spanning more than 2 files or touching architecture, use Plan Mode first.

Skip steps 1 and 2 only for changes touching a single file with no architectural impact.

## Do not edit
- `**/*.g.dart` — Riverpod/JSON codegen output
- `**/*.freezed.dart` — Freezed model codegen output
- `**/generated_plugin_registrant.*` — Flutter plugin registry
- `apps/mobile/android/app/build/**` — Android build artifacts
- `apps/mobile/ios/Pods/**` — CocoaPods dependencies
- `docs/decisions/` — Architect writes, human approves, no one else edits
- `docs/audit/evidence/` — screenshots and logs only, no code

To regenerate: `dart run build_runner build --delete-conflicting-outputs`

## Conventions

### Imports
- Always use package imports (`package:mobile/...`) — never relative imports (`../../`).
- Enforced by `always_use_package_imports` lint; run `dart fix --apply` to fix violations.

### Errors
- Domain errors are sealed classes in `lib/core/errors/`; never throw strings.

### Logging
- All log calls go through `lib/core/logger.dart` only; never use `print()`.
- Log levels: debug, info, warning, error. Use the correct level.
- No PII in any log output or Crashlytics custom keys.

### Data
- KMUTT email gate enforced at Firebase Auth level and in Firestore rules.
- Hashtags stored as `List<String>` on session documents, free-text, lowercase.
- No unbounded `ListView` — always `ListView.builder` with `itemCount` or paginated.
- All remote images through `cached_network_image`; never `Image.network` directly.

### Models
- Freezed + json_serializable for all models; never hand-roll `toJson`/`fromJson`.

### Analytics
- Every event declared in `lib/core/analytics_events.dart` before use.

## RBAC roles
Two roles: student (default) and host (any user who creates a session).
Role stored in `users/{uid}.role`. Firestore rules enforce role checks on all
write operations. KMUTT domain validated server-side in Firestore rules.

## Security expectations
- No secrets or API keys in source; Firebase config injected via CI environment only.
- No PII in logs, Crashlytics keys, or analytics events.
- Firestore rules must use `diff().affectedKeys()` for field-level write validation.
- Firestore rules must use `request.time` for all timestamp fields.
- Users can only read and write their own documents unless role explicitly permits otherwise.
- Crashlytics must catch all Flutter errors via `FlutterError.onError` and
  `PlatformDispatcher.instance.onError`.
- A deliberate debug-only test crash must exist to verify Crashlytics receives data.
- TLS enforced by Firebase SDK; never disable certificate validation.
- `flutter_secure_storage` for any token or sensitive value that must persist locally.