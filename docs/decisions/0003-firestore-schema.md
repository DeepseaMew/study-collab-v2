# 0002 — Firestore Schema and Security Rules Design

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
Notes:-

---

## Problem

Study Collab requires a Firestore schema that simultaneously supports six distinct feature areas — user profiles, sessions, friends, chat (DM and group), ratings, and note-sharing — together with a calendar view that aggregates across sessions. No schema exists yet. Without a deliberate decision, individual feature teams will design collections independently, producing schemas that clash on index requirements, make cross-collection security rules unenforceable, or force expensive fan-out writes to satisfy read patterns. Specifically, three structural questions are unresolved: (1) should subcollections be used for session-scoped data (messages, ratings, notes) or should everything be a top-level collection; (2) which fields should be denormalized onto the session document to satisfy calendar queries and Firestore rules in a single read; and (3) which composite indexes are required and what is their collection-group scope. A decision is needed now because the Firestore rules file and the data-layer datasource classes in every feature depend on the path structure chosen here.

---

## Constraints

- Domain layer must have zero Flutter or Firebase imports; all Firestore document paths and collection names are string constants in the data layer only.
- Repository interfaces live in `domain/repositories/`; implementations live in `data/repositories/`. No Firestore types cross this boundary.
- Entities use Freezed; datasource models use Freezed with json_serializable.
- KMUTT email gate (`@mail.kmutt.ac.th` and `@kmutt.ac.th`) must be enforced in Firestore rules via `request.auth.token.email.matches(...)`, not only client-side.
- All timestamp fields must use `request.time` server-side in Firestore rules; no client-generated timestamp may bypass this.
- Firestore rules must use `diff().affectedKeys()` for field-level write validation on every collection and subcollection.
- Users may only read and write their own documents unless their role explicitly permits otherwise.
- Denormalization decisions must be driven by read patterns, not write convenience.
- Every composite index must be justified by a specific feature query.
- Rating writes are online-only; the rules must enforce `status == 'ended'` before a rating document can be created.
- Notes are capped at 50 per session; this cap must be enforced in rules, not only client-side.
- Friendship is bidirectional; both friend documents must be written atomically in a single batch; rules must permit this.
- No PII beyond the fields listed in the schema section below may be stored on any document.
- Business logic must not be defined in the presentation layer.

---

## Options considered

### Option A — Flat top-level collections everywhere

All data lives as top-level Firestore collections: `users`, `sessions`, `friends`, `dms`, `messages` (a single collection for both DM and group messages, distinguished by a `context` field), `ratings`, `notes`. Every document carries a full set of denormalized foreign-key fields (e.g., `sessionId`, `dmId`) so that client-side filters can reconstruct relationships.

**Trade-offs**
- Pro: Every collection is independently queryable without knowing the parent document path; collection-group indexes are trivially available because every collection is already top-level.
- Pro: Firestore Console browsing is straightforward; operators see all messages in one place.
- Con: Security rules for session-scoped data (ratings, notes, messages) must read the parent session document on every access to check membership; this adds one extra document read per rule evaluation, increasing latency and Firestore read cost. Under Firestore's billing model, rule evaluation reads count toward the read quota.
- Con: Mixing DM messages and group messages in a single `messages` collection requires a discriminator field and makes it impossible to set different security rules per context type without awkward `resource.data.context` checks inside the same rules block.
- Con: The `memberUids array-contains` check that drives calendar queries and note-upload permission cannot be evaluated against the session document in a single read when messages and notes live in top-level collections; an additional `get()` call is required inside rules.
- Con: Index namespace is shared; queries must always include enough filter fields to avoid scanning unrelated documents.
- Reversal cost: High. Moving from flat to subcollections requires migrating all existing documents to new paths, rewriting all datasource call sites, regenerating Firestore indexes, and rewriting all security rules. Every feature's `data/datasources/` file is affected.

### Option B — Full subcollection nesting for all session-scoped and user-scoped data

Session-scoped data lives under `sessions/{sessionId}/` as subcollections (`messages`, `ratings`, `notes`). Friend data lives under `users/{uid}/friends/`. DM messages live under `dms/{dmId}/messages/`. The `dms` collection is top-level; its document ID is a deterministic sorted-uid pair (e.g., `uid1_uid2` with `uid1 < uid2` lexicographically). User profiles are top-level at `users/{uid}`.

**Trade-offs**
- Pro: Security rules for session-scoped subcollections inherit the session document path; a single `get(/databases/$(database)/documents/sessions/$(sessionId))` call in a rules function checks membership and status without additional collection complexity.
- Pro: Firestore's subcollection billing and performance characteristics are identical to top-level collections; there is no performance penalty for nesting.
- Pro: Separating DM messages (`dms/{dmId}/messages/`) from group messages (`sessions/{sessionId}/messages/`) allows different security rule blocks with no discriminator field required; DM rules check friend status, group rules check `memberUids`.
- Pro: The 50-note cap can be enforced in rules using `getAfter(...).size()` scoped to the specific `sessions/{sessionId}/notes` subcollection, with no cross-document pollution.
- Con: Cross-session queries on subcollections (e.g., "all ratings for a given rateeUid across all sessions") require a Firestore collection-group index (`collectionGroup('ratings')`). Collection-group indexes must be created explicitly in the Firebase Console or `firestore.indexes.json`.
- Con: Paginated chat queries on group messages and DM messages require separate indexes (one per path pattern) rather than a shared index on a single top-level `messages` collection.
- Con: If a future feature needs to query all notes uploaded by a specific user across all sessions (e.g., a "my uploads" view), it requires a collection-group index on `notes` plus a filter on `uploaderUid`. This index does not exist in the current feature set and would need a new ADR.
- Reversal cost: Moderate. Moving from full subcollections to flat collections is a data migration plus a rules and index rewrite. The domain layer is unaffected because it has no Firestore types. Only `data/datasources/` files and `firestore.rules`/`firestore.indexes.json` change.

### Option C — Hybrid: top-level collections for cross-session queries, subcollections for session-scoped data

Ratings and notes are promoted to top-level collections (`ratings`, `notes`) so that cross-session queries on `rateeUid` and `uploaderUid` do not require collection-group indexes. Messages remain as subcollections (`sessions/{sessionId}/messages/` and `dms/{dmId}/messages/`) because they are never queried across sessions. Friends remain as `users/{uid}/friends/` subcollections. Session and user documents remain top-level.

**Trade-offs**
- Pro: Eliminates the need for collection-group indexes on `ratings` and `notes`, which are the two subcollections most likely to require cross-session queries (profile score calculation, future "my uploads" view).
- Pro: Profile score recalculation can query the top-level `ratings` collection filtered by `rateeUid` without a collection-group index.
- Con: Security rules for top-level `ratings` and `notes` documents must still read the parent session document to verify membership and `status == 'ended'`; the extra `get()` call is unavoidable regardless of where the collection lives. The benefit of subcollection path inheritance is lost for these two collections.
- Con: The 50-note cap in rules becomes harder to enforce on a top-level collection because `getAfter(...).size()` on a top-level collection filtered by `sessionId` is not supported in Firestore rules; the only reliable cap enforcement is via a counter field on the session document or a Cloud Function trigger, both of which add complexity.
- Con: Mixing top-level and subcollection patterns increases cognitive load for the Flutter Engineer; it is not immediately obvious which collections are top-level and which are nested.
- Con: Top-level `ratings` and `notes` collections grow without bound across all sessions; operational index management becomes more complex as the dataset grows.
- Reversal cost: Moderate. If the team later decides to push ratings and notes back to subcollections, the migration affects `data/datasources/ratings_datasource.dart`, `data/datasources/notes_datasource.dart`, `firestore.rules`, and `firestore.indexes.json`. The domain layer is unaffected.

---

## Decision

Option B (full subcollection nesting) is chosen. The read patterns that drive every feature in Study Collab are either scoped to a single session (`messages`, `ratings`, `notes`) or scoped to a single user (`friends`), and subcollections provide security rule inheritance that eliminates extra `get()` calls for the most common access patterns. The one cross-session query that requires a collection-group index — `ratings` filtered by `rateeUid` for profile score calculation — is an infrequent write-triggered operation, not a hot read path, so the index overhead is acceptable. The 50-note cap is enforced cleanly within the `sessions/{sessionId}/notes` subcollection path, which would not be possible under Option C without introducing a counter field. Option A is rejected because shared message and rating collections require discriminator-based rules and extra `get()` calls that degrade both security rule clarity and billing efficiency. Option C is rejected because the cap enforcement problem for notes outweighs the marginal benefit of avoiding the `ratings` collection-group index.

---

## Schema

The following tables define every collection and subcollection. Field names match the Firestore document keys exactly. All timestamp fields are written server-side using `request.time` and must never be set from a client-generated value.

---

### `users/{uid}`

Stores the public profile and aggregate score for each registered user.

| Field | Type | Constraints / Notes |
|---|---|---|
| uid | String | Matches Firebase Auth UID; document ID equals this value |
| displayName | String | Required; non-empty; max 100 characters |
| email | String | Required; must match `@mail.kmutt.ac.th` or `@kmutt.ac.th`; validated in rules |
| photoUrl | String | Nullable; Firebase Storage URL or external avatar URL |
| hasHostedBefore | bool | UI hint only; `false` by default; set to `true` when user creates their first session. Never used as a security gate — per-session host authority is always checked via `sessions/{sessionId}.hostUid`. |
| studentYear | int | Values 1–8; represents undergraduate or graduate year |
| academicLevel | String | Enum: `undergraduate` or `graduate` |
| profileScore | float | Range 0.0–1.0; denormalized percentage of thumbs-up ratings received; updated on each rating write by the rating write path |
| createdAt | Timestamp | Set once on document creation using `request.time`; immutable after creation |
| updatedAt | Timestamp | Updated on every profile write using `request.time` |

No fields beyond the above may be stored on `users/{uid}`. No PII beyond displayName, email, and photoUrl is permitted.

---

### `sessions/{sessionId}`

Stores the authoritative state of a study session. The `memberUids` array is the denormalized membership list used by calendar queries, Firestore rules, and the note-upload cap check.

| Field | Type | Constraints / Notes |
|---|---|---|
| sessionId | String | Firestore auto-generated document ID; stored redundantly for client convenience |
| hostUid | String | UID of the session creator; immutable after creation |
| title | String | Required; non-empty; max 200 characters |
| description | String | Nullable; max 2000 characters |
| hashtags | List\<String\> | Each element is lowercase, free-text; max 20 elements; stored as Firestore array |
| academicLevel | String | Enum: `undergraduate` or `graduate` |
| studentYear | int | Values 1–8 |
| visibility | String | Enum: `public` or `private` |
| pin | String | Nullable; only present when `visibility == 'private'`; min 4 characters; stored in plaintext (not a security secret — access is controlled by rule-level membership check) |
| memberUids | List\<String\> | Array of UIDs of all current members including host; used for array-contains queries in calendar and rules; denormalized |
| status | String | Enum: `scheduled`, `active`, or `ended`; transitions are one-way: scheduled → active → ended |
| scheduledAt | Timestamp | Set by host at session creation; may be updated while `status == 'scheduled'`; written using `request.time` |
| endedAt | Timestamp | Nullable; set by host when session ends; written using `request.time`; immutable once set |
| createdAt | Timestamp | Set once on document creation using `request.time`; immutable |
| updatedAt | Timestamp | Updated on every session write using `request.time` |

---

### `sessions/{sessionId}/messages/{messageId}`

Group chat messages for a specific session. Visible to session members only. History persists after the session ends.

| Field | Type | Constraints / Notes |
|---|---|---|
| messageId | String | Firestore auto-generated document ID; stored redundantly |
| senderUid | String | UID of the message author; must be in `sessions/{sessionId}.memberUids` |
| text | String | Required; non-empty; max 4000 characters |
| sentAt | Timestamp | Set using `request.time` on creation; immutable |
| readBy | List\<String\> | Array of UIDs who have read this message; appended to by each member on read |

Pagination uses `sentAt` descending with `startAfterDocument` cursor. No edit or delete is permitted; messages are append-only.

---

### `dms/{dmId}/messages/{messageId}`

One-on-one direct messages between friends. The `dmId` is deterministic: the two participant UIDs are sorted lexicographically and joined with an underscore (e.g., `uidA_uidB` where `uidA < uidB`). The `dms/{dmId}` parent document stores only metadata; messages are the substantive content.

**`dms/{dmId}` parent document fields:**

| Field | Type | Constraints / Notes |
|---|---|---|
| participantUids | List\<String\> | Exactly two UIDs, sorted; used for security rule lookups and to reconstruct `dmId` from participant UIDs |
| createdAt | Timestamp | Set on first message; written using `request.time` |

**`dms/{dmId}/messages/{messageId}` fields:**

| Field | Type | Constraints / Notes |
|---|---|---|
| messageId | String | Firestore auto-generated document ID; stored redundantly |
| senderUid | String | UID of the message author; must be one of `dms/{dmId}.participantUids` |
| text | String | Required; non-empty; max 4000 characters |
| sentAt | Timestamp | Set using `request.time` on creation; immutable |
| readBy | List\<String\> | Array of UIDs who have read this message |

Friendship status must be confirmed (both `users/A/friends/B.status == 'accepted'` and `users/B/friends/A.status == 'accepted'`) before a DM conversation may be created or a message sent. This check is enforced in Firestore rules. The `dmId` determinism must be enforced in the data-layer repository, not in the UI or domain layer.

---

### `users/{uid}/friends/{friendUid}`

Bidirectional friend relationship. Both `users/A/friends/B` and `users/B/friends/A` must exist. They are written and deleted atomically using Firestore batch writes.

| Field | Type | Constraints / Notes |
|---|---|---|
| friendUid | String | UID of the other party; matches the document ID |
| status | String | Enum: `pending` or `accepted` |
| initiatorUid | String | UID of the user who sent the friend request; used to determine which party can withdraw a pending request |
| createdAt | Timestamp | Set when the friend request is sent; written using `request.time`; immutable |
| updatedAt | Timestamp | Updated when status changes (accept or unfriend); written using `request.time` |

Pending requests are visible to both parties. A `status == 'pending'` document on `users/B/friends/A` (written by A's batch) signals an inbound request to B. Accepting writes `status = 'accepted'` on both documents in a single batch. Unfriending deletes both documents in a single batch.

---

### `sessions/{sessionId}/ratings/{raterUid}`

Thumbs-up or thumbs-down ratings submitted by session members after a session ends. The document ID is the `raterUid`, enforcing one rating per rater per session at the document-path level.

| Field | Type | Constraints / Notes |
|---|---|---|
| raterUid | String | UID of the user submitting the rating; matches the document ID |
| rateeUid | String | UID of the user being rated; must be a member of the session and not equal to `raterUid` |
| liked | bool | `true` = thumbs-up; `false` = thumbs-down |
| ratedAt | Timestamp | Set using `request.time` on creation; immutable |

Creation is only permitted when `sessions/{sessionId}.status == 'ended'`. This check is enforced in Firestore rules. No update is permitted; ratings are immutable once submitted. After each rating write, the data layer must recalculate `profileScore` for `rateeUid` (sum of `liked == true` divided by total ratings for that rateeUid across all sessions, using a collection-group query on `ratings`) and write the result to `users/{rateeUid}.profileScore` in the same batch.

---

### `sessions/{sessionId}/notes/{noteId}`

Files uploaded by session members during or after a session. Capped at 50 per session. No update (edit) is permitted; only create and delete.

| Field | Type | Constraints / Notes |
|---|---|---|
| noteId | String | Firestore auto-generated document ID; stored redundantly |
| uploaderUid | String | UID of the user who uploaded the file; must be in `sessions/{sessionId}.memberUids` |
| fileName | String | Original filename including extension; max 255 characters |
| mimeType | String | MIME type string; validated client-side before upload; stored for display purposes |
| sizeBytes | int | File size in bytes; must be greater than 0 and no greater than 10,485,760 (10 MB) |
| storageRef | String | Firebase Storage path (not a full URL); used to construct the download URL or delete the blob |
| downloadUrl | String | Signed or public Firebase Storage download URL; set at upload time |
| uploadedAt | Timestamp | Set using `request.time` on creation; immutable |

Supported MIME types (validated client-side; `mimeType` field is informational in rules): `image/jpeg`, `image/png`, `image/gif`, `image/webp`, `application/pdf`, `application/msword`, `application/vnd.openxmlformats-officedocument.wordprocessingml.document`, `text/plain`, `application/zip`, `application/x-rar-compressed`, `application/x-7z-compressed`.

The 50-note cap is enforced in rules on the create path. Delete is permitted only to the session host (`sessions/{sessionId}.hostUid`) or the file owner (`uploaderUid`). No update operation is permitted.

---

## Composite index justification

Every index below must be created in `firestore.indexes.json` before deployment. Indexes are listed with collection path, fields and sort order, the feature query that drives them, and whether a collection-group index is required.

---

**Index 1 — Calendar upcoming view**

- Collection path: `sessions`
- Fields: `memberUids` (array-contains), `scheduledAt` (ascending)
- Feature: Calendar screen, "upcoming sessions" tab — query sessions where the current user is a member and `scheduledAt` is in the future, ordered chronologically.
- Collection-group index: No (top-level collection only).

---

**Index 2 — Calendar history view**

- Collection path: `sessions`
- Fields: `memberUids` (array-contains), `status` (ascending equality filter), `endedAt` (descending)
- Feature: Calendar screen, "past sessions" tab — query sessions where the current user is a member and `status == 'ended'`, ordered by most recently ended first.
- Collection-group index: No.

---

**Index 3 — Session search and filtering**

- Collection path: `sessions`
- Fields: `hashtags` (array-contains), `academicLevel` (ascending), `studentYear` (ascending)
- Feature: Search screen — filter public sessions by hashtag, academic level, and student year simultaneously.
- Collection-group index: No.
- Note: Firestore requires a composite index whenever an array-contains filter is combined with additional equality or range filters. Each combination of active search filters that includes `hashtags` must be covered by this index or a subset index. The Flutter Engineer must ensure that the query always includes `hashtags` as the array-contains field when this index is used.

---

**Index 4 — Paginated group chat**

- Collection path: `sessions/{sessionId}/messages`
- Fields: `sentAt` (descending)
- Feature: Session group chat screen — load messages in reverse chronological order with cursor-based pagination using `startAfterDocument`.
- Collection-group index: No (scoped to a single session subcollection; Firestore creates single-field descending indexes automatically, but explicit declaration ensures consistent behavior across SDK versions).

---

**Index 5 — Paginated DM chat**

- Collection path: `dms/{dmId}/messages`
- Fields: `sentAt` (descending)
- Feature: DM conversation screen — load messages in reverse chronological order with cursor-based pagination.
- Collection-group index: No (scoped to a single DM subcollection).

---

**Index 6 — Profile score calculation**

- Collection path: `sessions/{sessionId}/ratings` (collection-group: `ratings`)
- Fields: `rateeUid` (ascending), `ratedAt` (descending)
- Feature: Rating write path — after each rating submission, query all `ratings` documents where `rateeUid` equals the rated user across all sessions, to recalculate and update `users/{rateeUid}.profileScore`.
- Collection-group index: Yes. The query spans all `ratings` subcollections across all sessions.

---

**Index 7 — Notes list in session detail**

- Collection path: `sessions/{sessionId}/notes`
- Fields: `uploadedAt` (descending)
- Feature: Session detail screen, notes tab — list all notes for a session ordered by most recently uploaded first.
- Collection-group index: No (scoped to a single session subcollection).

---

## Firestore security rules sketch

This section is a structured sketch, not a complete `firestore.rules` file. The Flutter Engineer and security reviewer must use this sketch as the authoritative specification when writing the full rules file. Every rule must use `diff().affectedKeys()` for field-level write validation and `request.time` for all timestamp fields.

---

### Helper functions

```
// Returns true if the requesting user is authenticated and their email
// is verified and belongs to a KMUTT domain.
function isKmuttUser() {
  return request.auth != null
    && request.auth.token.email_verified == true
    && request.auth.token.email.matches('.*@(mail\\.kmutt\\.ac\\.th|kmutt\\.ac\\.th)$');
}

// Returns true if the requesting user is the host of the given session.
function isHost(sessionId) {
  return isKmuttUser()
    && get(/databases/$(database)/documents/sessions/$(sessionId)).data.hostUid
       == request.auth.uid;
}

// Returns true if the requesting user is a member of the given session
// (memberUids array contains the user's UID).
function isMember(sessionId) {
  return isKmuttUser()
    && request.auth.uid in
       get(/databases/$(database)/documents/sessions/$(sessionId)).data.memberUids;
}

// Returns true if the given session has status 'ended'.
function sessionEnded(sessionId) {
  return get(/databases/$(database)/documents/sessions/$(sessionId)).data.status
    == 'ended';
}

// Returns true if users A and B are confirmed friends (both directions accepted).
// Call as areFriends(request.auth.uid, otherUid).
function areFriends(uidA, uidB) {
  return get(/databases/$(database)/documents/users/$(uidA)/friends/$(uidB)).data.status
    == 'accepted'
    && get(/databases/$(database)/documents/users/$(uidB)/friends/$(uidA)).data.status
    == 'accepted';
}
```

---

### `users/{uid}` rules

```
match /users/{uid} {
  // Any authenticated KMUTT user may read any profile (for search and session context).
  allow read: if isKmuttUser();

  // Create: only the user themselves; all required fields must be present;
  // email must match the KMUTT domain; timestamps must equal request.time.
  allow create: if isKmuttUser()
    && request.auth.uid == uid
    && request.resource.data.keys().hasAll([
         'uid', 'displayName', 'email', 'hasHostedBefore',
         'studentYear', 'academicLevel', 'profileScore',
         'createdAt', 'updatedAt'
       ])
    && request.resource.data.email.matches('.*@(mail\\.kmutt\\.ac\\.th|kmutt\\.ac\\.th)$')
    && request.resource.data.createdAt == request.time
    && request.resource.data.updatedAt == request.time
    && request.resource.data.hasHostedBefore == false
    && request.resource.data.profileScore == 0.0;

  // Update: owner may update mutable profile fields;
  // diff().affectedKeys() ensures only permitted fields are changed;
  // updatedAt must equal request.time; createdAt and uid are immutable.
  allow update: if isKmuttUser()
    && request.auth.uid == uid
    && request.resource.data.diff(resource.data).affectedKeys()
         .hasOnly(['displayName', 'photoUrl', 'studentYear', 'academicLevel',
                   'hasHostedBefore', 'profileScore', 'updatedAt'])
    && request.resource.data.updatedAt == request.time
    && request.resource.data.uid == resource.data.uid
    && request.resource.data.createdAt == resource.data.createdAt
    && request.resource.data.email == resource.data.email;

  allow delete: if false;
}
```

---

### `sessions/{sessionId}` rules

```
match /sessions/{sessionId} {
  // Any authenticated KMUTT user may read public sessions; members may read private sessions.
  allow read: if isKmuttUser()
    && (resource.data.visibility == 'public'
        || request.auth.uid in resource.data.memberUids);

  // Create: any KMUTT user; all required fields present; hostUid equals caller;
  // memberUids initialized to contain only hostUid; status must be 'scheduled';
  // timestamps must equal request.time.
  allow create: if isKmuttUser()
    && request.resource.data.hostUid == request.auth.uid
    && request.resource.data.memberUids == [request.auth.uid]
    && request.resource.data.status == 'scheduled'
    && request.resource.data.createdAt == request.time
    && request.resource.data.updatedAt == request.time
    && request.resource.data.keys().hasAll([
         'sessionId', 'hostUid', 'title', 'hashtags', 'academicLevel',
         'studentYear', 'visibility', 'memberUids', 'status',
         'scheduledAt', 'createdAt', 'updatedAt'
       ]);

  // Update: host only; restricted mutable fields; status may only advance forward;
  // updatedAt must equal request.time; hostUid and createdAt are immutable.
  allow update: if isHost(sessionId)
    && request.resource.data.diff(resource.data).affectedKeys()
         .hasOnly(['title', 'description', 'hashtags', 'academicLevel',
                   'studentYear', 'visibility', 'pin', 'memberUids',
                   'status', 'scheduledAt', 'endedAt', 'updatedAt'])
    && request.resource.data.updatedAt == request.time
    && request.resource.data.hostUid == resource.data.hostUid
    && request.resource.data.createdAt == resource.data.createdAt;

  // Delete: host only; only when status is 'scheduled' (not active or ended).
  allow delete: if isHost(sessionId)
    && resource.data.status == 'scheduled';
}
```

---

### `sessions/{sessionId}/messages/{messageId}` rules

```
match /sessions/{sessionId}/messages/{messageId} {
  // Members may read all messages; history persists after session ends.
  allow read: if isMember(sessionId);

  // Create: sender must be a member; senderUid must equal caller;
  // sentAt must equal request.time; readBy initialized to [senderUid].
  allow create: if isMember(sessionId)
    && request.resource.data.senderUid == request.auth.uid
    && request.resource.data.sentAt == request.time
    && request.resource.data.readBy == [request.auth.uid]
    && request.resource.data.keys().hasAll([
         'messageId', 'senderUid', 'text', 'sentAt', 'readBy'
       ]);

  // Update: only readBy may be appended to (members marking as read).
  allow update: if isMember(sessionId)
    && request.resource.data.diff(resource.data).affectedKeys()
         .hasOnly(['readBy'])
    && request.auth.uid in request.resource.data.readBy;

  allow delete: if false;
}
```

---

### `dms/{dmId}` and `dms/{dmId}/messages/{messageId}` rules

```
match /dms/{dmId} {
  // Only participants may read the DM metadata document.
  allow read: if isKmuttUser()
    && request.auth.uid in resource.data.participantUids;

  // Create: caller must be one of the two participants; both must be confirmed friends;
  // participantUids must be exactly two elements; createdAt must equal request.time.
  allow create: if isKmuttUser()
    && request.auth.uid in request.resource.data.participantUids
    && request.resource.data.participantUids.size() == 2
    && areFriends(request.resource.data.participantUids[0],
                  request.resource.data.participantUids[1])
    && request.resource.data.createdAt == request.time;

  allow update: if false;
  allow delete: if false;

  match /messages/{messageId} {
    // Both participants may read messages.
    allow read: if isKmuttUser()
      && request.auth.uid in
         get(/databases/$(database)/documents/dms/$(dmId)).data.participantUids;

    // Create: sender must be a participant and confirmed friend of the other party;
    // sentAt must equal request.time.
    allow create: if isKmuttUser()
      && request.auth.uid in
         get(/databases/$(database)/documents/dms/$(dmId)).data.participantUids
      && request.resource.data.senderUid == request.auth.uid
      && request.resource.data.sentAt == request.time
      && request.resource.data.keys().hasAll([
           'messageId', 'senderUid', 'text', 'sentAt', 'readBy'
         ]);

    // Update: only readBy may be appended to.
    allow update: if isKmuttUser()
      && request.auth.uid in
         get(/databases/$(database)/documents/dms/$(dmId)).data.participantUids
      && request.resource.data.diff(resource.data).affectedKeys()
           .hasOnly(['readBy']);

    allow delete: if false;
  }
}
```

---

### `users/{uid}/friends/{friendUid}` rules

```
match /users/{uid}/friends/{friendUid} {
  // Owner or the referenced friend may read.
  allow read: if isKmuttUser()
    && (request.auth.uid == uid || request.auth.uid == friendUid);

  // Create: the document owner (uid) initiates; both directions are written in
  // a single batch by the client. Rules permit the initiator to write their own
  // document; the batch also writes the mirror document under the other user's
  // path, which is permitted because the other user's friends/{uid} create rule
  // allows writes where the document owner is the friendUid of the current caller.
  allow create: if isKmuttUser()
    && (request.auth.uid == uid || request.auth.uid == friendUid)
    && request.resource.data.friendUid == friendUid
    && request.resource.data.status == 'pending'
    && request.resource.data.createdAt == request.time
    && request.resource.data.updatedAt == request.time
    && request.resource.data.keys().hasAll([
         'friendUid', 'status', 'initiatorUid', 'createdAt', 'updatedAt'
       ]);

  // Update: only status and updatedAt may change; updatedAt must equal request.time.
  // The accepting user (friendUid of the pending request, i.e., not the initiator)
  // may set status to 'accepted'. Both documents are updated in a single batch.
  allow update: if isKmuttUser()
    && (request.auth.uid == uid || request.auth.uid == friendUid)
    && request.resource.data.diff(resource.data).affectedKeys()
         .hasOnly(['status', 'updatedAt'])
    && request.resource.data.updatedAt == request.time;

  // Delete: either party may delete (unfriend); both documents deleted in one batch.
  allow delete: if isKmuttUser()
    && (request.auth.uid == uid || request.auth.uid == friendUid);
}
```

---

### `sessions/{sessionId}/ratings/{raterUid}` rules

```
match /sessions/{sessionId}/ratings/{raterUid} {
  // Members may read ratings for a session.
  allow read: if isMember(sessionId);

  // Create: session must be ended; raterUid must equal caller; ratee must differ
  // from rater; ratedAt must equal request.time; no update allowed (immutable).
  allow create: if isMember(sessionId)
    && sessionEnded(sessionId)
    && request.auth.uid == raterUid
    && request.resource.data.raterUid == raterUid
    && request.resource.data.rateeUid != raterUid
    && request.resource.data.ratedAt == request.time
    && request.resource.data.keys().hasAll([
         'raterUid', 'rateeUid', 'liked', 'ratedAt'
       ]);

  allow update: if false;
  allow delete: if false;
}
```

---

### `sessions/{sessionId}/notes/{noteId}` rules

```
match /sessions/{sessionId}/notes/{noteId} {
  // Members may read notes; persists after session ends.
  allow read: if isMember(sessionId);

  // Create: uploader must be a member; uploaderUid must equal caller;
  // uploadedAt must equal request.time; sizeBytes must be > 0 and <= 10485760;
  // note count after write must not exceed 50.
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

  // No update (edit) is permitted.
  allow update: if false;

  // Delete: host or the file owner only.
  allow delete: if isKmuttUser()
    && (isHost(sessionId) || request.auth.uid == resource.data.uploaderUid);
}
```

Note: The cap check using `getAfter(...)` requires the session document to maintain a `noteCount` integer field that is incremented atomically in the same batch as the note create. Alternatively, the cap may be enforced with a Cloud Function trigger if `getAfter` on the parent document proves unreliable. The Flutter Engineer must confirm which mechanism is used and ensure atomicity. If a `noteCount` field is added to `sessions/{sessionId}`, the update rule for sessions must add `noteCount` to the `hasOnly(...)` permitted field list.

---

## Denormalization decisions

### `memberUids` on `sessions/{sessionId}`

- What is duplicated: the full list of member UIDs is stored directly on the session document rather than derived from a subcollection.
- Where it lives: `sessions/{sessionId}.memberUids` (a Firestore array field).
- What triggers an update: any join, leave, or host-approval event writes a new `memberUids` array to the session document. These writes occur through the session repository's join/leave methods.
- Why it exists: Firestore does not support server-side joins. The calendar queries (`memberUids array-contains uid`) and the note-upload cap check require membership to be verifiable in a single document read. Security rules for subcollections (`ratings`, `notes`, `messages`) also call `isMember(sessionId)` which performs one `get()` on the session document; if membership were stored in a subcollection, the rules function would require an additional query that is not supported in Firestore rules.
- Staleness risk: low. Membership changes are infrequent (join/leave events) and are always written by the affected user or the host. The array is the source of truth; no background sync is required.
- Write-limit consideration: Firestore enforces a 1-write-per-second sustained limit per document path. If many users join a session simultaneously, the `memberUids` array on the session document becomes a write hotspot. For Study Collab's expected scale (university study groups, not thousands of concurrent joins), this limit is not a practical concern. If session size grows, the team must revisit this with a new ADR.

### `profileScore` on `users/{uid}`

- What is duplicated: the aggregate rating result (total liked / total ratings) is stored on the user document rather than computed on every profile read.
- Where it lives: `users/{uid}.profileScore` (a float in range 0.0–1.0).
- What triggers an update: every time a rating document is created in `sessions/{sessionId}/ratings/{raterUid}`, the data layer performs a collection-group query on `ratings` filtered by `rateeUid == rateeUid`, counts the results and the liked subset, computes the new score, and writes it to `users/{rateeUid}.profileScore` in the same Firestore batch as the rating creation.
- Why it exists: computing the profile score on every profile read would require a collection-group query on `ratings` at read time, adding latency to every profile screen load and incurring additional Firestore read costs proportional to the number of sessions the user has participated in.
- Staleness risk: one rating event. The score visible on the profile screen lags by at most the duration of the batch write that creates the rating and updates the score. In practice this is sub-second. No background job or scheduled function is required.
- Transactional requirement: the rating creation and the profileScore update must be in the same Firestore batch write. If the batch fails, neither the rating nor the score update is committed. The use case must handle batch failure with a typed `AppError` from `lib/core/errors/`.

### `dmId` determinism (not a denormalized field, but a data-layer contract)

- The `dmId` for a DM conversation between users A and B is always constructed as `min(uidA, uidB) + '_' + max(uidA, uidB)` using lexicographic comparison.
- This construction must be performed in `data/datasources/dm_datasource.dart` or `data/repositories/dm_repository_impl.dart`, never in the presentation layer or a Riverpod provider.
- The domain entity for a DM conversation must not expose the raw `dmId` string; it should expose the two participant UIDs and let the data layer construct the path.

---

## Consequences

- The Flutter Engineer must implement datasource classes for seven distinct path patterns: `users/{uid}`, `sessions/{sessionId}`, `sessions/{sessionId}/messages/{messageId}`, `dms/{dmId}/messages/{messageId}`, `users/{uid}/friends/{friendUid}`, `sessions/{sessionId}/ratings/{raterUid}`, and `sessions/{sessionId}/notes/{noteId}`. Each datasource is a separate class in its feature's `data/datasources/` directory.
- All Firestore document paths are string constants; the domain layer never references a Firestore path. A `FirestorePaths` constants class in `lib/core/` (data layer accessible) must define all path templates.
- The `firestore.indexes.json` file must define all seven composite indexes listed above before any feature goes to production; Firestore does not automatically create composite indexes for new query patterns.
- The `firestore.rules` file must implement all helper functions and per-collection rules exactly as sketched; the security reviewer must audit the final rules file against this ADR before the first production deployment.
- Adding `noteCount` to the session document (required by the notes cap enforcement) means the session update rule must explicitly permit `noteCount` in its `diff().affectedKeys().hasOnly(...)` list; this is a coupling between the notes feature and the sessions rules block.
- The batch-write requirement for friend operations (both directions atomically) and for rating + profileScore (rating creation + score update atomically) means the repository implementations for these features must use `WriteBatch`, not individual `set`/`update` calls.
- Collection-group index on `ratings` (Index 6) means that any future feature querying across all sessions' ratings (e.g., a leaderboard) can reuse this index if the query fields match.
- The `dmId` determinism contract is enforced in the data layer; if the UI layer ever constructs a `dmId` directly, it will introduce a hard-to-detect duplication bug (two DM documents for the same pair of users). This rule must be documented in code comments on the DM datasource.
- Message history persists after a session ends; the rules for `sessions/{sessionId}/messages` do not gate on `status`. The team must decide whether to surface a UI-level "session ended" indicator in the chat screen rather than removing message access.
- Firestore's 1-document-per-second write limit applies to `memberUids` updates on session documents. For current expected usage this is not a constraint, but any future "instant join" flow that could trigger many simultaneous writes must be reviewed.

---

## Reversal plan

If the team determines that Option B (full subcollection nesting) is wrong and wants to move to Option A (flat top-level collections) or Option C (hybrid):

1. A new ADR is written by the architect, referencing this record. This record's Status is updated to "Superseded by NNNN".
2. A data migration script (in `tools/`) exports all subcollection documents to their new top-level paths. The migration must run in a staging environment first and be reviewed by the security reviewer before production.
3. All `data/datasources/` files for the affected features (ratings, notes, group messages) are rewritten to use the new top-level collection paths.
4. `firestore.rules` is rewritten to replace subcollection path matchers with top-level path matchers and to add discriminator-field checks where needed.
5. `firestore.indexes.json` is regenerated; collection-group indexes on `ratings` and `notes` become standard single-collection indexes.
6. The domain layer and entities are unaffected because they contain no Firestore paths or types.
7. The QA engineer re-runs the full test matrix against the new paths before the migration is considered complete.
8. The release engineer cuts a new app version that targets the new collection paths; the old paths must remain readable (not deleted) until the migration is confirmed complete and the old app version is no longer in use.
