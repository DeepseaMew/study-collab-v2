# 0008 — Note-Sharing Feature Architecture

| Field | Value |
|---|---|
| Status | Approved |
| Date | 2026-05-23 |
| Architect session | claude-sonnet-4-6 / NichapaJongKmutt / 2026-05-23 |
| Affects | Note-Sharing (domain, data, presentation), sessions presentation screens (ADR 0003 amendment), Firebase Storage rules (ADR 0005 amendment), Firestore rules (ADR 0001 amendment), core/analytics_events.dart, core/firestore_paths.dart, core/storage_paths.dart, pubspec.yaml |

---

## Team approval

Approved by: Film
Date: 2026-05-23
Notes: <!-- conditions or concerns, leave blank if none -->

---

## Problem

The Session detail screens established in ADR 0003 include a "Notes" tab (present in both `MemberSessionDetailScreen` and `HostSessionDetailScreen`) whose content was explicitly deferred. ADR 0001 defines the Firestore schema for `sessions/{sessionId}/notes/{noteId}` and the associated security rules, but stops short of specifying the feature's upload pipeline, Storage path layout, state management architecture, feature flag strategy, and tab routing. Before a Flutter Engineer begins any file, the team needs authoritative answers to five questions.

(1) Where in Firebase Storage should uploaded note files live, and how should the path be scoped so that Storage rules can enforce KMUTT-only access without calling Firestore from within Storage rules (which is not supported)?

(2) Should files be uploaded directly from the client using the `firebase_storage` SDK, or via a Cloud Function intermediary that validates and re-stores server-side? The answer determines latency, offline behavior, orphan-cleanup responsibility, and what the Storage rules need to enforce independently of Firestore rules.

(3) How should the note list be loaded given the 50-note cap? A paginated approach adds UI complexity for a collection that is already bounded; an unbounded stream risks future read waste if the cap is raised.

(4) How should the feature flag be implemented so that note-sharing can be toggled off without cutting a new release, per the stated requirement?

(5) Should the "Files" tab be a tab within the existing detail screens from ADR 0003, a separate pushed route, or a modal? And how does GoRouter expose an entry point to it?

Without answers to all five, engineers will make incompatible choices about Storage path layout, upload sequencing (Firestore-before-Storage vs. Storage-before-Firestore), cleanup on failure, feature flag placement, and routing. ADR 0001 also contains two gaps exposed by this feature: the sessions update rule allows only the host to modify `noteCount`, yet any member can upload a note; and the notes schema does not include a denormalized `uploaderDisplayName`, forcing either N+1 user-document reads or silent omission of the uploader identity in the UI. Both gaps must be closed before implementation begins.

---

## Constraints

- Domain layer has zero Flutter or Firebase imports; all Firestore path strings are constants in `lib/core/firestore_paths.dart` and all Firebase Storage path strings are constants in `lib/core/storage_paths.dart` (established by ADR 0005).
- `NoteUploadParams.bytes` uses `Uint8List` from `dart:typed_data`, which is a Dart SDK core library with no Flutter or Firebase dependency. This is the only non-pure-Dart type permitted in the domain entity layer for this feature; it does not violate the domain isolation rule.
- Repository interfaces in `domain/repositories/`; implementations in `data/repositories/`; no Firestore or Firebase Storage types cross the domain boundary.
- Entities use Freezed; datasource models use Freezed + json_serializable.
- All Riverpod providers use `@riverpod` codegen (riverpod_generator); no hand-written `StateNotifier`.
- Business logic (MIME validation, size validation) must not be defined in the presentation layer; it belongs in the use case.
- No provider may access Firestore or Firebase Storage directly; all access goes through the repository layer.
- Firestore rules for `sessions/{sessionId}/notes/{noteId}` are defined in ADR 0001; this ADR amends them only to add `uploaderDisplayName` to the `hasAll` list. The `noteCount` cap check (`getAfter(...)`) and delete authorization are unchanged.
- The sessions update rule in ADR 0001 is amended by this ADR to allow any session member to update `noteCount` by exactly ±1 (needed for note create and delete `WriteBatch`es by non-host members).
- The `noteCount` field on the session document must be incremented atomically with note creation and decremented atomically with note deletion, both in `WriteBatch`es as specified in ADR 0001.
- Maximum file size is 10 MB (10,485,760 bytes); enforced in Firestore rules (ADR 0001), Storage rules (this ADR), and client-side in the use case layer.
- Supported MIME types are fixed: `image/jpeg`, `image/png`, `image/gif`, `image/webp`, `application/pdf`, `application/msword`, `application/vnd.openxmlformats-officedocument.wordprocessingml.document`, `text/plain`, `application/zip`, `application/x-rar-compressed`, `application/x-7z-compressed`. Validated in the use case before upload; also enforced in Storage rules.
- Delete permission: session host or file owner only. Enforced in Firestore rules (ADR 0001). Storage delete must only be attempted after the corresponding Firestore document and `noteCount` decrement `WriteBatch` has successfully committed.
- Notes persist after the session ends; the session `status` field does not gate reads or writes on the notes subcollection.
- Visibility is session members only; enforced in Firestore rules via `isMember(sessionId)` (ADR 0001).
- KMUTT email gate (`@mail.kmutt.ac.th` / `@kmutt.ac.th`) is enforced in Firestore rules (ADR 0001); Storage rules enforce the same gate via `request.auth.token.email.matches(...)`.
- All remote images (image-type note files) must render through `cached_network_image`; never `Image.network` directly.
- No unbounded `ListView`; always `ListView.builder` with `itemCount`.
- All log calls go through `lib/core/logger.dart` only; never `print()`. No PII in any log message or Crashlytics custom key.
- Every analytics event declared in `lib/core/analytics_events.dart` before use.
- The note-sharing UI must be gated behind a feature flag (`note_sharing_enabled`) so it can be disabled server-side without a new release. When the flag is `false`, the "Files" tab renders a "Coming soon" placeholder; the tab itself remains visible to preserve ADR 0003's tab structure.
- Domain errors for this feature are sealed subclasses of a new `NoteError` class in `lib/core/errors/note_error.dart`.
- `firebase_storage` is already a declared dependency per ADR 0001 Amendment 3; no second declaration is needed.
- Index 7 (`sessions/{sessionId}/notes` ordered by `uploadedAt` desc) is already defined in ADR 0001; no new Firestore composite index is required.
- `SessionEntity` is shared from `lib/features/sessions/domain/entities/session_entity.dart` (ADR 0003); it must not be duplicated in the note-sharing feature.

---

## Options considered

### Sub-decision 1 — Firebase Storage path structure for notes

| | Option A — `sessions/{sessionId}/notes/{noteId}` | Option B — `sessions/{sessionId}/notes/{uploaderUid}/{noteId}/{fileName}` | Option C — `notes/{noteId}` |
|---|---|---|---|
| Summary | Flat path keyed by the Firestore-auto-generated `noteId`; mirrors the Firestore subcollection path exactly | Includes `uploaderUid` directory and original file name; enables per-uploader sub-folder in Storage | Top-level flat path; no session hierarchy |
| Storage rule scoping | `sessionId` available as a wildcard; rules can scope to session without a Firestore `get()` call | `sessionId` still available but nested wildcards add complexity | No session context; cannot scope by session in Storage rules |
| Path derivation | `storageRef` stored in Firestore equals path verbatim; no reconstruction needed | Same but three wildcards must be tracked | Same |
| Orphan reconciliation | One Storage object per `noteId`; easy to reconcile with the Firestore document | Same | No session link; harder to reconcile |
| Reversal cost | Low — change confined to `storage_paths.dart` and `note_datasource.dart` | Low | Low |
| Recommendation | Yes | No | No |

Option A mirrors the Firestore subcollection path, keeps Storage rules to two wildcards, and allows the `storageRef` field to be the canonical Storage path. The `uploaderUid` sub-folder in Option B adds indirection without benefit: delete authorization is already enforced by Firestore rules (host or owner), and Storage rules do not need to know the uploaderUid separately. Option C loses all session scoping in Storage rules.

---

### Sub-decision 2 — File upload strategy

| | Option A — Direct `firebase_storage` SDK upload from client | Option B — Cloud Function intermediary (validate + store server-side) | Option C — Pre-signed URL from Cloud Function |
|---|---|---|---|
| Summary | Client reads bytes via `file_picker`, validates MIME and size in the use case, uploads to Storage, then commits a Firestore `WriteBatch` (note document + `noteCount` increment) | Client sends raw bytes to a Cloud Function; Function validates, stores to Storage, and writes Firestore atomically | Client requests a short-lived signed URL from a Cloud Function; uploads directly to that URL; Function writes Firestore on a Cloud Storage trigger |
| Server-side enforcement | Firestore rules + Storage rules (MIME type, size, KMUTT auth) | Cloud Function code; Storage rules can be locked to Function service account | Partial — URL is pre-scoped by Function; Storage trigger handles Firestore write |
| Upload latency | One network hop (client → Storage) | Two hops (client → Function → Storage) + cold-start risk | Two hops (client → Function for URL; client → Storage) + cold-start risk |
| Offline behavior | SDK queues upload task; resumes when connectivity returns | No offline support | No offline support |
| Orphan cleanup responsibility | Data layer: delete Storage file if Firestore `WriteBatch` fails | Function handles both; no orphan risk | Trigger-based; orphan possible if trigger fails |
| Infrastructure cost | Storage only (free tier, 5 GB total per ADR 0001) | Storage + Cloud Function invocations | Storage + Cloud Function invocations |
| Reversal cost | Low — replace SDK call in `note_datasource.dart` | High — remove Function, replace all call sites | Medium |
| Recommendation | Yes | No | No |

Direct SDK upload is recommended. `firebase_storage` is already a declared dependency. Firestore rules and Storage rules together enforce all server-side constraints (KMUTT auth, MIME type, file size, membership, 50-note cap) without Cloud Function overhead. Cloud Functions add latency, cold-start risk, and infrastructure cost that is not justified for a free-tier 5 GB Storage budget at MVP. The data layer handles the orphan cleanup case: if the Firestore `WriteBatch` fails after a successful Storage upload, the data layer deletes the orphan Storage object before re-throwing the error.

---

### Sub-decision 3 — Note list loading strategy

| | Option A — Single stream of all notes (max 50) | Option B — Paginated cursor (limit 20, load-more) | Option C — Future-based load-once |
|---|---|---|---|
| Summary | One `@riverpod` stream provider watching the full `notes` subcollection ordered by `uploadedAt` desc; bounded by the 50-note cap | Stream 20 documents at a time; notifier maintains cursor state and exposes `fetchMore()` | `FutureProvider` that loads notes once when the tab is first opened; no live updates |
| Max Firestore reads per session open | ≤ 50 document reads | ≤ 20 per page | ≤ 50, once |
| Live updates | Yes — new uploads and deletes reflect immediately without a refresh | Yes for page 1; later pages re-queried on scroll | No |
| Implementation complexity | Low | Medium — cursor state, page merge, load-more button | Low |
| Reversal cost | Low — add cursor and load-more button to provider if cap is raised | Low | Low — add stream |
| Recommendation | Yes | No | No |

A single stream is recommended. The 50-note cap bounds the collection to a known small maximum; the cost of streaming all documents is equivalent to one Firestore page. Live updates are important in a collaborative session: a participant who uploads a file should see it reflected immediately in all members' tabs without a manual refresh. Pagination adds state management complexity for no benefit at this scale.

---

### Sub-decision 4 — Feature flag mechanism

| | Option A — Firebase Remote Config boolean `note_sharing_enabled` | Option B — Firestore document `config/feature_flags.noteSharing` | Option C — Compile-time constant |
|---|---|---|---|
| Summary | Boolean flag fetched from Firebase Remote Config; cached locally with a 12-hour minimum fetch interval in production; toggled from Firebase Console without a new build | Single Firestore document holding all feature flags; read on app startup; real-time stream if needed | `const bool kNoteSharingEnabled` in code; requires a code change and new release to toggle |
| Toggle without release | Yes | Yes | No — violates stated requirement |
| Fetch latency | ~100 ms on first launch; subsequent launches use cached value | One Firestore read on startup | N/A |
| Infrastructure | Remote Config free tier | Firestore read per app launch | None |
| Offline default | Falls back to last cached value; `false` on first launch (safe-off-by-default) | Falls back to Firestore offline cache | Always the compiled value |
| Reversal cost | Low — replace `RemoteConfig.getBool` call in the flag service with a constant | Low | N/A |
| Recommendation | Yes | No | No |

Firebase Remote Config is recommended. It allows the feature to be toggled server-side without a release, satisfying the stated requirement. The Firestore option adds a read on every app launch and requires either polling or a real-time stream to propagate changes. Option C violates the requirement entirely. Remote Config's `false` default on first launch (before the first fetch resolves) means note-sharing is safe-off until explicitly enabled in the console.

---

### Sub-decision 5 — Tab integration and GoRouter routing

| | Option A — "Files" tab within existing `TabController` of ADR 0003 screens | Option B — Separate GoRouter route `/sessions/:id/files` pushed from session detail | Option C — Bottom sheet or modal |
|---|---|---|---|
| Summary | The "Notes" tab allocated by ADR 0003 in `MemberSessionDetailScreen` (tab index 1) and `HostSessionDetailScreen` (tab index 1) is renamed "Files" and its content is defined by this ADR; GoRouter navigates to the existing route with `initialTabIndex: 1` in `extra` | A new screen pushed via GoRouter; session detail shows a "Files" card or button that calls `context.push('/sessions/$id/files')` | Files list in a `DraggableScrollableSheet`; triggered from a button in the session detail |
| ADR 0003 alignment | Directly implements the deferred "Notes" tab slot; no structural change to existing screens | Bypasses ADR 0003's tab layout; requires amending ADR 0003's route table | Bypasses the tab structure entirely |
| Deep-linkable | Yes — via `extra: {'initialTabIndex': 1}` on existing routes | Yes — via its own route constant | No |
| Tab count stability with feature flag | Tab stays visible (renders placeholder when flag is off); no index-shift on flag toggle | N/A | N/A |
| Implementation effort | Low — extends existing screens with one `TabBarView` child | Medium — new screen, new route constant, route wiring | Low |
| Reversal cost | Low — change tab content; no route changes | Low | Low |
| Recommendation | Yes | No | No |

Option A is recommended. ADR 0003 explicitly allocated the "Notes" tab slot in both detail screens; this ADR defines what fills that slot. Keeping the tab always visible (with a placeholder when the flag is off) avoids a tab-count change that would shift the index of subsequent tabs (e.g., "Requests" in `HostSessionDetailScreen`) depending on a remote value. GoRouter navigates to the existing detail screen routes with `extra: {'initialTabIndex': 1}`, enabling direct entry from the calendar, a notification, or a share link. A separate pushed route (Option B) would require amending ADR 0003's route table and creates an inconsistent UX pattern. A bottom sheet (Option C) is not deep-linkable and does not match the app's screen navigation model.

---

## Decision

The Note-Sharing feature implements the "Notes" tab deferred by ADR 0003 in both `MemberSessionDetailScreen` and `HostSessionDetailScreen`, renaming the tab label to "Files" without changing the tab index or route structure.

Sub-decision 1: Firebase Storage path is `sessions/{sessionId}/notes/{noteId}`, where `noteId` is the Firestore auto-generated document ID. The constant is declared in `lib/core/storage_paths.dart`. The `storageRef` field on the Firestore note document stores this path verbatim.

Sub-decision 2: Files are uploaded directly from the client using the `firebase_storage` SDK. `file_picker` provides file bytes as `Uint8List`. MIME type and file size are validated in `UploadNoteUseCase` before any network call. Storage rules enforce KMUTT authentication, file size ≤ 10 MB, and allowed MIME types independently of Firestore rules. The upload sequence is: (a) validate client-side, (b) upload bytes to Storage and obtain the download URL, (c) commit a Firestore `WriteBatch` containing the note document and the `noteCount` increment on the session. If the `WriteBatch` fails after a successful Storage upload, the data layer deletes the orphan Storage object before re-throwing a `NoteError.uploadFailed`.

Sub-decision 3: A single `@riverpod` auto-dispose stream provider watches all notes in the subcollection ordered by `uploadedAt` desc, using Index 7 from ADR 0001. No pagination is introduced. The 50-note cap bounds the collection to a known small maximum.

Sub-decision 4: The feature flag `note_sharing_enabled` is read from Firebase Remote Config. The flag defaults to `false` on first launch before any fetch resolves. When the flag is `false`, the "Files" tab renders a "Coming soon" banner; the tab remains visible at its fixed index to prevent tab-count instability across flag states.

Sub-decision 5: GoRouter navigates to the existing detail screen routes (ADR 0003) with `extra: {'initialTabIndex': 1}` to open directly at the Files tab. No new routes are added.

Two ADR 0001 gaps are closed by amendments in the Consequences section: (a) the sessions update rule is extended to allow any session member to update `noteCount` by ±1 (needed for non-host member upload and delete `WriteBatch`es); (b) `uploaderDisplayName` is added to the `sessions/{sessionId}/notes/{noteId}` Firestore schema and Storage rules, denormalized from `users/{uploaderUid}.displayName` at upload time by `NoteRepositoryImpl`.

---

## Consequences

### Required ADR 0001 amendments

#### Amendment A — `sessions/{sessionId}/notes/{noteId}` schema addition

Add `uploaderDisplayName` to the schema table after `uploaderUid`:

| Field | Type | Constraints / Notes |
|---|---|---|
| `uploaderDisplayName` | String | Denormalized from `users/{uploaderUid}.displayName` at upload time by `NoteRepositoryImpl`; required non-empty; max 100 characters |

Update the `sessions/{sessionId}/notes/{noteId}` Firestore create rule: extend `keys().hasAll(...)` to include `'uploaderDisplayName'`:

```
&& request.resource.data.keys().hasAll([
     'noteId', 'uploaderUid', 'uploaderDisplayName', 'fileName', 'mimeType',
     'sizeBytes', 'storageRef', 'downloadUrl', 'uploadedAt'
   ])
```

#### Amendment B — Sessions update rule: allow members to modify `noteCount`

Replace the sessions update rule with a two-condition block. The first condition (host) is unchanged from ADR 0001. The second condition (member) allows updating only `noteCount` by exactly ±1:

**Cap enforcement interaction:** The `noteCount <= 50` cap is enforced at the `sessions/{sessionId}/notes/{noteId}` **create** rule via `getAfter(...)` (defined in ADR 0001), not at the sessions update rule. The sessions update rule (this amendment) validates only that the delta is exactly ±1 and that `noteCount` remains non-negative. If a member attempts to upload a note when `noteCount` is already 50, the session `noteCount` increment to 51 would satisfy this update rule, but the note document create rule would fail (because `getAfter(...).data.noteCount` would equal 51, exceeding the cap). Firestore executes the WriteBatch atomically: if any document write in the batch fails, the entire batch is rolled back. The Flutter Engineer must not add a client-side `noteCount >= 50` guard that short-circuits before the batch — the Firestore rule is the authoritative enforcement point, and the use case should surface `NoteError.sessionCapReached` by catching the `permission-denied` response from Firestore when the batch fails due to the cap.

```
match /sessions/{sessionId} {
  // ... read, create, delete rules unchanged ...

  allow update: if
    (isHost(sessionId)
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
      && request.resource.data.createdAt == resource.data.createdAt)
    || (isMember(sessionId)
      && request.resource.data.diff(resource.data).affectedKeys()
           .hasOnly(['noteCount'])
      && (request.resource.data.noteCount == resource.data.noteCount + 1
          || request.resource.data.noteCount == resource.data.noteCount - 1)
      && request.resource.data.noteCount >= 0);
  // Note: the member condition intentionally omits `request.resource.data.updatedAt == request.time`.
  // The WriteBatch for a note upload or delete does not write `updatedAt` on the session document.
  // If a future change adds `updatedAt` to the member batch, this rule must be updated to include
  // `'updatedAt'` in the member `affectedKeys().hasOnly()` list and the `updatedAt == request.time` assertion.
}
```

#### Amendment C — Firebase Storage rules for notes

Add to `storage.rules` alongside the avatar rules established in ADR 0005:

```
match /sessions/{sessionId}/notes/{noteId} {
  allow read: if request.auth != null
    && request.auth.token.email_verified == true
    && request.auth.token.email.matches('.*@(mail\\.kmutt\\.ac\\.th|kmutt\\.ac\\.th)$');

  allow write: if request.auth != null
    && request.auth.token.email_verified == true
    && request.auth.token.email.matches('.*@(mail\\.kmutt\\.ac\\.th|kmutt\\.ac\\.th)$')
    && request.resource.size <= 10485760
    && request.resource.contentType in [
         'image/jpeg', 'image/png', 'image/gif', 'image/webp',
         'application/pdf',
         'application/msword',
         'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
         'text/plain',
         'application/zip',
         'application/x-rar-compressed',
         'application/x-7z-compressed'
       ];

  allow delete: if request.auth != null
    && request.auth.token.email_verified == true
    && request.auth.token.email.matches('.*@(mail\\.kmutt\\.ac\\.th|kmutt\\.ac\\.th)$');
}
```

Storage delete grants KMUTT-authenticated users the ability to delete any file at this path. The Firestore rules (ADR 0001) are the authoritative authorization check: the `WriteBatch` that deletes the Firestore document (and decrements `noteCount`) will be rejected by Firestore rules if the caller is neither the host nor the file owner. Storage delete is only attempted after a successful Firestore `WriteBatch` commit, so an unauthorized user has no data-layer path to reach the Storage delete call.

**Risk acceptance — Storage orphan via direct SDK call:** A KMUTT-authenticated client who obtains a valid Storage path (e.g., by reading the `storageRef` field from a Firestore note document they have read access to) can call the Firebase Storage SDK `delete()` directly, bypassing the application code sequence and orphaning the Storage object without touching the Firestore note document or `noteCount`. The consequence is a dangling `downloadUrl` on the Firestore note document that returns HTTP 404. The note document itself remains intact and visible in the UI (with a broken file link). This risk is accepted at MVP because Firebase Storage rules cannot reference Firestore documents (cross-product rule reads are not supported), making it impossible to enforce Firestore-level authorization in Storage rules. The security reviewer must explicitly confirm this acceptance before the PR is merged. Mitigation in a future iteration: a Cloud Storage `onObjectDeleted` trigger that detects orphaned Storage objects and removes the corresponding Firestore note document.

---

### CI pipeline changes required

The following changes to the CI pipeline must be made before the integration tests can pass in CI. The release engineer owns these changes.

- **Remote Config emulator seed** — the Firebase emulator job must seed `note_sharing_enabled: false` in the Remote Config emulator before any test run. Add a `remoteconfig.json` seed file to the emulator data directory and reference it in the emulator startup command (`--import`).
- **Storage rules emulator** — the Storage rules emulator must load the amended `storage.rules` file (Amendment C) so that the `/sessions/{sessionId}/notes/{noteId}` path is exercised in CI. Verify that the emulator job references the correct `storage.rules` path.
- **Integration test placement** — `note_upload_test.dart` and `note_delete_test.dart` must run in the existing Firebase emulator CI job (or a dedicated parallel matrix job if the Android + Web combination requires separate runners). Both tests must run against the Android emulator and the Web (Chrome) target in the same CI run.
- **Merge gate** — the release engineer must confirm that `note_sharing_enabled` is set to `false` in the production Firebase Remote Config before the PR is merged. This confirmation must appear as a manual approval step or a CI check that reads the production Remote Config value and fails the job if the flag is not `false`.

---

### New packages — add to `apps/mobile/pubspec.yaml`

- `file_picker` — multi-platform file selection; returns file bytes as `Uint8List` on Android and Web
- `firebase_remote_config` — feature flag; read after activation in app startup

(`firebase_storage` is already declared per ADR 0001 Amendment 3.)

---

### Storage path constant — add to `lib/core/storage_paths.dart`

```dart
static String sessionNote(String sessionId, String noteId) =>
    'sessions/$sessionId/notes/$noteId';
```

---

### Firestore path constant — add to `lib/core/firestore_paths.dart`

```dart
static String notes(String sessionId) =>
    'sessions/$sessionId/notes';
static String note(String sessionId, String noteId) =>
    'sessions/$sessionId/notes/$noteId';
```

---

### Domain errors — `lib/core/errors/note_error.dart`

Sealed class with variants:

- `NoteError.fileTooLarge(int sizeBytes)` — file exceeds 10 MB; `sizeBytes` is the actual size
- `NoteError.unsupportedMimeType(String mimeType)` — MIME type not in the allowed list; `mimeType` must contain no PII
- `NoteError.sessionCapReached` — session has reached the 50-note cap
- `NoteError.uploadFailed(String message)` — Firebase Storage or Firestore write failed; `message` must contain no PII
- `NoteError.deleteFailed(String message)` — delete operation failed; `message` must contain no PII
- `NoteError.permissionDenied` — caller is neither the session host nor the file owner

---

### Domain entity — `lib/features/note_sharing/domain/entities/note_entity.dart`

Freezed; fields:

| Field | Type | Notes |
|---|---|---|
| `noteId` | String | Firestore document ID |
| `uploaderUid` | String | UID of the uploader |
| `uploaderDisplayName` | String | Denormalized display name; populated from Firestore document |
| `fileName` | String | Original filename including extension |
| `mimeType` | String | Validated MIME type |
| `sizeBytes` | int | File size in bytes |
| `storageRef` | String | Firebase Storage path (not a full URL); value of `StoragePaths.sessionNote(sessionId, noteId)` |
| `downloadUrl` | String | Firebase Storage download URL |
| `uploadedAt` | DateTime | Converted from Firestore Timestamp in the model layer |

Value object for upload parameters — `lib/features/note_sharing/domain/entities/note_upload_params.dart` — Freezed; fields: `fileName` (String), `mimeType` (String), `sizeBytes` (int), `bytes` (Uint8List from `dart:typed_data`).

---

### Domain repository interface — `lib/features/note_sharing/domain/repositories/note_repository.dart`

```dart
abstract class NoteRepository {
  Stream<List<NoteEntity>> watchNotes(String sessionId);
  Future<void> uploadNote(String sessionId, NoteUploadParams params);
  Future<void> deleteNote(String sessionId, String noteId);
  Future<List<NoteEntity>> fetchNotesPage(
    String sessionId, {
    int limit = 20,
    DateTime? startAfter,
  });
}
```

---

### Domain use cases

- `lib/features/note_sharing/domain/usecases/watch_notes_usecase.dart`
  — `Stream<List<NoteEntity>> call(String sessionId)` — delegates to `NoteRepository.watchNotes`.

- `lib/features/note_sharing/domain/usecases/upload_note_usecase.dart`
  — `Future<void> call(String sessionId, NoteUploadParams params)` — validates `sizeBytes ≤ 10,485,760` (throws `NoteError.fileTooLarge`); validates `mimeType` against the allowed set (throws `NoteError.unsupportedMimeType`); delegates to `NoteRepository.uploadNote`.

- `lib/features/note_sharing/domain/usecases/delete_note_usecase.dart`
  — `Future<void> call(String sessionId, String noteId)` — delegates to `NoteRepository.deleteNote`.

- `lib/features/note_sharing/domain/usecases/fetch_notes_page_usecase.dart`
  — `Future<List<NoteEntity>> call(String sessionId, {int limit = 20, DateTime? startAfter})` — delegates to `NoteRepository.fetchNotesPage`.

---

### Data layer files

- `lib/features/note_sharing/data/models/note_model.dart` — Freezed + json_serializable; maps the Firestore `notes` document to `NoteEntity`; converts `uploadedAt` Timestamp to `DateTime`.

- `lib/features/note_sharing/data/datasources/note_datasource.dart`
  — Path constants from `lib/core/firestore_paths.dart` and `lib/core/storage_paths.dart` only.
  — `Stream<List<NoteModel>> watchNotes(String sessionId)` — `collection(FirestorePaths.notes(sessionId)).orderBy('uploadedAt', descending: true).snapshots()`.
  — `Future<String> uploadFile(String sessionId, String noteId, Uint8List bytes, String mimeType)` — uploads to `StoragePaths.sessionNote(sessionId, noteId)` with `SettableMetadata(contentType: mimeType)`; returns the download URL from `UploadTask.snapshot.ref.getDownloadURL()`. Logs progress at debug level. Records non-fatal Crashlytics event on `FirebaseException`.
  — `Future<void> writeNoteBatch(String sessionId, NoteModel model)` — commits a `WriteBatch`: sets the note document at `FirestorePaths.note(sessionId, noteId)` and increments `noteCount` by 1 on the session document via `FieldValue.increment(1)`.
  — `Future<void> deleteNoteBatch(String sessionId, String noteId, String storageRef)` — commits a `WriteBatch`: deletes the note document and decrements `noteCount` by 1 via `FieldValue.increment(-1)`; on success, deletes the Storage object at `storageRef`. If Storage delete fails: logs at error level and records a non-fatal Crashlytics event; does not re-throw (the note is already gone from Firestore).
  — `Future<void> deleteStorageFile(String storageRef)` — deletes the orphan Storage object on `WriteBatch` failure during upload.
  — `Future<List<NoteModel>> fetchNotesPage(String sessionId, {int limit = 20, DateTime? startAfter})` — queries `collection(FirestorePaths.notes(sessionId)).orderBy('uploadedAt', descending: true).limit(limit)`; applies `.startAfter([Timestamp.fromDate(startAfter)])` when `startAfter` is non-null; returns an empty list when no documents are returned.

- `lib/features/note_sharing/data/repositories/note_repository_impl.dart`
  — Implements `NoteRepository`.
  — `uploadNote`: reads `users/{uploaderUid}.displayName` once via `UserDatasource` to populate `uploaderDisplayName`; calls `NoteDatasource.uploadFile`; on Storage success calls `NoteDatasource.writeNoteBatch`; on `WriteBatch` failure calls `NoteDatasource.deleteStorageFile` then throws `NoteError.uploadFailed`.
  — `deleteNote`: calls `NoteDatasource.deleteNoteBatch`; maps `FirebaseException` with `permission-denied` code to `NoteError.permissionDenied`; wraps other exceptions in `NoteError.deleteFailed`.
  — `fetchNotesPage`: delegates to `NoteDatasource.fetchNotesPage`; maps `NoteModel` list to `NoteEntity` list.

---

### Presentation providers

- `lib/features/note_sharing/presentation/providers/notes_provider.dart`
  — `@riverpod Stream<List<NoteEntity>> notes(ref, String sessionId)` — auto-dispose; watches `NoteRepository.watchNotes(sessionId)`.

- `lib/features/note_sharing/presentation/providers/note_actions_provider.dart`
  — `@riverpod` async notifier `NoteActionsNotifier(String sessionId)` holding `AsyncValue<void>` state.
  — Exposes `Future<void> upload(NoteUploadParams params)` — checks `note_sharing_enabled` Remote Config flag; calls `UploadNoteUseCase`; fires `note_uploaded` analytics event on success.
  — Exposes `Future<void> delete(String noteId)` — calls `DeleteNoteUseCase`; fires `note_deleted` analytics event on success.
  — On any `NoteError`, sets state to `AsyncError` so the UI can surface the correct error message per variant.

- `lib/features/note_sharing/presentation/providers/note_sharing_flag_provider.dart`
  — `@riverpod bool noteSharingEnabled(ref)` — synchronous; reads `FirebaseRemoteConfig.instance.getBool('note_sharing_enabled')`; defaults to `false` before the first successful fetch. Remote Config must be fetched and activated during app startup before this provider is read. The fetch/activate call is owned by `lib/core/remote_config_startup.dart`, which exposes a `@riverpod Future<void> remoteConfigStartup(ref)` provider. This provider must be awaited in the app initialization sequence (e.g., inside `main()` via `ProviderContainer` or in the root widget's `didChangeDependencies`) before `ProviderScope` renders any screen that reads `noteSharingEnabledProvider`. `FirebaseRemoteConfig.instance.setConfigSettings(RemoteConfigSettings(fetchTimeout: const Duration(seconds: 10), minimumFetchInterval: const Duration(hours: 12)))` must be called before `fetchAndActivate()`.

- `lib/features/note_sharing/presentation/providers/paginated_notes_provider.dart`
  — `@riverpod` async notifier `PaginatedNotesNotifier(String sessionId)` with state `({List<NoteEntity> notes, bool hasMore})`.
  — On `build`: loads the first page by calling `FetchNotesPageUseCase(sessionId, limit: 20)`; sets `hasMore = (page.length == 20)`.
  — Exposes `Future<void> fetchNextPage()` — derives the cursor from `uploadedAt` of the last note in the current state; calls `FetchNotesPageUseCase(sessionId, limit: 20, startAfter: cursor)`; appends results to `notes`; sets `hasMore = false` when fewer than 20 notes are returned; no-ops when `hasMore` is already `false`.
  — Exposes `Future<void> refresh()` — resets state to the first page (calls `FetchNotesPageUseCase` with no cursor).

---

### Presentation screens and widgets

**`FilesTab` widget — `lib/features/note_sharing/presentation/widgets/files_tab.dart`**

Extracted into a named widget imported by both detail screens.

- Reads `noteSharingEnabledProvider`; if `false`, renders a `Center` containing a "Coming soon" `Text` with a `Semantics(label: 'Files tab — coming soon')` wrapper.
- If flag is `true`:
  - Watches `notesProvider(sessionId)`.
  - `AsyncValue.loading`: renders `CircularProgressIndicator` centered.
  - `AsyncValue.error`: renders an inline error banner.
  - `AsyncValue.data`:
    - If list is empty: renders a centred empty-state illustration and `Text('No files yet')` with `Semantics(label: 'No files shared yet')`.
    - If list is non-empty: `ListView.builder(itemCount: min(5, notes.length), itemBuilder: ...)` rendering `NoteTile` for the first 5 notes (the first 5 entries of the stream result, already ordered by `uploadedAt` desc). If `notes.length > 5`, a "See All" `TextButton` is rendered immediately below the list, showing the total count (e.g. "See All 12 files"); tapping it fires the `note_see_all_opened` analytics event and calls `context.push(RouteConstants.sessionFiles, extra: {'sessionId': sessionId, 'currentUserId': currentUserId, 'isHost': isHost})`.
  - Upload FAB: `FloatingActionButton` with `Semantics(label: 'Upload file', button: true)`; taps open a `showModalBottomSheet` with file-type guidance and a single "Pick file" action that invokes `FilePicker.platform.pickFiles()`; on selection calls `NoteActionsNotifier.upload`.
  - Upload progress: while `noteActionsProvider` state is `AsyncLoading`, overlay a `LinearProgressIndicator` at the top of the tab.

**`NoteTile` widget — `lib/features/note_sharing/presentation/widgets/note_tile.dart`**

- `ListTile` with leading file-type icon derived from `mimeType` (image MIME types show a `CachedNetworkImage` thumbnail; all others show a static icon per category: document, archive, text).
- **Thumbnail sizing (MVP):** `CachedNetworkImage` renders the full `downloadUrl` at the tile's leading image slot (56 dp height). No server-side image resizing is applied at MVP. If profiling in the QA performance check reveals excessive memory usage from downloading full-resolution images in list view, a future ADR should evaluate Firebase Extensions (Resize Images extension) or the `maxWidthDiskCache` / `maxHeightDiskCache` parameters on `CachedNetworkImage`. The QA performance check must note peak memory usage when 5 image-type tiles are visible simultaneously in `FilesTab`.
- Title: `note.fileName`. Subtitle: formatted `sizeBytes` (e.g. "4.2 MB") + " · " + relative `uploadedAt` + " · " + `note.uploaderDisplayName`.
- Trailing: delete `IconButton` (visible only when `currentUserId == note.uploaderUid || currentUserId == session.hostUid`), wrapped in `Semantics(label: 'Delete ${note.fileName}', button: true)`.
- Tapping the tile triggers the platform default open action (calls `url_launcher.launchUrl(Uri.parse(note.downloadUrl))`).
- Minimum tile height: 56 dp; touch target complies with the 44 × 44 dp minimum.
- Color contrast for subtitle text must meet WCAG AA (4.5:1 against the tile background).

**`AllFilesScreen` — `lib/features/note_sharing/presentation/screens/all_files_screen.dart`**

Pushed via GoRouter from the "See All" button in `FilesTab`. Receives `sessionId`, `currentUserId`, and `isHost` from GoRouter `extra`.

- Reads `noteSharingEnabledProvider`; if `false`, pops immediately and shows a `SnackBar` ("Files are not available yet").
- App bar title: "All Files". Standard back button navigates to the previous screen.
- Watches `paginatedNotesNotifier(sessionId)`.
- `AsyncValue.loading` (first page only): renders `CircularProgressIndicator` centered.
- `AsyncValue.error`: renders an inline error banner.
- `AsyncValue.data`:
  - `ListView.builder(itemCount: notes.length + (hasMore ? 1 : 0), itemBuilder: ...)`:
    - Indices `0` to `notes.length - 1`: renders `NoteTile(note: notes[i], currentUserId: currentUserId, isHost: isHost)`.
    - Index `notes.length` (rendered only when `hasMore == true`): while the notifier is loading the next page, renders a `CircularProgressIndicator`; otherwise renders a "Load more" `OutlinedButton` with `Semantics(label: 'Load more files', button: true)` that calls `PaginatedNotesNotifier.fetchNextPage()`.
  - `RefreshIndicator` wraps the `ListView.builder`; on refresh calls `PaginatedNotesNotifier.refresh()`.
- Upload FAB: identical to the FAB in `FilesTab` (same `NoteActionsNotifier`, same `LinearProgressIndicator` overlay on loading).
- All interactive elements wrapped in `Semantics`; minimum touch target 44 × 44 dp on "Load more" button.
- Color contrast for subtitle text ≥ 4.5:1 (same as `NoteTile` in `FilesTab`).

**Detail screen amendments (ADR 0003)**

- `MemberSessionDetailScreen` — rename tab label at index 1 from "Notes" to "Files"; replace the tab body with `FilesTab(sessionId: sessionId, currentUserId: currentUserId, session: session)`.
- `HostSessionDetailScreen` — same rename and replacement for tab index 1.
- Both screens: read `extra['initialTabIndex'] as int?` from GoRouter context; if non-null, pass to `TabController(initialIndex: ...)` so the caller can open directly at the Files tab.

---

### Session → GoRouter navigation to Files tab

To navigate to the Files tab directly (e.g., from a push notification or the calendar screen):

```dart
context.go(
  '/my-sessions/session/$sessionId/member',
  extra: {'initialTabIndex': 1},
);
```

For host-owned sessions:

```dart
context.go(
  '/my-sessions/session/$sessionId/host',
  extra: {'initialTabIndex': 1},
);
```

**`extra` type-safety:** In the receiving screens, parse `extra` as `(state.extra as Map<String, dynamic>?)`. Use a null-safe fallback: `final initialTabIndex = (extra?['initialTabIndex'] as int?) ?? 0`. This pattern must be consistent with the approach used in ADR 0003 detail screens — if ADR 0003 uses a typed `extra` model class or a named extension on `GoRouterState`, adopt the same pattern here rather than introducing a second parsing convention.

**`AllFilesScreen` route — add to `RouteConstants` and `app_router.dart`**

| Route constant | Path | Screen |
|---|---|---|
| `RouteConstants.sessionFiles` | `/my-sessions/session/:id/files` | `AllFilesScreen` |

Navigate from the "See All" button in `FilesTab`:

```dart
context.push(
  RouteConstants.sessionFiles,
  extra: {
    'sessionId': sessionId,
    'currentUserId': currentUserId,
    'isHost': isHost,
  },
);
```

The `:id` path parameter must match the `sessionId` already available at the call site.

---

### Analytics events — declare in `lib/core/analytics_events.dart` before use

- `note_uploaded` — payload: `mime_type` (String, no PII), `size_bytes` (int)
- `note_deleted` — no payload
- `note_file_opened` — no payload
- `note_upload_failed` — payload: `error_type` (String, no PII — e.g. `'file_too_large'`, `'unsupported_mime'`, `'upload_failed'`, `'cap_reached'`)
- `note_see_all_opened` — no payload

---

### Logging and observability

All log calls use `lib/core/logger.dart` only; never `print()`. No PII in any log message or Crashlytics key.

| Call site | Level | Message (no PII) |
|---|---|---|
| `UploadNoteUseCase` — size validation failure | `warning` | `'note_upload: file too large sizeBytes=$sizeBytes limit=10485760'` |
| `UploadNoteUseCase` — MIME validation failure | `warning` | `'note_upload: unsupported mimeType=$mimeType'` |
| `NoteDatasource.uploadFile()` — upload started | `debug` | `'note_upload: starting upload sessionId=$sessionId noteId=$noteId'` |
| `NoteDatasource.uploadFile()` — upload complete | `info` | `'note_upload: upload complete sessionId=$sessionId noteId=$noteId'` |
| `NoteDatasource.uploadFile()` — Storage exception | `error` | `'note_upload: Storage upload failed sessionId=$sessionId errorCode=$code'` |
| `NoteRepositoryImpl.uploadNote()` — WriteBatch failure, orphan cleanup | `error` | `'note_upload: WriteBatch failed; deleting orphan noteId=$noteId'` |
| `NoteDatasource.deleteNoteBatch()` — batch committed | `info` | `'note_delete: Firestore batch committed noteId=$noteId sessionId=$sessionId'` |
| `NoteDatasource.deleteNoteBatch()` — Storage delete failure | `error` | `'note_delete: Storage delete failed noteId=$noteId errorCode=$code'` |

Non-fatal Crashlytics events (`FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: false)`) must be recorded at:

- `NoteDatasource.uploadFile()` on `FirebaseException`
- `NoteDatasource.deleteNoteBatch()` on Storage delete failure (after successful Firestore batch)
- `NoteRepositoryImpl.uploadNote()` on orphan cleanup failure

---

### Test matrix (qa-engineer owns; must be complete before Flutter Engineer begins presentation layer)

| Test type | File | What to verify |
|---|---|---|
| Unit | `test/features/note_sharing/domain/upload_note_usecase_test.dart` | Throws `NoteError.fileTooLarge` when `sizeBytes > 10_485_760`; throws `NoteError.unsupportedMimeType` for a disallowed MIME; delegates to repository when valid |
| Unit | `test/features/note_sharing/domain/delete_note_usecase_test.dart` | Delegates to repository; propagates `NoteError.permissionDenied` |
| Unit | `test/features/note_sharing/data/note_datasource_test.dart` | `uploadFile` returns download URL on success; records non-fatal Crashlytics on `FirebaseException`; `deleteNoteBatch` decrement is FieldValue.increment(-1); Storage delete called after successful batch |
| Unit | `test/features/note_sharing/data/note_repository_impl_test.dart` | On `WriteBatch` failure after upload, `deleteStorageFile` is called with the correct `storageRef`; `permissionDenied` Firestore code mapped to `NoteError.permissionDenied` |
| Widget | `test/features/note_sharing/presentation/files_tab_test.dart` | Renders "Coming soon" when flag is false; renders empty state when note list is empty; renders exactly 5 `NoteTile`s when more than 5 notes exist; "See All" button visible when `notes.length > 5`; "See All" button hidden when `notes.length ≤ 5`; tapping "See All" pushes `RouteConstants.sessionFiles`; delete button hidden for non-owner non-host; delete button visible for owner; delete button visible for host |
| Widget | `test/features/note_sharing/presentation/all_files_screen_test.dart` | Renders up to 20 `NoteTile`s on first page; "Load more" button visible when `hasMore` is true; "Load more" button absent when `hasMore` is false; tapping "Load more" calls `PaginatedNotesNotifier.fetchNextPage`; `CircularProgressIndicator` replaces "Load more" while next page is loading; pull-to-refresh calls `PaginatedNotesNotifier.refresh` |
| Widget | `test/features/note_sharing/presentation/note_tile_test.dart` | Image MIME shows `CachedNetworkImage`; non-image MIME shows category icon; subtitle includes formatted size and uploader name; `Semantics` label matches `'Delete ${note.fileName}'` |
| Golden | `test/features/note_sharing/presentation/goldens/files_tab_populated.png` | Tab preview showing 5 tiles and "See All N files" button |
| Golden | `test/features/note_sharing/presentation/goldens/all_files_screen_page1.png` | All Files screen showing 20 tiles and "Load more" button |
| Golden | `test/features/note_sharing/presentation/goldens/files_tab_empty.png` | Empty state illustration and copy |
| Golden | `test/features/note_sharing/presentation/goldens/files_tab_flag_off.png` | "Coming soon" placeholder |
| Integration | `test/integration/note_upload_test.dart` | Android + Web: upload a PDF under 10 MB; verify it appears in the list; verify `noteCount` incremented on session document |
| Integration | `test/integration/note_delete_test.dart` | Android + Web: owner deletes own note; verify it disappears from the list; verify `noteCount` decremented; verify Storage object deleted; non-owner attempt returns `NoteError.permissionDenied` |

**Web MIME-type limitation:** On Web, `file_picker` derives the MIME type from the browser's interpretation of the file extension, not from the file's byte content. A file with a renamed extension (e.g., an executable renamed to `.pdf`) will pass both the use-case MIME check and the Storage `contentType` rule (since the client sets `SettableMetadata.contentType` to the picker-reported type). This is accepted at MVP. A future mitigation is a Cloud Storage `onObjectFinalized` trigger that inspects file bytes server-side and deletes objects whose content does not match the declared `contentType`. The integration test suite does not cover this attack vector; the security reviewer must note it in the audit report.

Accessibility sweep (qa-engineer): run `flutter test --tags a11y` on `FilesTab` and `AllFilesScreen`; verify every `NoteTile`, the upload FAB, the delete buttons, the "See All" button, and the "Load more" button carry `Semantics` labels readable by TalkBack (Android) and ChromeVox (Web). Verify subtitle text contrast ratio ≥ 4.5:1.

Performance check (qa-engineer): confirm that rendering 20 `NoteTile`s per page in `AllFilesScreen`'s `ListView.builder` produces no dropped frames on a mid-range Android device using Flutter's performance overlay.

---

### Implementation checklist for Flutter Engineer

- [ ] Amend `firestore.rules` — extend `sessions` update rule per Amendment B above (member `noteCount` ±1 condition)
- [ ] Amend `firestore.rules` — add `uploaderDisplayName` to `notes` create rule `hasAll` per Amendment A
- [ ] Amend `storage.rules` — add note Storage rules per Amendment C
- [ ] Add `file_picker` and `firebase_remote_config` to `apps/mobile/pubspec.yaml`
- [ ] Add `sessionNote(sessionId, noteId)` constant to `lib/core/storage_paths.dart`
- [ ] Add `notes(sessionId)` and `note(sessionId, noteId)` constants to `lib/core/firestore_paths.dart`
- [ ] Create `lib/core/errors/note_error.dart` — sealed class with five variants
- [ ] Declare all four analytics events in `lib/core/analytics_events.dart`
- [ ] Create `NoteUploadParams` value object (Freezed, domain layer, `dart:typed_data` only)
- [ ] Create `NoteEntity` Freezed entity
- [ ] Create `NoteRepository` abstract interface
- [ ] Create four use cases: `WatchNotesUseCase`, `UploadNoteUseCase`, `DeleteNoteUseCase`, `FetchNotesPageUseCase`
- [ ] Create `NoteModel` (Freezed + json_serializable)
- [ ] Create `NoteDatasource` with `watchNotes`, `uploadFile`, `writeNoteBatch`, `deleteNoteBatch`, `deleteStorageFile`, `fetchNotesPage`; add `logger.dart` calls at all specified call sites; add non-fatal Crashlytics records at all specified call sites
- [ ] Create `NoteRepositoryImpl`; reads `users/{uploaderUid}.displayName` once at upload time; handles orphan cleanup
- [ ] Create `notesProvider`, `NoteActionsNotifier`, `noteSharingEnabledProvider`, `PaginatedNotesNotifier`
- [ ] Create `lib/core/remote_config_startup.dart` — `@riverpod Future<void> remoteConfigStartup(ref)` provider that calls `FirebaseRemoteConfig.instance.setConfigSettings(...)` then `fetchAndActivate()`; await this provider in the app initialization sequence before any `noteSharingEnabledProvider` read
- [ ] Create `FilesTab` widget; gate on `noteSharingEnabledProvider`; wrap all interactive elements in `Semantics`
- [ ] Create `NoteTile` widget; image MIME types use `CachedNetworkImage`; minimum 44 × 44 dp touch target on delete button; verify subtitle contrast ≥ 4.5:1
- [ ] Amend `MemberSessionDetailScreen` — rename tab 1 label to "Files"; replace body with `FilesTab`; read `extra['initialTabIndex']` from GoRouter context
- [ ] Amend `HostSessionDetailScreen` — same amendments
- [ ] Verify domain layer has zero Flutter and Firebase imports (`dart run build_runner build` must pass with no import lint errors)
- [ ] Add `note_sharing_enabled` flag to Firebase Remote Config in the console before first QA deployment (set to `false` initially)

---

### Agent hand-off

- **QA engineer** must produce the full test matrix above and complete the accessibility sweep and performance check before the Flutter Engineer begins the presentation layer.
- **Security reviewer** must audit `NoteDatasource` (Storage upload/delete sequencing, orphan cleanup path), `NoteRepositoryImpl` (permission-denied mapping), and the amended Firestore rules (sessions update rule member condition) before the PR is merged.
- **Release engineer** must confirm `note_sharing_enabled` Remote Config flag is set to `false` in production until the integration tests for upload and delete pass in CI on both Android and Web.
- **Architect** must amend ADR 0001 inline (Amendments A, B, C) before the Flutter Engineer begins; ADR 0001 is the authoritative schema and rules document.

**Parallel work windows:** The following tasks may run concurrently rather than sequentially to reduce end-to-end implementation time:

- While the Flutter Engineer builds the domain layer (entities, repository interface, use cases) and data layer (datasource, repository implementation), the QA engineer may concurrently author the full test matrix stubs (empty test files with documented test cases) and the security reviewer may concurrently draft the audit checklist against `NoteDatasource`, `NoteRepositoryImpl`, and the amended Firestore rules.
- The release engineer CI pipeline changes (Edit 1 above) may begin as soon as Amendment C Storage rules are finalized — they do not depend on the Flutter presentation layer being complete.
- ADR 0001 inline amendments (A, B, C) may be written by the architect concurrently with the Flutter Engineer beginning the domain layer, since the domain layer does not depend on Firestore rules being deployed.

---

## Reversal plan

**Sub-decision 1 (Storage path):** If the path pattern must change (e.g., to include a user sub-folder for Storage-rules-based delete authorization), update `StoragePaths.sessionNote`, migrate existing files using a one-off script or Cloud Function, and update `note_datasource.dart`. The domain entity, repository interface, and all use cases are unaffected. An ADR amendment is required before the migration begins.

**Sub-decision 2 (direct SDK upload):** If a Cloud Function intermediary becomes necessary (e.g., for server-side virus scanning), replace the `uploadFile` and `writeNoteBatch` calls in `NoteRepositoryImpl` with a single Cloud Function call. The `NoteRepository` interface, all use cases, and the presentation layer are unaffected. A new ADR covering the Function's responsibilities is required.

**Sub-decision 3 (single stream):** If the note cap is raised and the stream becomes too large, add cursor-based pagination: introduce `fetchMore()` on `NoteActionsNotifier`, maintain a `lastDocument` cursor in provider state, and append pages to the list. No domain entity, use case, or repository interface changes are required.

**Sub-decision 4 (Remote Config flag):** If Remote Config is replaced (e.g., by a Firestore-based flag service), change only `noteSharingEnabledProvider` to read from the new source. All consumers of the provider are unaffected.

**Sub-decision 5 (tab integration):** If a dedicated route for the Files screen becomes necessary (e.g., for share-link deep-linking with file context), add a new route constant `/sessions/:id/files` to `RouteConstants`, create `FilesScreen` wrapping `FilesTab`, and wire it in `app_router.dart`. Amend ADR 0003 to record the new route. The domain, data, and provider layers are unaffected.
