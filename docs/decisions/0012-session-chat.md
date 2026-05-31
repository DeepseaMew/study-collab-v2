# 0012 — Session (Group) Chat Feature Architecture

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-05-31 |
| Architect session | claude-sonnet-4-6 / DeepseaMew / 2026-05-31 |
| Affects | Chat (domain, data, presentation), Firestore schema (ADR 0001 amendment), firestore.rules, firestore.indexes.json, analytics_events.dart, firestore_paths.dart |

---

## Team approval

Approved by:mew
Date: 2026-05-31
Notes:

---

## Problem

ADR 0001 defines a minimal `sessions/{sessionId}/messages/{messageId}` schema that covers only text messages with `readBy` tracking. The schema is insufficient to build a group-chat inbox with unread badges, file-shared message previews, paginated message threads, or a Groups tab in the Messages screen. Five questions are unresolved: (1) how member `groupChats` summary documents are updated on each send without using Cloud Functions (Spark plan); (2) whether `readBy` arrays on individual messages are maintained; (3) how `file_shared` messages written by `NoteRepositoryImpl` expose their `downloadUrl` at render time; (4) which query and index power the Groups tab list; (5) whether the existing `sentAt == request.time` rule is safe on web. The existing `sessions/{sessionId}/messages` create rule also contains `sentAt == request.time` and `readBy == [request.auth.uid]`, both of which must be removed (see ADR 0011: no `== request.time` on web, and SD3 below removes `readBy` entirely).

---

## Constraints

- Domain layer has zero Flutter or Firebase imports (ADR 0001).
- Repository interfaces in `domain/repositories/`; implementations in `data/repositories/`.
- Entities use Freezed; datasource models use Freezed + json_serializable.
- Business logic must not be defined in the presentation layer.
- Cloud Functions unavailable on Spark plan.
- Web: `FieldValue.serverTimestamp()` resolves after rule evaluation — no `== request.time` on any field (ADR 0011).
- Firestore rules must use `diff().affectedKeys()` for field-level write validation (ADR 0001).
- KMUTT email gate enforced in Firestore rules, not only client-side (ADR 0001).
- Every composite index must be justified by a specific feature query (ADR 0001).
- All log calls through `lib/core/logger.dart` only; no PII in logs.
- Every analytics event declared in `lib/core/analytics_events.dart` before use.
- `NoteRepositoryImpl` writes `file_shared` messages; the rules must permit them without a separate rule block.

---

## Options considered

### SD1 — Message send write strategy

| | Option A — Sequential writes | Option B — Cloud Function | Option C — WriteBatch |
|---|---|---|---|
| Summary | `await message.set(...)` then `for each member: await groupChatDoc.update(...)` | Trigger on message create; fan-out server-side | `message.set()` + all `groupChats` updates in one batch |
| Write cost | N+1 round trips; slow for large groups | Zero client writes beyond message | 1 round trip for all writes |
| Offline support | Partial — message lands, previews may lag | N/A (blocked) | Atomic — all land together or none |
| Conflict risk | None | N/A | None — batch writes to `messages/{id}` subcollection and `users/{uid}/groupChats/{sessionId}`; the create rule calls `isMember(sessionId)` which `get()`s `sessions/{sessionId}` — a document the batch does NOT write. No rule-evaluation conflict (contrast ADR 0011 SD3 where the batch wrote the same doc the rule read). |
| Reversal cost | Low — datasource only | N/A | Low — datasource only |
| Recommendation | No | Blocked | Yes |

WriteBatch is safe here because the `isMember(sessionId)` helper reads `sessions/{sessionId}` and the batch writes to `sessions/{sessionId}/messages/{messageId}` (subcollection) and `users/{uid}/groupChats/{sessionId}` (separate collection tree). The batch never writes to `sessions/{sessionId}` itself, so there is no document that is both read by a rule and written in the same batch. This is the critical difference from ADR 0011 SD3, where the batch wrote the same `dms/{dmId}` document that the message create rule also read.

### SD2 — `senderDisplayName` denormalization

Carried forward from ADR 0011 SD5. Denormalized from local auth state at send time, written once on the message document. No options to weigh; staleness is acceptable at MVP since Profile Edit is future work.

### SD3 — `readBy` on messages

| | Option A — Keep `readBy` (set-once, never updated) | Option B — Remove `readBy` |
|---|---|---|
| Summary | Message doc retains `readBy: [senderUid]` at create; never updated after creation | Unread state lives only in `groupChats.unreadCount` |
| Schema cost | Extra list field on every message; grows with backfill risk | None |
| Accuracy | Misleading — array is frozen at create time | Accurate — unread count is the single source of truth |
| Reversal cost | Low — add field back, add update rule | Low — remove field from schema |
| Recommendation | No | Yes |

`readBy` arrays that are never updated after creation are misleading: they imply read receipts but always contain only the sender. Unread state is fully and accurately captured by `groupChats.unreadCount`, which is zeroed by `markSessionRead`. Removing `readBy` reduces per-message storage and eliminates an ambiguous field.

### SD4 — `file_shared` `downloadUrl` resolution

| | Option A — Lazy resolve at render | Option B — Denormalize onto message at write time |
|---|---|---|
| Summary | `noteDownloadUrlProvider(sessionId, noteId)` fetches on tap | `NoteRepositoryImpl` writes `downloadUrl` onto message document |
| Read cost | 1 extra Firestore read per tap | 0 extra reads |
| Write cost | None | 1 extra field in the existing `NoteRepositoryImpl` batch |
| Network sensitivity | Fails silently on slow connections | URL available offline via Firestore cache |
| Reversal cost | Low — remove field from message, add provider | Low — remove provider, remove field |
| Recommendation | No | Yes |

Denormalizing `downloadUrl` onto the message document costs one extra field in the write already performed by `NoteRepositoryImpl`, and eliminates a per-tap Firestore read that matters on slow connections. Firebase Storage download URLs are immutable once written, so the denormalized value never becomes stale. The URL is available from Firestore's offline cache, giving a better experience than a lazy fetch.

### SD5 — Groups tab query

Stream `users/{uid}/groupChats` ordered by `lastMessageAt` desc (Index 12). Zero extra collection reads; the summary documents are already maintained by the send batch.

---

## Decision

Use `WriteBatch` for message send (SD1): one batch writes the message document and all members' `groupChats` summary documents atomically. The batch is safe because the `isMember` rule reads `sessions/{sessionId}` — a document the batch never writes — avoiding the rule-evaluation conflict documented in ADR 0011. Remove `readBy` from message documents (SD3): unread state is owned entirely by `groupChats.unreadCount`, which `markSessionRead` zeroes. Denormalize `downloadUrl` onto `file_shared` messages at write time (SD4) so the Groups tab and chat thread render file messages without extra reads even on poor connections.

---

## Schema

### Amended `sessions/{sessionId}/messages/{messageId}`

Supersedes ADR 0001. Removes `readBy`. Adds `senderDisplayName`, `type`, `noteId`, `fileName`, `downloadUrl`. `sentAt` is server-set but no `== request.time` check (web constraint, ADR 0011).

| Field | Type | Notes |
|---|---|---|
| messageId | String | Doc ID, stored redundantly |
| type | String | `'text'` or `'file_shared'` |
| senderUid | String | Must be in `memberUids` |
| senderDisplayName | String | Denormalized from auth state at send time; immutable |
| text | String? | Non-empty, max 4 000 chars; null for `file_shared` |
| noteId | String? | `file_shared` only |
| fileName | String? | `file_shared` only |
| downloadUrl | String? | `file_shared` only; Firebase Storage URL; immutable |
| sentAt | Timestamp | `serverTimestamp()`; no `== request.time`; immutable |

### New `users/{uid}/groupChats/{sessionId}`

| Field | Type | Notes |
|---|---|---|
| sessionId | String | Matches doc ID |
| sessionTitle | String | Denormalized at group chat creation; updated on session title edit |
| lastMessageText | String? | Preview; truncated to 200 chars |
| lastMessageAt | Timestamp? | `serverTimestamp()` on each send; orders Groups tab |
| unreadCount | int | `FieldValue.increment(1)` for non-senders; zeroed by `markSessionRead` |

---

## Firestore rules

### Amended `sessions/{sessionId}/messages/{messageId}`

Replaces the existing block in `firestore.rules`. Removes `sentAt == request.time` and `readBy`. Adds `senderDisplayName`, `type`, text-size validation, and `file_shared` conditional key check.

```
match /sessions/{sessionId}/messages/{messageId} {
  allow read: if isMember(sessionId);

  allow create: if isMember(sessionId)
    && request.resource.data.senderUid == request.auth.uid
    && request.resource.data.type in ['text', 'file_shared']
    && (
         // text message
         (request.resource.data.type == 'text'
          && request.resource.data.text is string
          && request.resource.data.text.size() > 0
          && request.resource.data.text.size() <= 4000
          && request.resource.data.keys().hasAll([
               'messageId', 'senderUid', 'senderDisplayName',
               'text', 'sentAt', 'type'
             ])
          && request.resource.data.keys().hasOnly([
               'messageId', 'senderUid', 'senderDisplayName',
               'text', 'sentAt', 'type'
             ]))
         ||
         // file_shared — written by NoteRepositoryImpl
         (request.resource.data.type == 'file_shared'
          && request.resource.data.keys().hasAll([
               'messageId', 'senderUid', 'senderDisplayName',
               'type', 'noteId', 'fileName', 'downloadUrl', 'sentAt'
             ])
          && request.resource.data.keys().hasOnly([
               'messageId', 'senderUid', 'senderDisplayName',
               'type', 'noteId', 'fileName', 'downloadUrl', 'sentAt'
             ]))
       );

  allow update: if false;
  allow delete: if false;
}
```

### New `users/{uid}/groupChats/{sessionId}`

Any authenticated KMUTT member of the session may write any member's summary document (needed for fan-out on send). Each user may only read their own.

```
match /users/{uid}/groupChats/{sessionId} {
  allow read: if isKmuttUser()
    && request.auth.uid == uid;

  allow create, update: if isKmuttUser()
    && isMember(sessionId)
    && request.resource.data.keys().hasAll([
         'sessionId', 'sessionTitle', 'unreadCount'
       ])
    && request.resource.data.keys().hasOnly([
         'sessionId', 'sessionTitle', 'lastMessageText',
         'lastMessageAt', 'unreadCount'
       ]);

  allow delete: if isKmuttUser()
    && request.auth.uid == uid;
}
```

`isMember(sessionId)` costs 1 `get()` call. The write path reads no other documents, staying well within the 10-call budget.

---

## Composite index

| # | Collection | Fields | Feature | Collection-group? |
|---|---|---|---|---|
| 12 | `users/{uid}/groupChats` | `lastMessageAt` desc | Groups tab — list ordered by most recent message | No |

Index 4 (`sessions/{sessionId}/messages` ordered by `sentAt` desc) defined in ADR 0001 covers message pagination; no new index needed for the thread.

---

## Analytics events

Declare in `lib/core/analytics_events.dart` before any call site:

- `session_chat_opened`
- `session_chat_message_sent`
- `session_chat_file_message_tapped`
- `groups_tab_viewed`

---

## Consequences

- ADR 0001 `sessions/{sessionId}/messages` schema superseded: `readBy` removed; `type`, `senderDisplayName`, `noteId`, `fileName`, `downloadUrl` added.
- `firestore.rules` `match /sessions/{sessionId}/messages/{messageId}` block replaced in full.
- New `match /users/{uid}/groupChats/{sessionId}` block added to `firestore.rules`.
- `firestore.indexes.json` must add Index 12 before Groups tab deploys.
- `lib/core/firestore_paths.dart` must add path constants for `groupChats` subcollection.
- `NoteRepositoryImpl` must include `downloadUrl` in the `file_shared` message document it writes.
- Send sequence in `SessionChatRemoteDatasource.sendMessage` must use `WriteBatch`: 1 message set + N `groupChats` updates (increment non-senders, set preview for all).
- `markSessionRead` writes only to `users/{uid}/groupChats/{sessionId}.unreadCount = 0`; it does NOT update individual message documents.
- Groups tab streams `users/{uid}/groupChats` ordered by `lastMessageAt` desc using Index 12; filtered client-side by search query.
- `unreadGroupTotalProvider` sums `unreadCount` across all `groupChats` documents for the badge in `MessagesScreen`.

## File list (for Flutter Engineer)

Domain: `features/chat/domain/entities/session_message.dart`, `features/chat/domain/entities/group_chat_summary.dart`, `features/chat/domain/repositories/session_chat_repository.dart`, `features/chat/domain/usecases/send_session_message.dart`, `features/chat/domain/usecases/stream_session_messages.dart`, `features/chat/domain/usecases/stream_group_chat_summaries.dart`, `features/chat/domain/usecases/mark_session_read.dart`

Data: `features/chat/data/models/session_message_model.dart`, `features/chat/data/models/group_chat_summary_model.dart`, `features/chat/data/datasources/session_chat_remote_datasource.dart`, `features/chat/data/repositories/session_chat_repository_impl.dart`

Presentation: `features/chat/presentation/providers/session_chat_providers.dart`, `features/chat/presentation/screens/session_chat_screen.dart`, `features/chat/presentation/widgets/session_message_bubble.dart`, `features/chat/presentation/widgets/group_chat_summary_tile.dart`

Core (amend): `core/analytics_events.dart`, `firestore.rules`, `firestore.indexes.json`

---

## Reversal plan

- **SD1 (WriteBatch → sequential):** Move fan-out loop into `SessionChatRemoteDatasource.sendMessage` as sequential `await` calls; datasource-only change. No schema migration required.
- **SD3 (restore `readBy`):** Add `readBy: [senderUid]` back to message create in datasource; add `allow update` rule for `readBy` append; no backfill needed (old messages simply lack the field).
- **SD4 (lazy `downloadUrl`):** Remove `downloadUrl` from `NoteRepositoryImpl` message write; add `noteDownloadUrlProvider(sessionId, noteId)` provider; add `allow read` path for notes. Requires an amendment ADR and a one-time migration for existing `file_shared` messages that already carry the field (harmless to leave in place).

---

## Related ADRs

- ADR 0001 — Firestore schema baseline; defines `sessions/{sessionId}/messages`, `isMember()`, Index 4.
- ADR 0008 — Note-Sharing; `NoteRepositoryImpl` writes `file_shared` messages.
- ADR 0011 — DM Chat; establishes no-`== request.time` rule, WriteBatch conflict pattern, 10-call `get()` budget.
