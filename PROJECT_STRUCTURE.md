# Project Structure — Study Collab V2

## Monorepo root

```
study_collab_v2/
├── CLAUDE.md                        # Project memory — read on every agent spawn
├── PROJECT_STRUCTURE.md             # This file
├── .claude/
│   ├── agents/                      # Agent definitions
│   │   ├── architect.md
│   │   ├── flutter-engineer.md
│   │   ├── firebase-specialist.md
│   │   ├── qa-engineer.md
│   │   ├── security-reviewer.md
│   │   ├── code-reviewer.md
│   │   ├── accessibility-auditor.md
│   │   └── docs-writer.md
│   ├── skills/                      # Reusable playbooks (future)
│   └── commands/                    # Slash commands (future)
├── apps/
│   └── mobile/                      # Flutter app — all Flutter commands run here
├── packages/                        # Shared Dart packages (empty — future use)
├── tools/                           # Repo scripts (empty — future use)
├── docs/
│   ├── adr/                         # Architecture Decision Records
    |── references/                  # Old project for reference only NOT IMPORT
│   └── feature-flags.md             # Feature flag registry + rollback plans
└── .github/
    └── workflows/
        └── ci.yml
```

## Flutter app — apps/mobile/

```
apps/mobile/
├── lib/
│   ├── core/                        # Shared across all layers
│   │   ├── constants/
│   │   │   ├── firestore_collections.dart   # Collection name constants
│   │   │   └── auth_constants.dart          # Allowed email domains
│   │   ├── errors/
│   │   │   └── app_exceptions.dart          # AppException, AuthException, DataException, etc.
│   │   ├── router/
│   │   │   └── app_router.dart              # GoRouter config + auth guards
│   │   ├── theme/
│   │   │   └── app_theme.dart               # Colors, text styles, theme data
│   │   └── utils/                           # Pure Dart helpers
│   │
│   ├── domain/                      # Pure Dart — ZERO Flutter/Firebase imports
│   │   ├── entities/                # Immutable plain Dart classes
│   │   │   ├── user.dart
│   │   │   ├── session.dart
│   │   │   ├── friend.dart
│   │   │   ├── chat_message.dart
│   │   │   ├── dm_conversation.dart
│   │   │   ├── group_conversation.dart
│   │   │   └── rating.dart
│   │   ├── repositories/            # Abstract interfaces — no implementations here
│   │   │   ├── auth_repository.dart
│   │   │   ├── user_repository.dart
│   │   │   ├── session_repository.dart
│   │   │   ├── friend_repository.dart
│   │   │   ├── chat_repository.dart
│   │   │   └── rating_repository.dart
│   │   └── usecases/                # One class, one public method, one responsibility
│   │       ├── auth/
│   │       │   ├── sign_in_usecase.dart
│   │       │   ├── sign_up_usecase.dart
│   │       │   └── sign_out_usecase.dart
│   │       ├── sessions/
│   │       │   ├── create_session_usecase.dart
│   │       │   ├── join_session_usecase.dart
│   │       │   └── end_session_usecase.dart
│   │       ├── friends/
│   │       │   ├── send_request_usecase.dart
│   │       │   └── accept_request_usecase.dart
│   │       └── chat/
│   │           └── send_message_usecase.dart
│   │
│   ├── data/                        # Firebase implementation
│   │   ├── models/                  # DTOs — fromFirestore/toFirestore only
│   │   │   ├── user_model.dart
│   │   │   ├── session_model.dart
│   │   │   ├── friend_model.dart
│   │   │   ├── chat_message_model.dart
│   │   │   └── rating_model.dart
│   │   ├── repositories/            # Concrete implementations of domain interfaces
│   │   │   ├── auth_repository_impl.dart
│   │   │   ├── user_repository_impl.dart
│   │   │   ├── session_repository_impl.dart
│   │   │   ├── friend_repository_impl.dart
│   │   │   ├── chat_repository_impl.dart
│   │   │   └── rating_repository_impl.dart
│   │   └── datasources/             # Raw Firestore/Storage calls
│   │       ├── auth_datasource.dart
│   │       ├── firestore_datasource.dart
│   │       └── storage_datasource.dart
│   │
│   ├── presentation/                # UI + Riverpod providers
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   │   ├── providers/       # @riverpod providers
│   │   │   │   ├── screens/
│   │   │   │   └── widgets/
│   │   │   ├── sessions/
│   │   │   │   ├── providers/
│   │   │   │   ├── screens/
│   │   │   │   └── widgets/
│   │   │   ├── friends/
│   │   │   │   ├── providers/
│   │   │   │   ├── screens/
│   │   │   │   └── widgets/
│   │   │   ├── chat/
│   │   │   │   ├── providers/
│   │   │   │   ├── screens/
│   │   │   │   └── widgets/
│   │   │   ├── calendar/
│   │   │   │   ├── providers/
│   │   │   │   ├── screens/
│   │   │   │   └── widgets/
│   │   │   └── profile/
│   │   │       ├── providers/
│   │   │       ├── screens/
│   │   │       └── widgets/
│   │   └── shared/
│   │       └── widgets/             # Reusable UI components
│   │
│   ├── firebase_options.dart        # Auto-generated — do not edit
│   └── main.dart                    # App entry point + Firebase init + Crashlytics
│
├── test/
│   ├── unit/                        # Domain entity + use case tests (no Firebase)
│   ├── repositories/                # Data repository tests (fake_cloud_firestore)
│   └── widgets/                     # Widget tests (ProviderScope overrides)
│
├── integration_test/                # End-to-end tests — Android + Web
│
├── android/
├── web/
├── pubspec.yaml
└── .gitignore
```

## Dependency rules (enforced by code-reviewer)

```
presentation/ → domain/ ← data/
```

| Layer | Can import | Cannot import |
|-------|-----------|---------------|
| domain/entities/ | nothing (pure Dart) | flutter, firebase_*, cloud_firestore |
| domain/repositories/ | domain/entities/ | data/, presentation/, firebase_* |
| domain/usecases/ | domain/entities/, domain/repositories/ | data/, presentation/, firebase_* |
| data/models/ | domain/entities/, cloud_firestore | presentation/ |
| data/repositories/ | domain/repositories/, data/models/, data/datasources/ | presentation/ |
| data/datasources/ | cloud_firestore, firebase_* | domain/, presentation/ |
| presentation/ | domain/entities/, domain/usecases/, flutter_riverpod | data/, cloud_firestore |

## Provider naming convention

All providers use `@riverpod` codegen. File must have `part 'filename.g.dart';`.

| Type | Example |
|------|---------|
| Stream provider | `@riverpod Stream<List<Session>> userSessions(UserSessionsRef ref)` |
| Future provider | `@riverpod Future<User> currentUser(CurrentUserRef ref)` |
| Notifier | `@riverpod class SessionNotifier extends _$SessionNotifier` |
| Family | `@riverpod Stream<Session> session(SessionRef ref, String id)` |

## Feature flag pattern

Feature flags live in Firebase Remote Config. New features are gated:

```dart
// In presentation layer
final flagValue = ref.watch(remoteConfigProvider).getBool('file_sharing_enabled');
if (!flagValue) return const ComingSoonWidget();
```

Rollback plan for each flag documented in `docs/feature-flags.md`.

## Crashlytics pattern

All uncaught errors wired in `main.dart`. Caught errors:

```dart
try {
  await useCase.execute();
} catch (e, stack) {
  FirebaseCrashlytics.instance.recordError(e, stack, reason: 'context');
  rethrow;
}
```

Never log PII. Never log passwords, emails, or UIDs in error messages.