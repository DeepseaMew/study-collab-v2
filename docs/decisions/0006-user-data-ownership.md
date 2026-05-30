# 0006 — User Data Ownership: Single Source of Truth for `users/{uid}`

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-05-20 |
| Architect session | claude-sonnet-4-6 / DeepseaMew / 2026-05-20 |
| Affects | Auth (presentation/providers), Profile (data, domain, presentation), core/firestore_paths.dart, ADR 0002 provider dependency graph |

---

## Team approval
 
Approved by: DeepseaMew
Date: 2026-05-20
Notes:

---

## Problem

Two concurrent Firestore snapshot listeners are opened on `users/{uid}` for every authenticated session. Path A is `current_user_provider.dart` in the auth feature: a `StreamProvider` that imports both `firebase_auth` and `cloud_firestore` directly in the presentation layer, hand-maps raw Firestore fields to `UserEntity` with string literals, and bypasses `ProfileDatasource`, `UserModel`, and `UserRepositoryImpl` entirely. Path B is `user_provider.dart` in the profile feature: a conforming Clean Architecture path through `ProfileDatasource` → `UserRepositoryImpl` → `user(uid)`. Schema changes to `users/{uid}` require updates in both the hand-rolled mapping in Path A and the Freezed `UserModel` in Path B. Neither path is the declared single source of truth. The duplicate listener also costs two Firestore reads per document change against the 50 k reads/day free-tier quota. Additionally, `current_user_provider.dart` imports `cloud_firestore` in a presentation-layer provider file, which is not covered by ADR 0002 Amendment 2 (that amendment named only `firebase_auth_state_provider.dart` as a second permitted `firebase_auth` site; it said nothing about `cloud_firestore` or any third file).

---

## Constraints

- Domain layer has zero Flutter or Firebase imports.
- Repository interfaces live in `domain/repositories/`; implementations live in `data/repositories/`.
- Entities use Freezed; use cases are plain Dart classes.
- Business logic must not be defined in the presentation layer.
- The only permitted `firebase_auth` import sites in the entire codebase are (per ADR 0002 Amendment 2): `auth_datasource.dart` and `firebase_auth_state_provider.dart`. No third site may be introduced.
- `cloud_firestore` imports are permitted only in datasource files inside `data/datasources/`.
- Any change to the provider dependency graph documented in ADR 0002 must be recorded in an amendment to that ADR.
- Firestore reads must not be duplicated for the same document path within a single authenticated session.
- All schema mapping for `users/{uid}` must go through `UserModel` (Freezed + json_serializable); no hand-rolled field mapping is permitted anywhere in the codebase.

---

## Options considered

### Sub-decision 1 — Which feature owns the `users/{uid}` stream and `UserEntity` mapping?

| | Option A: Auth-owns | Option B: Profile-owns | Option C: Shared/core layer |
|---|---|---|---|
| Summary | Auth feature's `AuthStateNotifier` delegates `users/{uid}` streaming to `UserRepositoryImpl` as a collaborator; auth retains a `currentUserProvider`. | Remove `current_user_provider.dart`; all consumers call `user(uid)` from the profile feature, supplying uid from `firebaseAuthStateProvider`. | Move `UserRepository`, `UserRepositoryImpl`, `ProfileDatasource`, and `UserModel` to `lib/core/` or `lib/shared/`; both features import from there. |
| Firestore listener count | One (routed through data layer) | One (routed through data layer) | One (routed through data layer) |
| Cross-feature imports | Auth imports `profile/domain/repositories/user_repository.dart` — a permanent cross-feature data dependency. | Auth imports nothing new. Profile already owns the path. Auth presentation reads uid from the already-permitted `firebaseAuthStateProvider`. | Neither feature imports the other. New `lib/core/` or `lib/shared/` surface must be maintained. |
| Schema change surface | `UserModel` only (Path A hand-roll is gone, replaced by the repository delegation). | `UserModel` only. | `UserModel` only. |
| Files deleted | `current_user_provider.dart` mapping replaced; `AuthRepositoryImpl` gains a collaborator parameter. | `current_user_provider.dart` deleted entirely. `user_provider.dart` and `ProfileDatasource` unchanged. | All profile data/domain files move to `lib/core/`; all import paths across every feature change; codegen must fully re-run. |
| Reversal cost | Medium — removing the collaborator from `AuthRepositoryImpl` requires unwinding the injected dependency across providers. | Low — adding a `currentUserProvider` wrapper in auth (if ever needed) is a single additive file delegating to `user(uid)`. | High — files moved to `lib/core/` cannot easily be moved back without touching every consumer and re-running codegen. |
| Recommendation | Not chosen | **Chosen** | Not chosen |

Option B is chosen. The profile feature already owns a fully conforming data path for `users/{uid}`. Eliminating `current_user_provider.dart` and routing all `UserEntity` consumers to `user(uid)` costs no new files and introduces no cross-feature data-layer dependency. Option A creates a permanent structural coupling between auth and the profile data layer that future engineers will find surprising. Option C solves a problem that does not exist once Option B removes the duplicate path, at a high reversal cost.

---

## Decision

The profile feature is the single source of truth for `users/{uid}` document streaming and `UserEntity` mapping. `current_user_provider.dart` in the auth feature is deleted. Every provider that previously watched `currentUserProvider` for the signed-in user's full `UserEntity` instead watches `user(uid)` from `user_provider.dart`, where `uid` is obtained from `ref.watch(firebaseAuthStateProvider)` — the already-permitted auth stream. `AuthStateNotifier` is not affected: it determines `pendingProfileSetup` via `authRepository.getAuthState()` which reads the Firestore document through `AuthRepositoryImpl` (a one-time fetch, not a stream). The `userProfile` helper inside `auth_state_notifier_provider.dart` (a `Future`-returning provider that also bypasses the data layer) is likewise removed and replaced by the `user(uid)` stream wherever profile fields are needed in the auth flow. No presentation-layer provider may import `cloud_firestore` or open a Firestore listener directly; all Firestore access flows through a datasource class in `data/datasources/`.

---

## Consequences

- `apps/mobile/lib/features/auth/presentation/providers/current_user_provider.dart` — **deleted**. The `userProfile` `Future` provider inside `auth_state_notifier_provider.dart` is **deleted** at the same time.
- All call sites of `currentUserProvider` across screens and widgets are updated to `ref.watch(userProvider(uid))` where `uid = ref.watch(firebaseAuthStateProvider).value?.uid`.
- `apps/mobile/lib/features/profile/presentation/providers/user_provider.dart` — no changes required; `user(uid)` and `userRepository` providers are already correct.
- `apps/mobile/lib/features/profile/data/datasources/profile_datasource.dart` — no changes required; this becomes the sole Firestore access point for `users/{uid}`.
- `apps/mobile/lib/features/profile/data/repositories/user_repository_impl.dart` — no changes required.
- `apps/mobile/lib/features/profile/domain/repositories/user_repository.dart` — no changes required.
- `apps/mobile/lib/features/auth/domain/entities/user_entity.dart` — no changes required; `UserEntity` remains the shared domain entity consumed by both auth and profile features.
- ADR 0002 must be amended (Amendment 3) to reflect the corrected provider dependency graph: `currentUserProvider` is removed from the graph; `user(uid)` from the profile feature is named as the canonical provider for signed-in user profile data; the prohibition on `cloud_firestore` imports in presentation-layer providers is made explicit.
- The Flutter Engineer must verify that no other file in `lib/` imports `cloud_firestore` outside of a `data/datasources/` file; `dart fix --apply` does not catch this — a manual grep is required before the PR is opened.
- No new analytics events are required by this decision.
- No Firestore rules changes are required.
- No schema changes are required.

---

## Reversal plan

If the team later determines that auth must own a dedicated `currentUserProvider` (for example, to add auth-scoped reactive behaviour that cannot be composed from `user(uid)`), the reversal is additive: create a new `current_user_provider.dart` in the auth feature that delegates to `ref.watch(userProvider(uid))` — it does not open a Firestore listener itself and does not import `cloud_firestore`. This file is a thin alias and does not reintroduce the dual-listener problem. The ADR 0002 amendment and this ADR would each receive a note recording the re-introduction. No data or domain layer files change on reversal.
