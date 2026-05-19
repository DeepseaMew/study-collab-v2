# 0001 — Firestore Schema and Security Rules Design

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-05-15 |
| Architect session | claude-sonnet-4-6 / DeepseaMew / 2026-05-15 |
| Affects | Auth, Sessions, Friends, Chat, Rating, Note-Sharing, Calendar, Firestore rules, data/datasources, domain/entities |

---

## Team approval

Approved by: DeepseaMew
Date: 2026-05-15
Notes: —

---

## Decision

Full subcollection nesting (Option B). Session-scoped data (`messages`, `ratings`, `notes`) lives under `sessions/{sessionId}/`. Friend data lives under `users/{uid}/friends/`. DM messages live under `dms/{dmId}/messages/`.

**Why:** every hot read path is scoped to a single session or user, so subcollections provide security-rule path inheritance that eliminates extra `get()` calls. The only cross-session query (`ratings` by `rateeUid` for profile score) is infrequent and is handled by a collection-group index (Index 6). The 50-note cap is enforced cleanly at the subcollection path level.

---

## Constraints

- Domain layer has zero Flutter or Firebase imports. All Firestore paths are string constants in the data layer only (`lib/core/firestore_paths.dart`).
- Repository interfaces in `domain/repositories/`; implementations in `data/repositories/`. No Firestore types cross this boundary.
- Entities use Freezed; datasource models use Freezed + json_serializable.
- KMUTT email gate (`@mail.kmutt.ac.th` / `@kmutt.ac.th`) enforced in Firestore rules via `request.auth.token.email.matches(...)`, not only client-side.
- All timestamp fields written server-side via `request.time`; no client-generated timestamp may bypass this.
- Firestore rules must use `diff().affectedKeys()` for field-level write validation on every collection and subcollection.
- Users may only read and write their own documents unless their role explicitly permits otherwise.
- Denormalization is driven by read patterns only.
- Every composite index must be justified by a specific feature query.
- Rating writes are online-only; rules enforce `status == 'ended'` before a rating document can be created.
- Notes capped at 50 per session; enforced in rules, not only client-side.
- Friendship is bidirectional; both friend documents written atomically in a single batch.
- No PII beyond the fields listed in the schema section may be stored on any document.
- Business logic must not be defined in the presentation layer.

---

## Schema

All timestamp fields are written server-side using `request.time` and must never be set from a client-generated value.

---

### `users/{uid}`

| Field | Type | Constraints / Notes |
|---|---|---|
| uid | String | Matches Firebase Auth UID; document ID equals this value |
| displayName | String | Required; non-empty; max 100 characters |
| fullName | String | Required; non-empty; max 150 characters. **PII — never log, never use as Crashlytics key or analytics property.** |
| email | String | Required; must match `@mail.kmutt.ac.th` or `@kmutt.ac.th` |
| photoUrl | String | Nullable; Firebase Storage URL or external avatar URL |
| hasHostedBefore | bool | UI hint only; `false` by default; set to `true` when user creates their first session. Never used as a security gate. |
| studentYear | int | Values 1–8 |
| academicLevel | String | Enum: `undergraduate` or `graduate` |
| faculty | String | `.name` of `KmuttFaculty` enum; `''` on initial creation; required non-empty after profile setup |
| bio | String | Nullable; free text; max 300 characters; `''` on initial creation |
| profileScore | float | ≥ 0.0; thumbs-up received ÷ ended sessions joined; updated on each rating write |
| createdAt | Timestamp | Set once on creation via `request.time`; immutable |
| updatedAt | Timestamp | Updated on every profile write via `request.time` |

No PII beyond `displayName`, `fullName`, `email`, and `photoUrl` may be stored on this document.

---

### `sessions/{sessionId}`

| Field | Type | Constraints / Notes |
|---|---|---|
| sessionId | String | Firestore auto-generated document ID; stored redundantly |
| hostUid | String | UID of the session creator; immutable after creation |
| hostFaculty | String | `.name` of `KmuttFaculty` enum; copied from `users/{hostUid}.faculty` at creation by `SessionRepositoryImpl`; immutable. Enables Index 8 faculty filter without a `get()` inside rules. |
| title | String | Required; non-empty; max 200 characters |
| description | String | Nullable; max 2000 characters |
| hashtags | List\<String\> | Lowercase, free-text; max 20 elements |
| academicLevel | String | Enum: `undergraduate` or `graduate` |
| studentYear | int | Values 1–8 |
| visibility | String | Enum: `public` or `private` |
| pin | String | Nullable; only present when `visibility == 'private'`; min 4 characters; stored in plaintext |
| memberUids | List\<String\> | All current member UIDs including host; used for `array-contains` queries and rules membership checks; denormalized |
| noteCount | int | Count of notes in the `notes` subcollection; incremented atomically in the same batch as note creation; used by the notes cap rule |
| status | String | Enum: `scheduled`, `active`, or `ended`; one-way transitions |
| scheduledAt | Timestamp | Set by host at creation; may be updated while `status == 'scheduled'` |
| scheduledEndAt | Timestamp | Required; must be strictly after `scheduledAt`; set by host at creation; may be updated while `status == 'scheduled'` |
| endedAt | Timestamp | Nullable; set when host ends session; immutable once set |
| location | String | Required; non-empty; max 300 characters |
| capacity | int | Required; ≥ 1; maximum number of participants |
| hostDisplayName | String | Required; non-empty; denormalized from `users/{hostUid}.displayName` at session creation by `SessionRepositoryImpl`; immutable after creation |
| hostPhotoUrl | String | Nullable; denormalized from `users/{hostUid}.photoUrl` at session creation; immutable after creation |
| createdAt | Timestamp | Set once on creation; immutable |
| updatedAt | Timestamp | Updated on every write |

---

### `sessions/{sessionId}/messages/{messageId}`

Group chat. Visible to session members. History persists after session ends. Append-only — no edit or delete.

| Field | Type | Constraints / Notes |
|---|---|---|
| messageId | String | Auto-generated; stored redundantly |
| senderUid | String | Must be in `sessions/{sessionId}.memberUids` |
| text | String | Required; non-empty; max 4000 characters |
| sentAt | Timestamp | Set via `request.time` on creation; immutable |
| readBy | List\<String\> | UIDs who have read this message; append-only |

Pagination: `sentAt` descending with `startAfterDocument` cursor.

---

### `dms/{dmId}` and `dms/{dmId}/messages/{messageId}`

One-on-one DMs between confirmed friends.

**`dmId` construction (data-layer contract):** `min(uidA, uidB) + '_' + max(uidA, uidB)` using lexicographic order. **Must be constructed in `data/datasources/dm_datasource.dart` or `data/repositories/dm_repository_impl.dart` only — never in the presentation layer.** Violating this creates duplicate DM documents.

**`dms/{dmId}` parent document:**

| Field | Type | Constraints / Notes |
|---|---|---|
| participantUids | List\<String\> | Exactly two UIDs, sorted; used for security rule lookups |
| createdAt | Timestamp | Set on first message creation |

**`dms/{dmId}/messages/{messageId}`:**

| Field | Type | Constraints / Notes |
|---|---|---|
| messageId | String | Auto-generated; stored redundantly |
| senderUid | String | Must be one of `dms/{dmId}.participantUids` |
| text | String | Required; non-empty; max 4000 characters |
| sentAt | Timestamp | Set via `request.time` on creation; immutable |
| readBy | List\<String\> | UIDs who have read this message |

Both `users/A/friends/B.status` and `users/B/friends/A.status` must equal `'accepted'` before a DM may be created or a message sent. Enforced in Firestore rules.

---

### `users/{uid}/friends/{friendUid}`

Bidirectional friendship. Both documents written and deleted atomically via `WriteBatch`.

| Field | Type | Constraints / Notes |
|---|---|---|
| friendUid | String | UID of the other party; matches the document ID |
| status | String | Enum: `pending` or `accepted` |
| initiatorUid | String | UID of the user who sent the request; used to determine who may withdraw a pending request |
| createdAt | Timestamp | Set when request is sent; immutable |
| updatedAt | Timestamp | Updated on status change |

A `status == 'pending'` document on `users/B/friends/A` (written by A's batch) signals an inbound request to B.

---

### `sessions/{sessionId}/ratings/{raterUid}`

Thumbs-up rating submitted by session members after a session ends. Only thumbs-up is supported — there is no thumbs-down. Document ID is `raterUid`, enforcing one rating per rater per session. Immutable once created.

| Field | Type | Constraints / Notes |
|---|---|---|
| raterUid | String | Matches document ID |
| rateeUid | String | Must be a session member; must differ from `raterUid` |
| liked | bool | Always `true`; the user pressed the thumbs-up button. Enforced in Firestore rules (`liked == true`). No document = user did not rate. |
| ratedAt | Timestamp | Set via `request.time` on creation; immutable |

**After each rating write:** the data layer recalculates `users/{rateeUid}.profileScore` using two counts — (1) collection-group count on `ratings` where `rateeUid == uid` (Index 6); (2) count on `sessions` where `memberUids array-contains uid` and `status == 'ended'` (Index 2). Formula: `profileScore = thumbsUpCount / endedSessionsJoined`. Both the rating creation and the score update must be in the same `WriteBatch`.

---

### `sessions/{sessionId}/notes/{noteId}`

Files uploaded by session members. Capped at 50 per session. No edit; create and delete only.

| Field | Type | Constraints / Notes |
|---|---|---|
| noteId | String | Auto-generated; stored redundantly |
| uploaderUid | String | Must be in `sessions/{sessionId}.memberUids` |
| fileName | String | Original filename including extension; max 255 characters |
| mimeType | String | Validated client-side before upload |
| sizeBytes | int | Must be > 0 and ≤ 10,485,760 (10 MB) |
| storageRef | String | Firebase Storage path (not a full URL) |
| downloadUrl | String | Signed or public Firebase Storage download URL |
| uploadedAt | Timestamp | Set via `request.time` on creation; immutable |

Supported MIME types: `image/jpeg`, `image/png`, `image/gif`, `image/webp`, `application/pdf`, `application/msword`, `application/vnd.openxmlformats-officedocument.wordprocessingml.document`, `text/plain`, `application/zip`, `application/x-rar-compressed`, `application/x-7z-compressed`.

Delete: host (`sessions/{sessionId}.hostUid`) or file owner (`uploaderUid`) only.

The 50-note cap is enforced in rules by checking `sessions/{sessionId}.noteCount` via `getAfter(...)`. The note create and the `noteCount` increment must be in the same `WriteBatch`.

---

### `sessions/{sessionId}/requests/{uid}`

Join requests submitted by users who want to join a session. Document ID is the requesting user's UID, enforcing one pending request per user per session. Immutable once created; the host deletes on approve or decline, and the requester may withdraw their own request.

| Field | Type | Constraints / Notes |
|---|---|---|
| uid | String | Matches document ID; the requesting user's UID |
| displayName | String | Required; non-empty; denormalized from `users/{uid}.displayName` at request creation |
| photoUrl | String | Nullable; denormalized from `users/{uid}.photoUrl` at request creation |
| requestedAt | Timestamp | Set via `request.time` on creation; immutable |

**On approval:** the host's `WriteBatch` must atomically delete the request document and append the `uid` to `sessions/{sessionId}.memberUids`. The `sessions` update rule already permits `memberUids` in `affectedKeys`.

**On decline:** the host deletes the request document. No write to `memberUids`.

---

## Composite indexes

All indexes must be declared in `firestore.indexes.json` before deployment.

| # | Collection path | Fields | Feature | Collection-group? |
|---|---|---|---|---|
| 1 | `sessions` | `memberUids` (array-contains), `scheduledAt` asc | Calendar — upcoming sessions | No |
| 2 | `sessions` | `memberUids` (array-contains), `status` asc, `endedAt` desc | Calendar — past sessions | No |
| 3 | `sessions` | `hashtags` (array-contains), `academicLevel` asc, `studentYear` asc | Search — filter by hashtag + level + year | No |
| 4 | `sessions/{sessionId}/messages` | `sentAt` desc | Group chat pagination | No |
| 5 | `dms/{dmId}/messages` | `sentAt` desc | DM chat pagination | No |
| 6 | `sessions/{sessionId}/ratings` | `rateeUid` asc, `ratedAt` desc | Profile score calculation across all sessions | **Yes** |
| 7 | `sessions/{sessionId}/notes` | `uploadedAt` desc | Notes list in session detail | No |
| 8 | `sessions` | `hostFaculty` asc, `status` asc, `scheduledAt` asc | Search — filter by faculty + status | No |
| 9 | `sessions` | `hostUid` asc, `scheduledAt` desc | My Sessions tab — hosted sessions list | No |

**Index 3 note:** Firestore requires a composite index when `array-contains` is combined with additional filters. Always include `hashtags` as the `array-contains` field when using this index.

**Index 6 note:** spans all `ratings` subcollections across all sessions; collection-group index is mandatory.

---

## Firestore security rules sketch

Use this as the authoritative specification when writing `firestore.rules`. Every rule must use `diff().affectedKeys()` for field-level write validation and `request.time` for all timestamp fields.

---

### Helper functions

```
function isKmuttUser() {
  return request.auth != null
    && request.auth.token.email_verified == true
    && request.auth.token.email.matches('.*@(mail\\.kmutt\\.ac\\.th|kmutt\\.ac\\.th)$');
}

function isHost(sessionId) {
  return isKmuttUser()
    && get(/databases/$(database)/documents/sessions/$(sessionId)).data.hostUid
       == request.auth.uid;
}

function isMember(sessionId) {
  return isKmuttUser()
    && request.auth.uid in
       get(/databases/$(database)/documents/sessions/$(sessionId)).data.memberUids;
}

function sessionEnded(sessionId) {
  return get(/databases/$(database)/documents/sessions/$(sessionId)).data.status
    == 'ended';
}

function areFriends(uidA, uidB) {
  return get(/databases/$(database)/documents/users/$(uidA)/friends/$(uidB)).data.status
    == 'accepted'
    && get(/databases/$(database)/documents/users/$(uidB)/friends/$(uidA)).data.status
    == 'accepted';
}
```

---

### `users/{uid}`

```
match /users/{uid} {
  allow read: if isKmuttUser();

  allow create: if isKmuttUser()
    && request.auth.uid == uid
    && request.resource.data.keys().hasAll([
         'uid', 'displayName', 'fullName', 'email', 'hasHostedBefore',
         'studentYear', 'academicLevel', 'faculty',
         'profileScore', 'createdAt', 'updatedAt'
       ])
    && request.resource.data.email.matches('.*@(mail\\.kmutt\\.ac\\.th|kmutt\\.ac\\.th)$')
    && request.resource.data.createdAt == request.time
    && request.resource.data.updatedAt == request.time
    && request.resource.data.hasHostedBefore == false
    && request.resource.data.profileScore == 0.0;

  allow update: if isKmuttUser()
    && request.auth.uid == uid
    && request.resource.data.diff(resource.data).affectedKeys()
         .hasOnly(['displayName', 'fullName', 'photoUrl', 'studentYear', 'academicLevel',
                   'faculty', 'bio', 'hasHostedBefore', 'profileScore', 'updatedAt'])
    && request.resource.data.updatedAt == request.time
    && request.resource.data.uid == resource.data.uid
    && request.resource.data.createdAt == resource.data.createdAt
    && request.resource.data.email == resource.data.email;

  allow delete: if false;
}
```

---

### `sessions/{sessionId}`

```
match /sessions/{sessionId} {
  allow read: if isKmuttUser()
    && (resource.data.visibility == 'public'
        || request.auth.uid in resource.data.memberUids);

  allow create: if isKmuttUser()
    && request.resource.data.hostUid == request.auth.uid
    && request.resource.data.memberUids == [request.auth.uid]
    && request.resource.data.status == 'scheduled'
    && request.resource.data.createdAt == request.time
    && request.resource.data.updatedAt == request.time
    && request.resource.data.keys().hasAll([
         'sessionId', 'hostUid', 'hostFaculty', 'title', 'hashtags', 'academicLevel',
         'studentYear', 'visibility', 'memberUids', 'noteCount', 'status',
         'scheduledAt', 'scheduledEndAt', 'location', 'capacity',
         'hostDisplayName', 'createdAt', 'updatedAt'
       ])
    && request.resource.data.scheduledEndAt > request.resource.data.scheduledAt
    && request.resource.data.capacity >= 1;

  allow update: if isHost(sessionId)
    && request.resource.data.diff(resource.data).affectedKeys()
         .hasOnly(['title', 'description', 'hashtags', 'academicLevel',
                   'studentYear', 'visibility', 'pin', 'memberUids',
                   'noteCount', 'status', 'scheduledAt', 'scheduledEndAt',
                   'location', 'capacity', 'endedAt', 'updatedAt'])
    && request.resource.data.updatedAt == request.time
    && request.resource.data.hostUid == resource.data.hostUid
    && request.resource.data.hostFaculty == resource.data.hostFaculty
    && request.resource.data.hostDisplayName == resource.data.hostDisplayName
    && request.resource.data.hostPhotoUrl == resource.data.hostPhotoUrl
    && request.resource.data.createdAt == resource.data.createdAt;

  allow delete: if isHost(sessionId)
    && resource.data.status == 'scheduled';
}
```

---

### `sessions/{sessionId}/messages/{messageId}`

```
match /sessions/{sessionId}/messages/{messageId} {
  allow read: if isMember(sessionId);

  allow create: if isMember(sessionId)
    && request.resource.data.senderUid == request.auth.uid
    && request.resource.data.sentAt == request.time
    && request.resource.data.readBy == [request.auth.uid]
    && request.resource.data.keys().hasAll([
         'messageId', 'senderUid', 'text', 'sentAt', 'readBy'
       ]);

  allow update: if isMember(sessionId)
    && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['readBy'])
    && request.auth.uid in request.resource.data.readBy;

  allow delete: if false;
}
```

---

### `dms/{dmId}` and `dms/{dmId}/messages/{messageId}`

```
match /dms/{dmId} {
  allow read: if isKmuttUser()
    && request.auth.uid in resource.data.participantUids;

  allow create: if isKmuttUser()
    && request.auth.uid in request.resource.data.participantUids
    && request.resource.data.participantUids.size() == 2
    && areFriends(request.resource.data.participantUids[0],
                  request.resource.data.participantUids[1])
    && request.resource.data.createdAt == request.time;

  allow update: if false;
  allow delete: if false;

  match /messages/{messageId} {
    allow read: if isKmuttUser()
      && request.auth.uid in
         get(/databases/$(database)/documents/dms/$(dmId)).data.participantUids;

    allow create: if isKmuttUser()
      && request.auth.uid in
         get(/databases/$(database)/documents/dms/$(dmId)).data.participantUids
      && request.resource.data.senderUid == request.auth.uid
      && request.resource.data.sentAt == request.time
      && request.resource.data.keys().hasAll([
           'messageId', 'senderUid', 'text', 'sentAt', 'readBy'
         ]);

    allow update: if isKmuttUser()
      && request.auth.uid in
         get(/databases/$(database)/documents/dms/$(dmId)).data.participantUids
      && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['readBy']);

    allow delete: if false;
  }
}
```

---

### `users/{uid}/friends/{friendUid}`

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
       ]);

  allow update: if isKmuttUser()
    && (request.auth.uid == uid || request.auth.uid == friendUid)
    && request.resource.data.diff(resource.data).affectedKeys()
         .hasOnly(['status', 'updatedAt'])
    && request.resource.data.updatedAt == request.time;

  allow delete: if isKmuttUser()
    && (request.auth.uid == uid || request.auth.uid == friendUid);
}
```

---

### `sessions/{sessionId}/ratings/{raterUid}`

```
match /sessions/{sessionId}/ratings/{raterUid} {
  allow read: if isMember(sessionId);

  allow create: if isMember(sessionId)
    && sessionEnded(sessionId)
    && request.auth.uid == raterUid
    && request.resource.data.raterUid == raterUid
    && request.resource.data.rateeUid != raterUid
    && request.resource.data.liked == true
    && request.resource.data.ratedAt == request.time
    && request.resource.data.keys().hasAll([
         'raterUid', 'rateeUid', 'liked', 'ratedAt'
       ]);

  allow update: if false;
  allow delete: if false;
}
```

---

### `sessions/{sessionId}/notes/{noteId}`

```
match /sessions/{sessionId}/notes/{noteId} {
  allow read: if isMember(sessionId);

  allow create: if isMember(sessionId)
    && request.resource.data.uploaderUid == request.auth.uid
    && request.resource.data.uploadedAt == request.time
    && request.resource.data.sizeBytes > 0
    && request.resource.data.sizeBytes <= 10485760
    && request.resource.data.keys().hasAll([
         'noteId', 'uploaderUid', 'fileName', 'mimeType',
         'sizeBytes', 'storageRef', 'downloadUrl', 'uploadedAt'
       ])
    && getAfter(/databases/$(database)/documents/sessions/$(sessionId))
         .data.noteCount <= 50;

  allow update: if false;

  allow delete: if isKmuttUser()
    && (isHost(sessionId) || request.auth.uid == resource.data.uploaderUid);
}
```

---

### `sessions/{sessionId}/requests/{uid}`

```
match /sessions/{sessionId}/requests/{uid} {
  // Host reads all pending requests. Requester reads only their own (for pending-status display).
  allow read: if isHost(sessionId)
    || (isKmuttUser() && request.auth.uid == uid);

  // Only the requester may submit; they must not already be a member.
  allow create: if isKmuttUser()
    && request.auth.uid == uid
    && !(request.auth.uid in
         get(/databases/$(database)/documents/sessions/$(sessionId)).data.memberUids)
    && request.resource.data.uid == uid
    && request.resource.data.requestedAt == request.time
    && request.resource.data.keys().hasAll(['uid', 'displayName', 'requestedAt']);

  allow update: if false;

  // Host deletes on approve or decline. Requester may withdraw their own request.
  allow delete: if isHost(sessionId)
    || (isKmuttUser() && request.auth.uid == uid);
}
```

---

## Denormalization summary

| Field | Lives on | Updated by | Why |
|---|---|---|---|
| `memberUids` | `sessions/{sessionId}` | Any join/leave/approval write | Enables `array-contains` calendar queries and membership checks in rules without a subcollection query |
| `profileScore` | `users/{uid}` | Same `WriteBatch` as each rating creation | Avoids expensive queries on every profile read. Formula: count(`ratings` where `rateeUid == uid`) ÷ count(`sessions` where `memberUids array-contains uid` and `status == 'ended'`). |
| `hostFaculty` | `sessions/{sessionId}` | Set once at session creation; immutable | Enables Index 8 faculty filter without a `get()` on the user document inside rules |
| `hostDisplayName` | `sessions/{sessionId}` | Set once at session creation; immutable | Enables session card to display host name without N+1 `users/` reads |
| `hostPhotoUrl` | `sessions/{sessionId}` | Set once at session creation; immutable | Enables session card to display host avatar without N+1 `users/` reads; nullable pending photo upload feature |
| `noteCount` | `sessions/{sessionId}` | Same `WriteBatch` as each note creation | Required for the 50-note cap check via `getAfter(...)` in rules |

---

## Implementation checklist (Flutter Engineer)

- [ ] `lib/core/firestore_paths.dart` — all path templates as string constants; no Firestore paths elsewhere in the codebase.
- [ ] `firestore.indexes.json` — all 9 indexes declared before any feature goes to production.
- [ ] `firestore.rules` — implement helper functions and all rules exactly as sketched; security reviewer audits before first production deployment.
- [ ] Eight datasource classes — one per path pattern: `users/{uid}`, `sessions/{sessionId}`, `sessions/{sessionId}/messages`, `dms/{dmId}/messages`, `users/{uid}/friends/{friendUid}`, `sessions/{sessionId}/ratings`, `sessions/{sessionId}/notes`, `sessions/{sessionId}/requests`.
- [ ] `WriteBatch` required for: friend request (both directions), rating + profileScore update, note create + `noteCount` increment.
- [ ] `dmId` constructed in `dm_datasource.dart` or `dm_repository_impl.dart` only — never in the presentation layer.
- [ ] `noteCount` incremented atomically with note creation; `sessions` update rule already permits `noteCount` in `hasOnly(...)`.
- [ ] Join request approval must use `WriteBatch`: delete `sessions/{sessionId}/requests/{uid}` + `arrayUnion` uid to `sessions/{sessionId}.memberUids` atomically.
- [ ] `hostDisplayName` and `hostPhotoUrl` read from `users/{hostUid}` once at session creation by `SessionRepositoryImpl`; never written again.

---

## Amendments

### Amendment 1 — Sessions schema additions and join-requests subcollection

- Date: 2026-05-18
- Author: claude-sonnet-4-6 (architect agent), per ADR 0003 Consequences
- Trigger: ADR 0003 (Sessions Feature Architecture) identified five required fields missing from `sessions/{sessionId}` and specified a new `sessions/{sessionId}/requests/{uid}` subcollection for join requests.
- Changes:
  - Added five fields to `sessions/{sessionId}` schema: `location`, `scheduledEndAt`, `capacity`, `hostDisplayName`, `hostPhotoUrl`. Inserted after `scheduledAt` and before `endedAt` in the schema table.
  - Added `sessions/{sessionId}/requests/{uid}` subcollection with schema and Firestore rules.
  - Added Index 9 (`sessions: hostUid asc, scheduledAt desc`) to composite indexes table.
  - Updated `sessions` create rule: `hasAll` extended with `scheduledEndAt`, `location`, `capacity`, `hostDisplayName`; ordering validation `scheduledEndAt > scheduledAt` added; capacity validation `capacity >= 1` added. Note: `hostPhotoUrl` is nullable and excluded from `hasAll` — its absence is valid.
  - Updated `sessions` update rule: `affectedKeys hasOnly` extended with `location`, `scheduledEndAt`, `capacity`; immutability assertions added for `hostDisplayName` and `hostPhotoUrl` (mirroring existing `hostFaculty` immutability pattern).
  - Updated denormalization summary: added `hostDisplayName` and `hostPhotoUrl` rows.
  - Updated implementation checklist: index count 8 → 9; datasource count 7 → 8; added two new checklist items.
- No changes to: Status, Decision paragraph, Constraints, schema for other collections, helper function definitions, or rules for other collections.

