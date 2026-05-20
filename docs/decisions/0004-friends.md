# 0004 — Friends Feature Architecture

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-05-19 |
| Architect session | claude-sonnet-4-6 / DeepseaMew / 2026-05-19 |
| Affects | Friends, Chat (DM creation gate), Profile (others'), Rating (post-session), domain/entities, data/datasources, presentation/providers, firestore.rules, lib/core/analytics_events.dart |

---

## Team approval

Approved by: DeepseaMew
Date: 2026-05-19
Notes:

---

## Problem

The Friends feature spans send/accept/decline/unfriend actions that simultaneously mutate documents in two separate users' subcollections and gates DM creation for the Chat feature. Without a single authoritative record, Flutter Engineers will produce inconsistent atomic write patterns (breaking bidirectionality), implement rule checks that diverge from the ADR 0001 `areFriends` helper, and create divergent UI states for pending-inbox vs. accepted-friend views. Friends is a hard dependency for Profile (others' view), DM Chat (creation gate), and Rating (post-session thumbs-up between session members); this ADR must be accepted before any of those features begin implementation.

---

## Constraints

- Domain layer has zero Flutter or Firebase imports; all Firestore path strings are constants in `lib/core/firestore_paths.dart` only.
- Repository interfaces in `domain/repositories/`; implementations in `data/repositories/`; no Firestore types cross this boundary.
- Entities use Freezed; datasource models use Freezed + json_serializable.
- Business logic must not be defined in the presentation layer.
- All Riverpod providers use `@riverpod` codegen (riverpod_generator); no hand-written `StateNotifier`.
- No provider may access Firestore directly; all Firestore access goes through the repository layer.
- ADR 0001 already defines `users/{uid}/friends/{friendUid}` schema with fields: `friendUid` (String), `status` (String enum: `pending` | `accepted`), `initiatorUid` (String), `createdAt` (Timestamp), `updatedAt` (Timestamp).
- Friendship is bidirectional; both friend documents must be written and deleted atomically via `WriteBatch` (ADR 0001).
- DM creation requires `users/{A}/friends/{B}.status == 'accepted'` AND `users/{B}/friends/{A}.status == 'accepted'`, enforced in Firestore rules via the `areFriends` helper (ADR 0001).
- Firestore rules must use `diff().affectedKeys()` for field-level write validation (ADR 0001).
- All timestamp fields written server-side via `request.time`; no client-generated timestamp may bypass this (ADR 0001).
- KMUTT email gate (`@mail.kmutt.ac.th` / `@kmutt.ac.th`) enforced in Firestore rules via `isKmuttUser()` (ADR 0001).
- Users may only read their own friend subcollection or documents where they are the `friendUid` (ADR 0001).
- Every analytics event declared in `lib/core/analytics_events.dart` before use.
- No PII in logs, Crashlytics keys, or analytics events.
- Target platforms: Android and Web only.

---

## Options considered

### Sub-decision 1 — Friend list query and stream strategy

| | Option A | Option B | Option C |
|---|---|---|---|
| Summary | Stream `users/{uid}/friends` where `status == 'accepted'`; resolve display names via N+1 reads on `users/{friendUid}` | Stream `users/{uid}/friends` where `status == 'accepted'`; store denormalized `friendDisplayName` and `friendPhotoUrl` on each friend document at accept time | Top-level `friends` collection with both UIDs for collection-group queries |
| Read cost | High: one Firestore read per friend per list render when display names or photos are needed | Low: all data in one subcollection stream; no secondary reads for list rendering | Medium: fewer secondary reads but queries require composite indexes on the top-level collection; fan-out on status update is complex |
| Offline support | Degraded: if `users/{friendUid}` documents are not cached, display names are unavailable offline | Full: the friend subcollection document carries all display fields; renders correctly offline | Partial: collection-group queries are harder to cache predictably; offline support is unreliable |
| Write complexity | Low at accept time: only update `status` and `updatedAt` on both documents | Medium at accept time: write `friendDisplayName` and `friendPhotoUrl` alongside status update in the batch; display name staleness if friend updates their profile later | High: a top-level collection breaks the security-rule path inheritance established in ADR 0001 and requires re-specifying `areFriends` |
| Reversal cost | Low: add denormalized fields later by amending friend documents in a migration; no domain entity changes | Medium: if display name staleness becomes unacceptable, a sync mechanism (Cloud Function or client-side batch) is needed; `FriendEntity` interface is unchanged | High: migrating from a top-level collection back to subcollections requires a data migration and full rules rewrite; DM creation gate changes |
| Recommendation | Not recommended | Recommended | Not recommended |

Option B is recommended. Denormalizing `friendDisplayName` and `friendPhotoUrl` onto each friend document at accept time eliminates N+1 reads for the friend list screen and ensures the list renders correctly when offline. This is consistent with the denormalization pattern already established in ADR 0001 for `hostDisplayName` and `hostPhotoUrl` on session documents. Display name staleness is acceptable at MVP because profile editing is listed under "Planned in the future" in CLAUDE.md.

---

### Sub-decision 2 — Pending requests: inbox vs. subcollection polling

| | Option A | Option B |
|---|---|---|
| Summary | Query `users/{uid}/friends` where `status == 'pending'` and `initiatorUid != uid`; render as a pending-requests list in the same subcollection | Separate top-level `pendingRequests` collection for easier querying |
| Read cost | Low: single filtered stream on the existing subcollection; no additional document reads | Low: single collection stream, but requires a separate security-rules block and a new top-level path |
| Offline support | Full: the subcollection is already cached by the friend list stream; no separate collection to warm | Partial: requires a separate offline cache entry for the top-level collection |
| Write complexity | Low: the send-request batch already writes `status == 'pending'` to both documents (ADR 0001); no additional write path | High: send-request must write to both the subcollection AND the top-level collection; accept/decline/unfriend must clean up both paths atomically |
| Reversal cost | Low: query can be replaced with a separate collection by changing only the datasource; subcollection schema is unchanged | High: migrating away requires deleting the top-level collection, updating all write paths, and amending Firestore rules and indexes |
| Recommendation | Recommended | Not recommended |

Option A is recommended. The `users/{uid}/friends` subcollection is already the authoritative source for friendship state (ADR 0001); filtering by `status == 'pending'` and `initiatorUid != uid` on the recipient's subcollection is a single Firestore query that reuses the existing schema and rules block without introducing a second write path or a new top-level collection. Option B contradicts ADR 0001's subcollection-first design and doubles the atomic write surface.

---

### Sub-decision 3 — Unfriend and decline atomicity

| | Option A | Option B |
|---|---|---|
| Summary | `WriteBatch` with two deletes; datasource owns the batch and issues both deletes atomically | Cloud Function triggered on delete; client deletes only one side and the function mirrors the deletion on the other |
| Read cost | None: both document paths are known at call time | None: Cloud Function reads the document paths from the triggering event |
| Offline support | Supported: `WriteBatch` is queued and flushed when the device reconnects | Not supported offline: Cloud Functions are not available on the Spark (free) plan and cannot be triggered from an offline device |
| Write complexity | Low: datasource constructs a batch with two `batch.delete(...)` calls; consistent with the send-request batch pattern already specified in ADR 0001 | High: Cloud Functions are not available on the Firebase Spark plan (CLAUDE.md restricts to free-tier services); adds infrastructure complexity and deployment surface |
| Reversal cost | Low: the batch can be split into two sequential writes if the consistency requirement changes; no infrastructure changes | High: decommissioning a Cloud Function requires infrastructure changes, a deployment pipeline step, and a rules amendment |
| Recommendation | Recommended | Not recommended |

Option A is recommended. `WriteBatch` with two deletes is consistent with the atomic send-request pattern mandated by ADR 0001, requires no Cloud Functions infrastructure (which is unavailable on the Spark plan), and ensures both sides of the bidirectional friendship are deleted atomically in a single SDK call. Option B is ruled out because Cloud Functions are not available on the Firebase Spark free tier.

---

## Decision

The Friends feature uses three coordinated decisions. For friend list display (sub-decision 1), `friendDisplayName` and `friendPhotoUrl` are denormalized onto each `users/{uid}/friends/{friendUid}` document at accept time so the list renders from a single subcollection stream without N+1 reads and works offline; staleness on display name change is acceptable at MVP. For pending-request inbox (sub-decision 2), the existing `users/{uid}/friends` subcollection is queried with `status == 'pending'` and `initiatorUid != uid` on the recipient, reusing the ADR 0001 schema and rules block without a second write path or top-level collection. For unfriend and decline atomicity (sub-decision 3), the datasource constructs a `WriteBatch` with two deletes — one per side of the bidirectional friendship — consistent with the ADR 0001 send-request batch pattern and without Cloud Functions, which are unavailable on the Spark plan.

---

## Consequences

- `FriendEntity` (Freezed) must include `friendUid`, `status`, `initiatorUid`, `createdAt`, `updatedAt`, plus the two denormalized display fields `friendDisplayName` (String, required) and `friendPhotoUrl` (String?, nullable).
- `FriendModel` (Freezed + json_serializable) mirrors `FriendEntity` with `toJson`/`fromJson` for Firestore serialization.
- `FriendsDatasource` constructs all `WriteBatch` operations; the repository implementation must not call Firestore directly.
- The send-request batch writes `status == 'pending'` on both documents (ADR 0001); `friendDisplayName` and `friendPhotoUrl` are NOT yet written — they are populated only when the accept-request batch is committed.
- The accept-request batch updates `status = 'accepted'` and `updatedAt = request.time` on both documents AND writes `friendDisplayName` and `friendPhotoUrl` on each side (initiator's doc gets the recipient's display data; recipient's doc gets the initiator's display data). Both users' `users/{uid}` documents must be read once in the repository implementation to source the display fields before the batch is committed.
- The decline-request batch deletes both pending documents atomically.
- The unfriend batch deletes both accepted documents atomically.
- Firestore rules for `users/{uid}/friends/{friendUid}` (ADR 0001) require two amendments: (1) the `create` rule must be tightened to permit only `status == 'pending'` and only the five base fields (`friendUid`, `status`, `initiatorUid`, `createdAt`, `updatedAt`) at creation time — `friendDisplayName` and `friendPhotoUrl` are absent on create and added on accept; (2) the `update` rule must be extended to permit `friendDisplayName` and `friendPhotoUrl` in `affectedKeys().hasOnly(...)` so that the accept batch can write both display fields alongside the status change.
- The `areFriends` helper function in `firestore.rules` (ADR 0001) is already correct and needs no changes.
- No new composite indexes are required beyond the nine already defined in ADR 0001. The pending-inbox query (`status == 'pending'`, `initiatorUid != uid`) operates on a per-user subcollection whose cardinality is bounded; Firestore handles this without a composite index because `status` is the only equality filter and the result set is small.
- Analytics events `friend_request_sent`, `friend_request_accepted`, `friend_request_declined`, `friend_request_withdrawn`, and `friend_unfriended` must be declared in `lib/core/analytics_events.dart` before use.
- The `FriendRepository` interface in the domain layer must expose no Firestore types; all write operations accept plain Dart values only.
- The presentation layer must not construct or commit `WriteBatch` objects; all batch logic lives in `FriendsDatasource`.
- DM Chat and Profile (others') features are blocked until this ADR is Accepted.

---

## Firestore rules amendments

The existing `users/{uid}/friends/{friendUid}` rules block in ADR 0001 must be replaced with the following. The change tightens `create` to exclude display fields (which do not exist at request-send time) and extends `update` to permit `friendDisplayName` and `friendPhotoUrl` alongside `status` and `updatedAt` when the accept batch commits.

```
match /users/{uid}/friends/{friendUid} {
  allow read: if isKmuttUser()
    && (request.auth.uid == uid || request.auth.uid == friendUid);

  allow create: if isKmuttUser()
    && (request.auth.uid == uid || request.auth.uid == friendUid)
    && request.resource.data.friendUid == friendUid
    && request.resource.data.status == 'pending'
    && request.resource.data.createdAt == request.time
    && request.resource.data.updatedAt == request.time
    && request.resource.data.keys().hasAll([
         'friendUid', 'status', 'initiatorUid', 'createdAt', 'updatedAt'
       ])
    && request.resource.data.keys().hasOnly([
         'friendUid', 'status', 'initiatorUid', 'createdAt', 'updatedAt'
       ]);

  allow update: if isKmuttUser()
    && (request.auth.uid == uid || request.auth.uid == friendUid)
    && request.resource.data.diff(resource.data).affectedKeys()
         .hasOnly(['status', 'updatedAt', 'friendDisplayName', 'friendPhotoUrl'])
    && request.resource.data.updatedAt == request.time
    && request.resource.data.friendUid == resource.data.friendUid
    && request.resource.data.initiatorUid == resource.data.initiatorUid
    && request.resource.data.createdAt == resource.data.createdAt;

  allow delete: if isKmuttUser()
    && (request.auth.uid == uid || request.auth.uid == friendUid);
}
```

Key changes from ADR 0001 sketch:
- `create` now uses `hasOnly` to prohibit `friendDisplayName` and `friendPhotoUrl` at creation time, ensuring display fields can only arrive via the accept-request update.
- `update` `affectedKeys().hasOnly(...)` is extended with `'friendDisplayName'` and `'friendPhotoUrl'` to permit the accept batch to write both display fields.
- `update` adds immutability assertions for `friendUid`, `initiatorUid`, and `createdAt`.

---

## Composite indexes

No new composite indexes are required. All nine indexes defined in ADR 0001 remain sufficient. The friend list stream queries `users/{uid}/friends` with a single equality filter (`status == 'accepted'`); the pending-inbox stream queries with a single equality filter (`status == 'pending'`); both operate on a per-user subcollection and do not require a composite index in Firestore.

---

## Analytics events

Declare the following in `lib/core/analytics_events.dart` before any call site is written:

- `friend_request_sent` — no payload; no PII
- `friend_request_accepted` — no payload; no PII
- `friend_request_declined` — no payload; no PII
- `friend_request_withdrawn` — no payload; no PII
- `friend_unfriended` — no payload; no PII

---

## Full file list

**Domain:**
- `apps/mobile/lib/features/friends/domain/entities/friend_entity.dart` — Freezed entity: `friendUid`, `status`, `initiatorUid`, `createdAt`, `updatedAt`, `friendDisplayName`, `friendPhotoUrl`.
- `apps/mobile/lib/features/friends/domain/repositories/friends_repository.dart` — abstract interface:
  - `Stream<List<FriendEntity>> watchFriends(String uid)` — accepted friends only
  - `Stream<List<FriendEntity>> watchIncomingRequests(String uid)` — pending where `initiatorUid != uid`
  - `Stream<List<FriendEntity>> watchOutgoingRequests(String uid)` — pending where `initiatorUid == uid`
  - `Future<void> sendRequest(String currentUid, String targetUid)` — batch create both pending documents
  - `Future<void> acceptRequest(String currentUid, String initiatorUid)` — batch update both documents to accepted + write display fields
  - `Future<void> declineRequest(String currentUid, String initiatorUid)` — batch delete both pending documents
  - `Future<void> withdrawRequest(String currentUid, String targetUid)` — batch delete both pending documents (initiator withdraws)
  - `Future<void> unfriend(String currentUid, String friendUid)` — batch delete both accepted documents
- `apps/mobile/lib/features/friends/domain/usecases/send_friend_request_usecase.dart`
- `apps/mobile/lib/features/friends/domain/usecases/accept_friend_request_usecase.dart`
- `apps/mobile/lib/features/friends/domain/usecases/decline_friend_request_usecase.dart`
- `apps/mobile/lib/features/friends/domain/usecases/withdraw_friend_request_usecase.dart`
- `apps/mobile/lib/features/friends/domain/usecases/unfriend_usecase.dart`
- `apps/mobile/lib/features/friends/domain/usecases/watch_friends_usecase.dart`
- `apps/mobile/lib/features/friends/domain/usecases/watch_incoming_requests_usecase.dart`

**Data:**
- `apps/mobile/lib/features/friends/data/models/friend_model.dart` — Freezed + json_serializable; maps Firestore document to `FriendEntity`.
- `apps/mobile/lib/features/friends/data/datasources/friends_datasource.dart` — all Firestore reads and all `WriteBatch` construction; path strings from `lib/core/firestore_paths.dart` only.
- `apps/mobile/lib/features/friends/data/repositories/friends_repository_impl.dart` — reads `users/{uid}.displayName` and `users/{uid}.photoUrl` once per accept call to source denormalized display fields before committing the batch; no Firestore types exposed at the interface boundary.

**Presentation — providers:**
- `apps/mobile/lib/features/friends/presentation/providers/friends_provider.dart` — `@riverpod Stream<List<FriendEntity>> friends(String uid)`.
- `apps/mobile/lib/features/friends/presentation/providers/incoming_requests_provider.dart` — `@riverpod Stream<List<FriendEntity>> incomingRequests(String uid)`.
- `apps/mobile/lib/features/friends/presentation/providers/outgoing_requests_provider.dart` — `@riverpod Stream<List<FriendEntity>> outgoingRequests(String uid)`.
- `apps/mobile/lib/features/friends/presentation/providers/friend_action_provider.dart` — `@riverpod` async notifier exposing `sendRequest`, `acceptRequest`, `declineRequest`, `withdrawRequest`, `unfriend`; holds loading/error state per action.

**Presentation — screens:**
- `apps/mobile/lib/features/friends/presentation/screens/friends_screen.dart` — tabbed screen with two tabs: Friends (accepted list) and Requests (incoming + outgoing). Entry point from navigation.
- `apps/mobile/lib/features/friends/presentation/screens/friend_requests_screen.dart` — full incoming and outgoing requests list; navigated to from the Friends screen badge.

**Presentation — widgets:**
- `apps/mobile/lib/features/friends/presentation/widgets/friend_list_tile.dart` — renders `friendDisplayName`, `friendPhotoUrl` (via `cached_network_image` with initials fallback), and an unfriend action.
- `apps/mobile/lib/features/friends/presentation/widgets/friend_request_tile.dart` — renders sender display name and photo; accept and decline action buttons.
- `apps/mobile/lib/features/friends/presentation/widgets/add_friend_button.dart` — stateful button that switches among Send Request / Pending / Friends states; consumed by profile screens.

**Core path constants (amendment to existing file):**
- `apps/mobile/lib/core/firestore_paths.dart` — add:
  - `static String friendsCollection(String uid)` → `users/$uid/friends`
  - `static String friendDoc(String uid, String friendUid)` → `users/$uid/friends/$friendUid`

---

## Reversal plan

**Sub-decision 1 (denormalized display fields):** If display name staleness becomes unacceptable after the Profile Edit feature ships, amend ADR 0001 to permit `friendDisplayName` and `friendPhotoUrl` in an `update` batch triggered by profile edits. Steps: (a) write a new ADR covering the sync strategy; (b) update `users` update rule to trigger a client-side `WriteBatch` from `ProfileRepositoryImpl` that fans out display-name changes to all `users/{uid}/friends/{friendUid}` documents; (c) update `friends` update rule `affectedKeys` if needed. The `FriendEntity` interface and all presentation-layer code are unchanged.

**Sub-decision 2 (subcollection polling for pending inbox):** If the single-subcollection pending-inbox query proves insufficient (e.g., cross-user inbox aggregation is required for a notifications feature), introduce a top-level `notifications` collection in a separate ADR. Steps: (a) write the notifications ADR; (b) add a write to the notifications collection in the send-request batch inside `FriendsDatasource`; (c) add rules and indexes for the new collection. The friends subcollection schema and `FriendsDatasource` batch logic are unchanged except for the additional write.

**Sub-decision 3 (WriteBatch atomicity):** If the team migrates to a paid Firebase plan and wants server-side enforcement of bidirectional deletes, introduce a Cloud Function triggered on `users/{uid}/friends/{friendUid}` deletion. Steps: (a) write a Cloud Functions ADR; (b) deploy the mirror-delete function; (c) update `FriendsDatasource` to delete only the caller's side and rely on the function for the other. The domain entity, repository interface, and use case files are unchanged.
