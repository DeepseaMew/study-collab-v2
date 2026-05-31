# 0013 — In-App Notification System and Settings Screen

| Field | Value |
|---|---|
| Status | Accepted  |
| Date | 2026-05-31 |
| Architect session | claude-sonnet-4-6 / DeepseaMew / 2026-05-31 |
| Affects | Notifications, Settings, Friends (write trigger), Sessions (write trigger), Rating (write trigger), firestore.rules, firestore.indexes.json, analytics_events.dart |

---

## Team approval

Approved by: Mew
Date: 2026-05-31
Notes:

---

## Problem

Study Collab has no mechanism to surface event-driven alerts (friend requests, session join requests, rating availability) to users, nor a settings screen for managing notification preferences and account actions. Without a decision record, the Flutter Engineer will produce divergent write paths for notification creation, no server-side authorship enforcement, and preference state scattered across providers. The solution must work entirely client-side for MVP, be privacy-safe (actor cannot read recipient private data), and extend cleanly when Cloud Functions are introduced in a future ADR.

---

## Constraints

- Domain layer has zero Flutter or Firebase imports.
- Repository interfaces live in `domain/`; implementations live in `data/`.
- Entities use Freezed; use cases are plain Dart classes.
- Business logic must not be defined in the presentation layer.
- KMUTT email gate enforced server-side via `isKmuttUser()` in Firestore rules.
- Firestore rules must use `diff().affectedKeys()` for field-level write validation.
- Web constraint (from ADR 0011): no `== request.time` check on any timestamp field; use a time-range window instead.
- Cloud Functions unavailable; all writes originate from the actor's client device.
- Actor must not be able to read the recipient's `users/{uid}` document to check preferences (privacy and rules budget).
- No unbounded `ListView`; notification list capped at 50 documents.
- All analytics events declared in `lib/core/analytics_events.dart` before use.

---

## Options considered

### Sub-decision 1 — Notification storage location

| | Option A | Option B | Option C |
|---|---|---|---|
| Summary | `users/{uid}/notifications/{notifId}` subcollection | Top-level `notifications/{notifId}` with `recipientUid` field | Local only via `flutter_secure_storage` |
| Read cost | Low: owner-only subcollection stream; no collection-group index needed for reads | Medium: requires collection-group query; all KMUTT users could potentially query the collection | Zero network cost; local read only |
| Offline support | Full: Firestore offline cache persists the subcollection | Full: offline cache persists, but wider surface | Full: persists locally; no cross-device sync |
| Write complexity | Low: actor writes to a known path `users/{recipientUid}/notifications/{notifId}` | Low: actor writes to a known top-level path | Low: actor writes to local storage only |
| Reversal cost | Low: subcollection migrated to top-level via one-time Cloud Function script | Medium: migrating to subcollection requires full re-write and index changes | High: abandoning local storage loses cross-device history; no migration path |
| Recommendation | Recommended | Not recommended | Not recommended |

Option A is recommended. A per-user subcollection keeps Firestore rules simple (owner reads, KMUTT users create only), survives reinstalls because data lives on the server, and supports real-time streaming without a collection-group index. Option B widens the read surface unnecessarily; Option C breaks on device change.

---

### Sub-decision 2 — Unread count strategy

| | Option A | Option B | Option C |
|---|---|---|---|
| Summary | Stream `users/{uid}/notifications` where `isRead == false`; count client-side (requires Index 13) | Denormalize `unreadNotificationCount` on `users/{uid}`; `FieldValue.increment` on write and mark-read | Count from a cached full-list snapshot |
| Read cost | Low: filtered stream; index cost is minimal | Very low: single field read on already-streamed user doc | Zero network; entirely local |
| Offline support | Full: Firestore offline cache serves the filtered stream | Full: user doc is always cached | Full: always available; may be stale |
| Write complexity | Low: no extra write on notification create; count derived from stream | High: atomic increment on every write AND decrement/zero on every mark-read; race conditions possible | None |
| Reversal cost | Medium: switching to counter requires backfill migration on all user docs | Low: removing the counter field is a simple data migration | Low: replacing with server stream is a provider-only change |
| Recommendation | Recommended | Not recommended | Not recommended |

Option A is recommended. A real-time filtered stream keeps the badge count accurate without counter drift from concurrent increments or decrements. The composite index cost (Index 13) is minimal and already required for the notification panel query. Option B adds write complexity and risks stale counts under concurrent operations.

---

### Sub-decision 3 — Notification list query

| | Option A | Option B |
|---|---|---|
| Summary | Stream latest 50 `users/{uid}/notifications` ordered by `createdAt` desc; no pagination | Cursor-based paginated fetch |
| Read cost | Low: single stream of 50 documents maximum | Low per page, but multiple round-trips for history |
| Offline support | Full: the 50-document window is cached | Partial: only the first page is reliably cached |
| Write complexity | None | Medium: cursor state in provider; next-page logic in datasource |
| Reversal cost | Low: swap to cursor pagination by adding cursor parameter to provider query; no schema change | Low: drop pagination and stream full list; no schema change |
| Recommendation | Recommended | Not recommended |

Option A is recommended. Fifty notifications covers several weeks of typical activity for an MVP; a live stream keeps the panel current without a pull-to-refresh gesture. Cursor pagination can be adopted later without any schema change.

---

### Sub-decision 4 — Notification creation — who writes?

| | Option A | Option B |
|---|---|---|
| Summary | Actor's device writes directly to `users/{recipientUid}/notifications/{notifId}`; rule scoped to create-only | Cloud Function trigger on friends/sessions write |
| Read cost | Zero: path is known; no extra reads | Zero at client; Cloud Function reads trigger document |
| Offline support | Partial: queued by SDK and flushed on reconnect | None: Cloud Functions not available on Spark plan |
| Write complexity | Low: single `set()` call at each of the 6 trigger points | Out of scope: Spark plan blocks Cloud Functions |
| Reversal cost | Low: replace write call site with Cloud Function invocation; remove create rule permission | High: Cloud Function deployment, infra changes |
| Recommendation | Recommended | Not recommended |

Option A is recommended. Direct actor writes avoid Cloud Functions (unavailable on Spark plan), keep latency low, and are consistently enforced by a tightly scoped create-only rule. Cloud Functions can replace actor writes in ADR 0014 by switching the write call site and removing the create permission from the rule.

---

### Sub-decision 5 — Mark as read strategy

| | Option A | Option B | Option C |
|---|---|---|---|
| Summary | Batch update all unread docs to `isRead: true` on notification panel open | Mark read on individual notification tap only | Mark read for visible items only on scroll |
| Read cost | None beyond existing stream | None | None |
| Write complexity | Low: one batch write of up to 50 docs on open | Low: single doc update per tap | Medium: scroll-position tracking + per-item write |
| Reversal cost | Low: isolated in one repository method | Low: provider-only change | Low: provider-only change |
| Recommendation | Recommended | Not recommended | Not recommended |

Option A is recommended. Opening the panel signals intent to view all alerts, consistent with email and messaging conventions. A batch write capped at 50 documents is a single Firestore operation. Options B and C each require per-item UI state tracking or scroll-position instrumentation that is not justified at MVP scale.

---

### Sub-decision 6 — Preference enforcement

| | Option A | Option B | Option C |
|---|---|---|---|
| Summary | Actor checks recipient's preferences before writing | Actor always writes; recipient's app filters locally via `flutter_secure_storage` | Firestore rule enforces preference |
| Read cost | High: actor reads private `users/{recipientUid}` document — rules must block this | Zero: preferences read locally | Zero: rule-time enforcement |
| Write complexity | High: adds a read before every notification write | Low: write always; filter on display only | Not feasible: rules cannot read caller-supplied preferences securely |
| Reversal cost | High: privacy violation — cannot be patched without full redesign | Low: add Cloud Function filter layer; local filter remains as fast-path | Not applicable |
| Recommendation | Not recommended | Recommended | Not recommended |

Option B is recommended. Actors cannot and should not read a recipient's private preference document; Firestore rules block cross-user reads on the `users` collection. Local filtering via `flutter_secure_storage` is instant, zero-latency, and requires no network round-trip. Notification documents are written regardless and serve as a persistent audit trail.

---

## Decision

Notifications are stored as a subcollection `users/{uid}/notifications/{notifId}` (SD1). Unread count is derived by streaming documents where `isRead == false` client-side against Index 13 (SD2). The notification panel streams the latest 50 documents ordered by `createdAt` desc with no pagination for MVP (SD3). The actor's device writes notification documents directly at each of the 6 trigger points under a tightly scoped create-only Firestore rule (SD4). Opening the notification panel triggers a batch update marking all unread documents as read (SD5). Notification preferences are stored locally in `flutter_secure_storage` and applied client-side as a display filter; actors always write regardless of recipient preferences (SD6).

---

## Consequences

- `NotificationEntity` (Freezed) must include all 8 fields from the schema table below; zero Flutter or Firebase imports in the entity.
- `NotificationRepository` interface in `domain/repositories/`; `NotificationRepositoryImpl` in `data/repositories/`.
- Six trigger points (friends send, friends accept, join request, join approved, join declined, rating available) must each call `NotificationRepository.createNotification` after their primary write.
- `notification_preferences_provider.dart` reads/writes `flutter_secure_storage`; it is a presentation-layer provider with no Firestore dependency.
- `NotificationBellBadge` widget streams unread count and displays a badge; consumed by the app shell nav bar.
- `firestore.rules` requires a new `match /users/{uid}/notifications/{notifId}` block (see Firestore rules section below).
- `firestore.indexes.json` must add Index 13 before the notification panel deploys.
- Declare `notification_panel_opened`, `notification_marked_read`, `notification_preference_changed` in `lib/core/analytics_events.dart` before any call site is written.
- Settings screen is a standalone feature screen; it has no domain or data layer — all logic is presentation-layer calls to existing auth and preference providers.
- Session reminder notifications are out of scope — ADR 0014 was cancelled.

---

## Firestore schema

### `users/{uid}/notifications/{notifId}`

| Field | Type | Notes |
|---|---|---|
| `notifId` | String | Doc ID stored redundantly for convenience |
| `type` | String | Enum: `friend_request`, `friend_accepted`, `join_request`, `join_approved`, `join_declined`, `rating_available` |
| `actorUid` | String | UID of the user who triggered the event |
| `actorDisplayName` | String | Denormalized at write time; non-empty |
| `sessionId` | String? | Null for friend-type events |
| `sessionTitle` | String? | Denormalized at write time; null for friend-type events |
| `isRead` | bool | `false` on create; `true` after user views |
| `createdAt` | Timestamp | `FieldValue.serverTimestamp()` on create |

### Notification preferences (`flutter_secure_storage`, key: `notification_preferences`, JSON-encoded)

| Preference key | Type | Default | Controls |
|---|---|---|---|
| `allNotifications` | bool | true | Master toggle; false suppresses all display |
| `joinRequestAlerts` | bool | true | `join_request`, `join_approved`, `join_declined` |
| `friendRequests` | bool | true | `friend_request`, `friend_accepted` |
| `ratingAvailable` | bool | true | `rating_available` |

---

## Notification trigger points

| # | Event | Actor writes to | Type field |
|---|---|---|---|
| 1 | Friend request sent | Recipient's notifications subcollection | `friend_request` |
| 2 | Friend request accepted | Original sender's notifications subcollection | `friend_accepted` |
| 3 | Join request sent | Session host's notifications subcollection | `join_request` |
| 4 | Join request approved | Requester's notifications subcollection | `join_approved` |
| 5 | Join request declined | Requester's notifications subcollection | `join_declined` |
| 6 | Host ends session | All session members' notifications subcollections | `rating_available` |

---

## Settings screen sections

1. **Profile** — `CircleAvatar` (radius 28, accent initial fallback), display name (`tt.titleLarge`), email (`tt.bodyMedium`, hint color). No Edit Profile action (pending future ADR).
2. **Notifications** — toggles in order: All Notifications (master), Join Request Alerts, Friend Requests, Rating Available.
3. **Account** — Change Password (`Icons.lock_outline`), Sign Out (`Icons.logout`, error color) with confirmation dialog.

---

## Firestore rules

Add the following block inside `match /users/{uid}` in `firestore.rules`.

```
match /notifications/{notifId} {
  // Only the owner may read their own notifications.
  allow get, list: if isKmuttUser() && request.auth.uid == uid;

  // Any authenticated KMUTT user may create a notification for another user,
  // but only as the actor and only with the required fields.
  allow create: if isKmuttUser()
    && request.resource.data.keys().hasOnly([
         'notifId', 'type', 'actorUid', 'actorDisplayName',
         'sessionId', 'sessionTitle', 'isRead', 'createdAt'
       ])
    && request.resource.data.type in [
         'friend_request', 'friend_accepted', 'join_request',
         'join_approved', 'join_declined', 'rating_available'
       ]
    && request.resource.data.actorUid == request.auth.uid
    && request.resource.data.isRead == false
    && request.resource.data.actorDisplayName is string
    && request.resource.data.actorDisplayName.size() > 0;

  // Only the owner may mark notifications as read; no other field may change.
  allow update: if isKmuttUser()
    && request.auth.uid == uid
    && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['isRead'])
    && request.resource.data.isRead == true;

  // Only the owner may delete their own notifications.
  allow delete: if isKmuttUser() && request.auth.uid == uid;
}
```

---

## Composite index

| # | Collection | Fields | Query scope | Used by |
|---|---|---|---|---|
| 13 | `users/{uid}/notifications` | `isRead` ASC, `createdAt` DESC | Collection | Unread count stream (SD2) |

---

## Analytics events

Declare in `lib/core/analytics_events.dart` before any call site:

- `notification_panel_opened` — no payload
- `notification_marked_read` — params: `type` (String), `notif_id` (String)
- `notification_preference_changed` — params: `preference_key` (String), `new_value` (bool)

---

## Full file list

```
apps/mobile/lib/
  features/notifications/
    data/
      datasources/notification_remote_datasource.dart
      models/notification_model.dart
    domain/
      entities/notification_entity.dart
      repositories/notification_repository.dart
      usecases/stream_notifications_usecase.dart
      usecases/stream_unread_count_usecase.dart
      usecases/mark_all_read_usecase.dart
      usecases/create_notification_usecase.dart
    presentation/
      providers/notifications_provider.dart
      providers/unread_count_provider.dart
      providers/notification_preferences_provider.dart
      screens/notification_panel_screen.dart
      widgets/notification_bell_badge.dart
      widgets/notification_list_tile.dart
  features/settings/
    presentation/
      screens/settings_screen.dart
      widgets/notification_preferences_section.dart
  core/analytics_events.dart        ← add 3 new events
firestore.rules                      ← add notifications match block
firestore.indexes.json               ← add Index 13
```

---

## Reversal plan

To disable the notification system: remove the `createNotification` call at each of the 6 trigger points and hide `NotificationBellBadge` in the app shell. No data migration is needed — existing notification documents are inert and do not affect other features. Preference data in `flutter_secure_storage` can be cleared on next app launch via a version-keyed migration flag in `lib/core/feature_flags.dart`. The Firestore rules block and Index 13 may remain in place safely; they only activate when documents are written.

---

## Related ADRs

- ADR 0001 — Firestore schema; defines `users/{uid}` baseline and `isKmuttUser()` helper.
- ADR 0004 — Friends; defines trigger points 1 and 2 (friend request sent, accepted).
- ADR 0003 — Sessions; defines trigger points 3, 4, and 5 (join request lifecycle).
- ADR 0009 — Rating; defines trigger point 6 (host ends session → rating available).
- ADR 0011 — DM Chat; establishes the web `request.time` constraint (time-range window instead of `== request.time`).
