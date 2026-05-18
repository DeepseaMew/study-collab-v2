# 0003 — Sessions Feature Architecture

| Field | Value |
|---|---|
| Status | Proposed |
| Date | 2026-05-18 |
| Architect session | claude-sonnet-4-6 / 2026-05-18 |
| Affects | Sessions, My Sessions, Dashboard (session_card), Firestore schema amendment (ADR 0001), firestore.indexes.json, firestore.rules, data/datasources, domain/entities, presentation/providers, core/router, shared/widgets |

---

## Team approval

Approved by: Eve
Date: 2026-05-18
Notes: -

---

## Problem

The Sessions feature spans two feature folders (`session/` and `my_sessions/`) and eight screens, and directly affects the Dashboard feature via a shared `session_card.dart` widget. Before a Flutter Engineer begins any file, the team needs authoritative answers to five questions. (1) How do three semantically distinct Firestore queries — sessions a user is joining soon, sessions a user has completed, and sessions a user is hosting — get served without creating unnecessary composite indexes, performing N+1 reads per card, or breaking offline persistence? (2) Where in Firestore are join requests stored? ADR 0001's `sessions/{sessionId}` schema defines no requests subcollection; without a decision, different engineers will pick incompatible paths. (3) Five fields required to render a session card (`location`, `scheduledEndAt`, `capacity`, `hostDisplayName`, `hostPhotoUrl`) are absent from the current ADR 0001 schema. The Flutter Engineer cannot begin until these are formally added and the rules amended. (4) Should host display data be denormalized at session creation or joined at read time? The choice determines whether the app works offline and whether session card rendering requires N+1 Firestore reads. (5) The feature has three conceptually distinct detail screens — a public pre-join view, a member view, and a host view — but it is unclear whether these should be separate screen files with separate routes or a single context-aware screen. Without a single record, Flutter Engineers will produce ad-hoc, divergent data access patterns, violate domain isolation, and likely break offline caching behavior.

---

## Constraints

- Domain layer has zero Flutter or Firebase imports; all Firestore path strings are constants in `lib/core/firestore_paths.dart` only.
- Repository interfaces in `domain/repositories/`; implementations in `data/repositories/`; no Firestore types cross this boundary.
- Entities use Freezed; datasource models use Freezed + json_serializable.
- Business logic must not be defined in the presentation layer.
- All Riverpod providers use `@riverpod` codegen (riverpod_generator); no hand-written `StateNotifier`.
- No provider may access Firestore directly; all Firestore access goes through the repository layer.
- Firestore rules must use `diff().affectedKeys()` for field-level write validation (ADR 0001).
- All timestamp fields written server-side via `request.time` (ADR 0001).
- Users may only read sessions they are a member of, or that are public (ADR 0001 rules).
- Session lists must be served from Firestore's offline persistence cache when offline; no custom caching code is permitted.
- Host name and photo must be available for session card display without N+1 Firestore reads.
- All remote images through `cached_network_image`; never `Image.network` directly.
- `session_card.dart` must live at `lib/shared/widgets/session_card.dart` so that the Dashboard feature can import it without a cross-feature dependency.
- `SessionEntity` must live at `lib/features/sessions/domain/entities/session_entity.dart` as the single shared entity used by Sessions, My Sessions, Calendar, and Dashboard.
- The `Subject` enum from the old codebase has no ADR 0001 equivalent; the session card renders `session.hashtags.firstOrNull ?? session.academicLevel` as the subject tag (plain text, no enum color).
- The detail screen pushed on card tap is determined solely by the source context (public list, Upcoming/Completed tab, or My Sessions tab), not by the current user's computed role on that session.
- Every analytics event declared in `lib/core/analytics_events.dart` before use.
- No PII in logs, Crashlytics keys, or analytics events.
- ADR 0001 must be amended to add the required fields and join-requests subcollection before any file in this feature is implemented. Flutter Engineer must not begin until Status is Accepted.

---

## Options considered

### Sub-decision 1 — Firestore query strategy for the three My Sessions tabs

#### Option A — Three separate stream providers; Upcoming uses client-side status filter

Three Riverpod auto-dispose stream providers, each wrapping its own Firestore stream through the repository:

- **Upcoming:** `sessions` where `memberUids array-contains uid`, ordered by `scheduledAt asc`. The repository implementation filters out documents where `status == 'ended'` in Dart before returning the list. Reuses Index 1 from ADR 0001 (`memberUids, scheduledAt asc`).
- **Completed:** `sessions` where `memberUids array-contains uid` and `status == 'ended'`, ordered by `endedAt desc`. Reuses Index 2 from ADR 0001 (`memberUids, status asc, endedAt desc`).
- **My Sessions:** `sessions` where `hostUid == uid`, ordered by `scheduledAt desc`. Requires one new composite index (Index 9: `hostUid asc, scheduledAt desc`).

The client-side filter for Upcoming is bounded to the user's own member sessions only; it is not an unbounded collection scan.

**Trade-offs**
- Pro: Completed reuses Index 2 and Upcoming reuses Index 1 — only one new index required.
- Pro: No `array-contains + whereIn` compound query; avoids Firebase SDK version compatibility concerns.
- Pro: Each stream reacts independently to session status changes in real time.
- Con: The Upcoming stream fetches `status == 'ended'` documents from Firestore and discards them client-side. For a user with many ended sessions this wastes read bandwidth on the Upcoming query. In practice, Index 1 orders by `scheduledAt asc`, so ended sessions accumulate at the front of the stream result; volume is small at MVP.
- Reversal cost: low — the client-side filter can be replaced with a Firestore `whereIn` clause by changing only the datasource file.

---

**Decision for sub-decision 1:** Option A. Reusing Index 1 and Index 2 from ADR 0001 minimises new index cost to one (vs. two for Option B). The client-side status filter for Upcoming is bounded to the user's own member sessions and is not a scalability concern at MVP. Option C is ruled out because `hostUid == uid` cannot be reliably inferred from `memberUids array-contains uid`.

---

### Sub-decision 2 — Join request storage

#### Option A — `sessions/{sessionId}/requests/{uid}` subcollection

Each join request is a separate document whose ID is the requesting user's UID. Fields: `uid` (String), `displayName` (String, denormalized), `photoUrl` (String?, denormalized), `requestedAt` (Timestamp). Approval removes the document and atomically adds `uid` to `memberUids` in a `WriteBatch`. Decline deletes the document. Firestore rules enforce that only the host may read the subcollection; the requesting user may write their own document if they are not already a member.

**Trade-offs**
- Pro: each request carries its own metadata (`requestedAt`, display fields) without parallel arrays.
- Pro: security rules can be expressed cleanly at the path level (`request.auth.uid == uid` for create; `isHost` for read/delete).
- Pro: listing, approving, and declining individual requests are all O(1) document operations.
- Pro: works fully offline — the cached subcollection carries all fields needed to render the request card.
- Con: adds one new subcollection path and one new rules block to ADR 0001.
- Reversal cost: low — the subcollection can be removed and replaced with an embedded array by changing only the datasource and rules files.

---

**Decision for sub-decision 2:** Option A. The subcollection cleanly carries per-request metadata required by the request card UI, supports atomic approve/decline operations, and is consistent with the subcollection nesting pattern established in ADR 0001. Option B is ruled out due to the privacy concern and the inability to carry per-request metadata without introducing parallel arrays.

---

### Sub-decision 3 — Host display data for session cards

#### Option A — Denormalize `hostDisplayName` and `hostPhotoUrl` onto the session document at creation time

`SessionRepositoryImpl` reads `users/{hostUid}.displayName` and `users/{hostUid}.photoUrl` once during session creation and writes them as `hostDisplayName` (String, required) and `hostPhotoUrl` (String?, nullable) on the session document. Both fields are immutable after creation, consistent with the existing `hostFaculty` denormalization in ADR 0001.

**Trade-offs**
- Pro: session card renders from a single document read; no N+1.
- Pro: works fully offline — the cached session document carries all fields needed to render a card.
- Pro: consistent with the `hostFaculty` denormalization pattern already in ADR 0001.
- Con: `hostDisplayName` becomes stale if the host updates their display name after session creation. Acceptable for MVP — profile edit is listed under "Planned in the future" in CLAUDE.md and is out of scope for this ADR.
- Con: `hostPhotoUrl` will be `null` for all sessions until a photo upload system is built; the avatar widget must gracefully fall back to initials. This is not a regression — the field is nullable and the initials fallback already exists in the session card design.
- Reversal cost: low — a sync mechanism (Cloud Function or client-side `WriteBatch`) can be added in a future ADR without changing the domain entity interface.

---

**Decision for sub-decision 3:** Option A. Denormalize `hostDisplayName` and `hostPhotoUrl` at session creation, consistent with `hostFaculty` in ADR 0001. This eliminates N+1 reads and ensures the session card renders correctly offline. Both fields are immutable after creation.

---

### Sub-decision 4 — Detail screen routing (three contexts)

#### Option A — Three separate screen files, route determined by source context

Three screen files with three distinct routes:
- `SessionDetailScreen` at `/sessions/:id` — public pre-join view, accessible from Search and Home. Shows session info, members preview, join action row (Request to Join / Join with PIN / Joined / Pending / Message Group).
- `MemberSessionDetailScreen` at `/my-sessions/session/:id/member` — post-join view for members. Two tabs: Members, Notes. Shows "Joined" status badge, auto-triggers rating sheet when session ends via `ref.listen`.
- `HostSessionDetailScreen` at `/my-sessions/session/:id/host` — host management view. Three tabs: Members, Notes, Requests. Shows "Hosting" badge, End Session button, approve/decline actions.

The source context determines which route is pushed: Upcoming/Completed tabs push the `/member` route; My Sessions tab pushes the `/host` route; public session list pushes `/sessions/:id`. A host's own session appearing in Upcoming/Completed still routes to the member detail screen from those tabs — the routing decision is made at the tap site, not by inspecting the session's `hostUid`.

**Trade-offs**
- Pro: each screen has a distinct responsibility; tab management, state, and providers are independent.
- Pro: the routing rule is simple and stateless — the push site always knows which route to use.
- Pro: host detail can add capabilities (End Session, Requests tab) without conditional rendering complexity.
- Con: some UI elements (session info card, notes tab, members list) are duplicated across screens; should be extracted into shared widgets.
- Reversal cost: low — merging screens collapses to a conditional rendering approach; the domain and data layers are unaffected.

---

**Decision for sub-decision 4:** Option A. Three separate screen files with three separate routes. The routing rule (push site determines route) is simple, stateless, and honours the constraint that the detail screen is determined by source context. The shared UI elements (session info card, notes tab, members list) are extracted into private shared widgets within the feature to avoid duplication.

---

## Decision

The Sessions feature uses three auto-dispose stream providers for the My Sessions tabs: Upcoming (reuses Index 1, client-side `status != 'ended'` filter), Completed (reuses Index 2), and My Sessions (new Index 9: `hostUid asc, scheduledAt desc`). Join requests are stored in `sessions/{sessionId}/requests/{uid}` subcollection — each document is keyed by the requesting user's UID and carries denormalized `displayName`, `photoUrl`, and `requestedAt`. Host display data (`hostDisplayName`, `hostPhotoUrl`) is denormalized at session creation, consistent with `hostFaculty` in ADR 0001; both fields are immutable after creation and `hostPhotoUrl` is nullable pending a future photo upload system. The feature uses three separate detail screens at three separate routes: `SessionDetailScreen` for the public pre-join view (`/sessions/:id`), `MemberSessionDetailScreen` for the post-join member view (`/my-sessions/session/:id/member`), and `HostSessionDetailScreen` for the host management view (`/my-sessions/session/:id/host`). The route pushed on card tap is determined solely by the source context (public list, Upcoming/Completed tab, My Sessions tab). The `session_card.dart` widget lives at `lib/shared/widgets/session_card.dart` so the Dashboard feature can import it. `SessionEntity` lives at `lib/features/sessions/domain/entities/session_entity.dart` as the single shared entity across Sessions, My Sessions, Calendar, and Dashboard. Before the Flutter Engineer begins any implementation, ADR 0001 must be amended to add the five session fields and the join-requests subcollection listed in Consequences.

---

## Consequences

### Required ADR 0001 amendment — `sessions/{sessionId}` schema additions

The following five fields must be added to the `sessions/{sessionId}` schema in ADR 0001 before any file in this feature is implemented.

| Field | Type | Constraints / Notes |
|---|---|---|
| `location` | String | Required; non-empty; max 300 characters |
| `scheduledEndAt` | Timestamp | Required; must be strictly after `scheduledAt`; set by host at creation; may be updated while `status == 'scheduled'` |
| `capacity` | int | Required; ≥ 1; maximum number of participants |
| `hostDisplayName` | String | Required; non-empty; denormalized from `users/{hostUid}.displayName` at session creation by `SessionRepositoryImpl`; immutable after creation |
| `hostPhotoUrl` | String | Nullable; denormalized from `users/{hostUid}.photoUrl` at session creation; immutable after creation |

The ADR 0001 amendment must also:
- Add `location`, `scheduledEndAt`, `capacity`, `hostDisplayName`, `hostPhotoUrl` to the `sessions` create rule's `hasAll` list.
- Add `location`, `scheduledEndAt`, `capacity` to the `sessions` update rule's `affectedKeys hasOnly` list (host may update while `status == 'scheduled'`).
- Exclude `hostDisplayName` and `hostPhotoUrl` from the update rule's `affectedKeys` (immutable, consistent with `hostFaculty`).
- Add ordering validation to the create rule: `request.resource.data.scheduledEndAt > request.resource.data.scheduledAt`.

### Required ADR 0001 amendment — `sessions/{sessionId}/requests/{uid}` subcollection

Add the following subcollection and its rules to ADR 0001.

**Schema:**

| Field | Type | Constraints / Notes |
|---|---|---|
| `uid` | String | Matches document ID; the requesting user's UID |
| `displayName` | String | Required; denormalized from `users/{uid}.displayName` at request creation |
| `photoUrl` | String | Nullable; denormalized from `users/{uid}.photoUrl` at request creation |
| `requestedAt` | Timestamp | Set via `request.time` on creation; immutable |

**Rules sketch:**

```
match /sessions/{sessionId}/requests/{uid} {
  // Host reads all requests. Requester reads only their own (for pending status check).
  allow read: if isHost(sessionId)
    || (isKmuttUser() && request.auth.uid == uid);

  // Only the user themselves may submit a request; they must not already be a member.
  allow create: if isKmuttUser()
    && request.auth.uid == uid
    && !(request.auth.uid in
         get(/databases/$(database)/documents/sessions/$(sessionId)).data.memberUids)
    && request.resource.data.requestedAt == request.time
    && request.resource.data.uid == uid
    && request.resource.data.keys().hasAll(['uid', 'displayName', 'requestedAt']);

  allow update: if false;

  // Host deletes on approve or decline. Requester may withdraw their own request.
  allow delete: if isHost(sessionId)
    || (isKmuttUser() && request.auth.uid == uid);
}
```

### New composite index

Add to `firestore.indexes.json`:

| # | Collection | Fields | Feature | Collection-group? |
|---|---|---|---|---|
| 9 | `sessions` | `hostUid` asc, `scheduledAt` desc | My Sessions tab | No |

### Domain entity

`SessionEntity` lives at `lib/features/sessions/domain/entities/session_entity.dart`. It includes all ADR 0001 fields plus the five new fields above.

Derived fields computed in the repository layer (not stored in Firestore):

| Derived field | Formula |
|---|---|
| `participantCount` | `memberUids.length` |
| `spotsLeft` | `max(0, capacity - memberUids.length)` |
| `isFull` | `memberUids.length >= capacity` |

`JoinRequestEntity` lives at `lib/features/sessions/domain/entities/join_request_entity.dart`. Fields: `uid`, `displayName`, `photoUrl` (nullable), `requestedAt`.

### Session card widget

`lib/shared/widgets/session_card.dart` — used by My Sessions feature AND by the Dashboard (Home) feature. Constructor:

```dart
SessionCard({
  required SessionEntity session,
  required String currentUserId,
  required VoidCallback onTap,
  bool showJoinButton = false,     // true on Home/Search only
  VoidCallback? onJoinTap,         // required when showJoinButton is true
})
```

Displays:
- Subject tag chip: `session.hashtags.firstOrNull ?? session.academicLevel` (plain text, no enum color).
- Status badge: `session.hostUid == currentUserId ? 'Hosting' : 'Joined'`.
- Session title, `session.hostDisplayName`, date/time (`scheduledAt`–`scheduledEndAt`), location, description.
- Capacity progress bar: `session.participantCount / session.capacity`, clamped 0.0–1.0.
- Spots left: `session.spotsLeft`.
- 3-dot menu:
  - Host menu (when `session.hostUid == currentUserId`): Edit Session → `/sessions/:id/edit`; Delete Session → confirm dialog → `deleteSession`.
  - Member menu (when `session.hostUid != currentUserId`): Leave Session → confirm dialog → `leaveSession`.
- Request To Join button: visible only when `showJoinButton == true`; calls `onJoinTap`.

### Routes to add to `app_router.dart`

Add to `RouteConstants` and wire in the router:

```
/sessions/create                     → CreateSessionScreen
/sessions/:id                        → SessionDetailScreen  (public pre-join)
/sessions/:id/edit                   → EditSessionScreen    (host only; guard in screen)
/sessions/:id/members                → MembersListScreen
/sessions/:id/requests               → RequestsScreen       (host only; guard in screen)
/my-sessions                         → MySessionsScreen     (StatefulShellRoute branch 4)
/my-sessions/session/:id/member      → MemberSessionDetailScreen
/my-sessions/session/:id/host        → HostSessionDetailScreen
```

### Files to create

**Domain:**
- `lib/features/sessions/domain/entities/session_entity.dart` — Freezed entity with all ADR 0001 fields + 5 new fields + 3 derived fields.
- `lib/features/sessions/domain/entities/join_request_entity.dart` — Freezed entity.
- `lib/features/sessions/domain/repositories/session_repository.dart` — abstract interface:
  - `Stream<SessionEntity?> watchSession(String sessionId)`
  - `Stream<List<SessionEntity>> watchPublicSessions()` — for home/search
  - `Stream<List<UserEntity>> watchMembers(String sessionId)`
  - `Future<void> createSession(SessionEntity session, {String? plainTextPin})`
  - `Future<void> editSession(String sessionId, String callerUid, Map<String, dynamic> updates)`
  - `Future<void> deleteSession(String sessionId, String callerUid)`
  - `Future<void> endSession(String sessionId, String callerUid)`
  - `Future<void> leaveSession(String sessionId, String uid)`
- `lib/features/sessions/domain/repositories/join_request_repository.dart` — abstract interface:
  - `Stream<List<JoinRequestEntity>> watchRequests(String sessionId)`
  - `Future<void> submitRequest(String sessionId, JoinRequestEntity request)`
  - `Future<void> approveRequest(String sessionId, String callerUid, String requestUid)`
  - `Future<void> declineRequest(String sessionId, String callerUid, String requestUid)`
  - `Future<void> withdrawRequest(String sessionId, String uid)`
- `lib/features/my_sessions/domain/repositories/my_sessions_repository.dart` — abstract interface:
  - `Stream<List<SessionEntity>> watchUpcomingSessions(String uid)`
  - `Stream<List<SessionEntity>> watchCompletedSessions(String uid)`
  - `Stream<List<SessionEntity>> watchHostedSessions(String uid)`

**Data:**
- `lib/features/sessions/data/models/session_model.dart` — Freezed + json_serializable; maps Firestore document to `SessionEntity`.
- `lib/features/sessions/data/models/join_request_model.dart` — Freezed + json_serializable.
- `lib/features/sessions/data/datasources/session_datasource.dart` — Firestore queries; path strings from `firestore_paths.dart` only.
- `lib/features/sessions/data/datasources/join_request_datasource.dart` — Firestore queries for `sessions/{sessionId}/requests`.
- `lib/features/sessions/data/repositories/session_repository_impl.dart` — reads `users/{hostUid}` once at creation to denormalize `hostDisplayName` and `hostPhotoUrl`.
- `lib/features/sessions/data/repositories/join_request_repository_impl.dart` — wraps approve in a `WriteBatch`: delete request document + `arrayUnion` uid to `memberUids`.
- `lib/features/my_sessions/data/datasources/my_sessions_datasource.dart` — three Firestore streams (Upcoming, Completed, Hosted).
- `lib/features/my_sessions/data/repositories/my_sessions_repository_impl.dart` — applies client-side `status != 'ended'` filter for the Upcoming stream.

**Presentation — providers:**
- `lib/features/sessions/presentation/providers/session_provider.dart` — `@riverpod Stream<SessionEntity?>` by sessionId.
- `lib/features/sessions/presentation/providers/session_members_provider.dart` — `@riverpod Stream<List<UserEntity>>` by sessionId.
- `lib/features/sessions/presentation/providers/join_requests_provider.dart` — `@riverpod Stream<List<JoinRequestEntity>>` by sessionId.
- `lib/features/my_sessions/presentation/providers/upcoming_sessions_provider.dart` — `@riverpod Stream<List<SessionEntity>>`.
- `lib/features/my_sessions/presentation/providers/completed_sessions_provider.dart` — same shape.
- `lib/features/my_sessions/presentation/providers/hosted_sessions_provider.dart` — same shape.

**Presentation — screens:**
- `lib/features/sessions/presentation/screens/create_session_screen.dart` — wraps `SessionForm(isEditing: false)`.
- `lib/features/sessions/presentation/screens/edit_session_screen.dart` — loads session via provider; guards non-hosts; wraps `SessionForm(isEditing: true, bottomExtra: _DeleteSessionButton)`.
- `lib/features/sessions/presentation/screens/session_detail_screen.dart` — public pre-join view; `CustomScrollView` + `SliverAppBar`; host 3-dot menu (edit/delete/copy link); `_JoinActionRow` switches on computed join status.
- `lib/features/sessions/presentation/screens/members_list_screen.dart` — full members list for host navigation.
- `lib/features/sessions/presentation/screens/requests_screen.dart` — full requests list for host navigation ("See All" target).
- `lib/features/sessions/presentation/widgets/session_form.dart` — 3-step form with `AnimatedSwitcher` + `FadeTransition`; `bottomExtra` slot; see design reference at `design/references/session_form_ref.dart`.
- `lib/features/my_sessions/presentation/screens/my_sessions_screen.dart` — `TabController(length: 3)`; top search + date-range filter row; three tab views (Upcoming, Completed, My Sessions); client-side search filters by `title` case-insensitively on the already-fetched list.
- `lib/features/my_sessions/presentation/screens/member_session_detail_screen.dart` — 2 tabs (Members, Notes); `ref.listen` on session stream triggers rating sheet when `status` transitions to `'ended'` (once, using `_sessionEndedPopupShown` flag); `isDismissible: false` on rating sheet.
- `lib/features/my_sessions/presentation/screens/host_session_detail_screen.dart` — 3 tabs (Members, Notes, Requests); End Session button; approve/decline actions with independent `_approvingLoading`/`_decliningLoading` state per request tile.

**Shared:**
- `lib/shared/widgets/session_card.dart` — see Session card widget section above.

### Analytics events to declare in `analytics_events.dart` before use

- `session_created`
- `session_edited`
- `session_deleted` — payload: `session_id`
- `session_ended` — payload: `session_id`
- `session_join_requested` — payload: `session_id`
- `session_joined` — payload: `session_id`
- `session_left` — payload: `session_id`
- `session_request_approved` — payload: `session_id`
- `session_request_declined` — payload: `session_id`
- `my_sessions_tab_switched` — payload: `tab_name` (`upcoming` | `completed` | `hosted`)
- `my_sessions_searched` — no payload; fire only on non-empty query; no PII
- `session_rating_submitted` — payload: `thumbs_up_count` (int)

---

## Reversal plan

**Sub-decision 1 (query strategy):** If the client-side status filter for Upcoming causes measurable performance issues (e.g., a user with thousands of historical member sessions), replace it with a Firestore `whereIn ['scheduled', 'active']` filter. Steps: (a) add Index 10 (`sessions: memberUids array-contains, status asc, scheduledAt asc`) to `firestore.indexes.json`; (b) update `MySessionsDatasource.watchUpcomingSessions` to add the `whereIn` clause; (c) remove the client-side `status != 'ended'` filter in `MySessionsRepositoryImpl`. No domain entity, provider, or presentation layer changes are required.

**Sub-decision 2 (join request storage):** If join requests must be embedded in the session document (e.g., to reduce read costs), add a `pendingUids: List<String>` array field to `sessions/{sessionId}` via an ADR 0001 amendment, migrate existing request documents to array entries, update the join-request datasource, and revise the Firestore rules. A dedicated migration ADR is required before this work begins.

**Sub-decision 3 (denormalization):** If `hostDisplayName` must reflect profile updates in real time, amend ADR 0001 to permit `hostDisplayName` and `hostPhotoUrl` in the session update rule's `affectedKeys`, and write a Cloud Function (or client-side `WriteBatch`) to sync display name changes. A new ADR covering the sync strategy is required. The `SessionEntity` interface and all presentation-layer code remain unchanged.

**Sub-decision 4 (detail screens):** If the three screens are merged into one context-aware screen, the files that change are: `app_router.dart` (collapse three route constants to one), `member_session_detail_screen.dart` and `host_session_detail_screen.dart` (merge into one screen with conditional rendering). The domain, data, and provider layers are unaffected. A reviewer must verify that the routing logic continues to honour the source-context rule.
