# 0001 — Note Sharing within Sessions

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-05-15 |
| Architect session | claude-sonnet-4-6 |
| Affects | sessions feature, data layer, Firebase Storage, Firestore rules, presentation/session-detail |

---

## Team approval

Approved by: DeepseaMew
Date: 2026-05-15
Notes:-

---

## Problem

KMUTT students collaborating inside a session need a way to share reference material — lecture slides, photos of handwritten notes, and compressed archives of exercise sets. Currently the session detail screen provides only chat and participant information; there is no mechanism to attach or retrieve files scoped to that session. Without a decision, different engineers might reach for different storage backends (Firestore base64, external CDN, or Firebase Storage) and produce incompatible access-control models. This record decides the storage backend, Firestore schema, security rules, domain layer shape, and UI placement so that implementation can start from a single agreed design.

---

## Constraints

- Notes must be scoped exclusively to a session; there is no standalone notes feature.
- Supported MIME categories: images (jpg, png, gif, webp), documents (pdf, doc, docx, txt), compressed archives (zip, rar, 7z).
- Maximum file size: 10 MB per file.
- Maximum notes per session: 50.
- Storage backend is Firebase Storage on the free tier (5 GB total cap).
- Delete permission: session host OR the uploader (file owner). No edit allowed.
- Visibility: current session members only. No public access.
- Notes persist after the session ends.
- Domain layer (entities, repository interfaces, use cases) must have zero Flutter or Firebase imports.
- Firestore rules must use `diff().affectedKeys()` for field-level write validation and `request.time` for all timestamp fields.
- KMUTT email gate enforced server-side in Firestore rules.
- All remote images rendered via `cached_network_image`; never `Image.network`.
- Models use Freezed + json_serializable; no hand-rolled JSON.
- All log calls go through `lib/core/logger.dart`; no PII in logs.
- Errors are sealed classes in `lib/core/errors/`; never throw raw strings.
- Package imports only; no relative imports.

---

## Options considered

### Option A — Firebase Storage with Firestore metadata subcollection (selected)

Binary files are uploaded to Firebase Storage. A lightweight metadata document is written to `sessions/{sessionId}/notes/{noteId}` in Firestore containing only non-binary fields (uploader UID, file name, MIME type, size, Storage download URL, timestamp). The client reads the subcollection in real time via a stream and renders previews using the download URL through `cached_network_image`.

**Trade-offs**
- Pro: Binary data stays in Storage, keeping Firestore documents small and under the 1 MB document limit.
- Pro: Firebase Storage security rules and Firestore rules enforce access independently and complementarily.
- Pro: Download URLs can be signed or made resumable; large files do not round-trip through Firestore.
- Con: Two separate rule sets (Storage rules + Firestore rules) must be kept consistent; a gap in either leaks access.
- Con: Deleting a note requires two atomic operations (Storage delete + Firestore delete); failure in either leaves orphaned data. A Cloud Function or client-side retry strategy is needed.
- Reversal cost: Medium. Migrating stored binaries to a different backend requires re-uploading all files and updating every download URL in Firestore. The domain layer and use cases are storage-backend-agnostic by contract, so only the data layer changes.

### Option B — Firestore only with base64-encoded file content

Files are base64-encoded on the client and stored directly in a Firestore document field. No separate Storage bucket is used.

**Trade-offs**
- Pro: Single backend; one rule set; no Storage configuration.
- Con: Base64 encoding inflates size by ~33%; a 10 MB file becomes ~13.3 MB, far exceeding the 1 MB Firestore document limit. This option is technically non-viable at the stated 10 MB file size limit.
- Con: Firestore is billed per read/write; large documents incur high read costs even for metadata-only list views.
- Reversal cost: Very high if already in production — all existing documents must be migrated to binary storage.

### Option C — Third-party CDN or self-hosted object storage

Files are uploaded to an external object storage provider (e.g., AWS S3, Cloudflare R2). Firestore stores only the metadata and the external URL.

**Trade-offs**
- Pro: Potentially lower storage cost and more flexible CDN configuration.
- Con: Adds an external service dependency outside the Firebase ecosystem, requiring separate secret management, a new CI integration, and additional Firestore rule logic to validate that URLs point to the expected origin.
- Con: Firebase Authentication tokens cannot be reused directly for Storage authorization; a backend proxy or signed URL generation service is required, adding infrastructure the team does not currently own.
- Reversal cost: High. Removing the external dependency requires re-uploading all files and retiring secrets and IAM roles in a second cloud account.

---

## Decision

Option A (Firebase Storage + Firestore metadata subcollection) is adopted. Option B is ruled out because base64 encoding violates the 1 MB Firestore document size limit at the required 10 MB file cap. Option C introduces an out-of-ecosystem dependency that conflicts with the project's current zero-backend-server posture and adds secret management complexity the team has not planned for. Option A aligns with the existing Firebase stack, allows real-time member-scoped subscriptions through Firestore, and keeps the domain layer fully decoupled from the storage implementation because the repository interface deals only in plain Dart types (no Firebase Storage references or URLs leak into the domain).

---

## Data model

### Firestore document — `sessions/{sessionId}/notes/{noteId}`

| Field | Type | Constraints |
|---|---|---|
| `noteId` | `String` | Document ID; generated client-side as UUID v4 |
| `uploaderUid` | `String` | UID of the Firebase Auth user who uploaded the file |
| `fileName` | `String` | Original file name as supplied by the picker; max 255 chars |
| `mimeType` | `String` | One of the allowed MIME types listed in Constraints |
| `fileSizeBytes` | `int` | Must be > 0 and <= 10 485 760 (10 MB) |
| `storageRef` | `String` | Firebase Storage object path (not the download URL); used to delete the object |
| `downloadUrl` | `String` | Firebase Storage download URL; used for display and download |
| `uploadedAt` | `Timestamp` | Set to `request.time` in Firestore rules; client value rejected |

**Composite index justification:**
A composite index on `(uploadedAt DESC)` is required for the `ListNotes` use case, which orders notes chronologically descending. No other multi-field query is needed because notes are always fetched within a single session subcollection and there is no cross-session query.

**Notes cap enforcement:**
The Firestore security rule for create checks that the subcollection size does not exceed 50 by reading the current count. Because Firestore does not support `get()` on collection size in rules efficiently, the cap is enforced client-side in `UploadNote` via a pre-check query and the rule applies a belt-and-suspenders field constraint only. The Flutter Engineer must implement the client-side guard as the primary cap enforcement mechanism.

---

## Firebase Storage path structure

```
notes/{sessionId}/{noteId}/{fileName}
```

- `sessionId` matches the Firestore session document ID.
- `noteId` matches the Firestore note document ID, providing a stable, collision-free path.
- `fileName` is the sanitized original file name (no path separators, no null bytes).

Storage security rules grant read access only to authenticated users whose UID appears in `sessions/{sessionId}.memberUids` (read from Firestore via `firestore.get()`). Write access is granted only during upload (the path must not already exist). Delete access is granted only to the uploader or the session host.

---

## Firestore security rules sketch

```
match /sessions/{sessionId}/notes/{noteId} {

  function isSessionMember() {
    return request.auth != null
      && request.auth.token.email_verified == true
      && request.auth.uid in get(/databases/$(database)/documents/sessions/$(sessionId)).data.memberUids;
  }

  function isSessionHost() {
    return request.auth != null
      && request.auth.uid == get(/databases/$(database)/documents/sessions/$(sessionId)).data.hostUid;
  }

  function isNoteOwner() {
    return request.auth != null
      && request.auth.uid == resource.data.uploaderUid;
  }

  function isKmuttEmail() {
    return request.auth.token.email.matches('.*@(mail\\.)?kmutt\\.ac\\.th');
  }

  // Members may list and read notes.
  allow read: if isSessionMember() && isKmuttEmail();

  // Any member may upload a note; uploadedAt must equal server time; only the
  // declared fields may be set.
  allow create: if isSessionMember()
    && isKmuttEmail()
    && request.resource.data.keys().hasOnly(
         ['noteId', 'uploaderUid', 'fileName', 'mimeType',
          'fileSizeBytes', 'storageRef', 'downloadUrl', 'uploadedAt'])
    && request.resource.data.uploadedAt == request.time
    && request.resource.data.uploaderUid == request.auth.uid
    && request.resource.data.fileSizeBytes <= 10485760;

  // No update (edit) is permitted.
  allow update: if false;

  // Only the host or the file owner may delete.
  allow delete: if (isSessionHost() || isNoteOwner()) && isKmuttEmail();
}
```

All write paths use `request.resource.data.keys().hasOnly(...)` (equivalent to `diff().affectedKeys()` semantics) to prevent injection of undeclared fields. `uploadedAt` is pinned to `request.time` server-side; any client-supplied value is rejected.

---

## Domain layer

### Entity — `lib/features/notes/domain/entities/note.dart`

```dart
// Pure Dart — zero Flutter or Firebase imports.
@freezed
class Note with _$Note {
  const factory Note({
    required String noteId,
    required String sessionId,
    required String uploaderUid,
    required String fileName,
    required String mimeType,
    required int fileSizeBytes,
    required String storageRef,
    required String downloadUrl,
    required DateTime uploadedAt,
  }) = _Note;
}
```

### Repository interface — `lib/features/notes/domain/repositories/note_repository.dart`

```dart
// Pure Dart — zero Flutter or Firebase imports.
abstract interface class NoteRepository {
  /// Emits the ordered list of notes for [sessionId] in real time.
  Stream<List<Note>> watchNotes({required String sessionId});

  /// Uploads [fileBytes] and creates the Firestore metadata document.
  /// Throws [NoteUploadFailure] on storage or Firestore error.
  /// Throws [NoteCapExceededFailure] when the session already has 50 notes.
  /// Throws [FileSizeExceededFailure] when [fileSizeBytes] > 10 MB.
  Future<Note> uploadNote({
    required String sessionId,
    required String fileName,
    required String mimeType,
    required int fileSizeBytes,
    required List<int> fileBytes,
    required String uploaderUid,
  });

  /// Deletes the Storage object and the Firestore document for [noteId].
  /// Throws [NoteDeleteUnauthorizedFailure] if the caller is neither host nor owner.
  Future<void> deleteNote({
    required String sessionId,
    required String noteId,
  });
}
```

### Use cases — `lib/features/notes/domain/usecases/`

**`UploadNote`**
```dart
// Input: sessionId, fileName, mimeType, fileSizeBytes, fileBytes, uploaderUid
// Output: Future<Note>
// Validates file size and MIME type before delegating to NoteRepository.uploadNote.
```

**`DeleteNote`**
```dart
// Input: sessionId, noteId
// Output: Future<void>
// Delegates directly to NoteRepository.deleteNote; authorization enforced by
// Firestore rules and double-checked in the data layer before the Storage delete.
```

**`ListNotes`**
```dart
// Input: sessionId
// Output: Stream<List<Note>>
// Delegates to NoteRepository.watchNotes; no additional business logic.
```

Sealed error classes to add to `lib/core/errors/`:
- `NoteUploadFailure`
- `NoteCapExceededFailure`
- `FileSizeExceededFailure`
- `UnsupportedMimeTypeFailure`
- `NoteDeleteUnauthorizedFailure`

---

## Presentation

### Location

Notes are surfaced inside the existing **session detail screen** (`features/sessions/presentation/screens/session_detail_screen.dart`) as a dedicated tab or collapsible section. The Flutter Engineer must not create a standalone notes route; notes are always reached through the session context via go_router.

### Provider shape — `lib/features/notes/presentation/providers/`

```dart
// Watches the live note list for a given session.
@riverpod
Stream<List<Note>> noteList(NoteListRef ref, {required String sessionId});

// Exposes upload and delete actions; returns AsyncValue to surface loading/error states.
@riverpod
class NoteController extends _$NoteController {
  // upload(sessionId, fileName, mimeType, fileSizeBytes, fileBytes)
  // delete(sessionId, noteId)
}
```

### UI rules

- Notes list uses `ListView.builder` with `itemCount`; never an unbounded `ListView`.
- Image previews (jpg, png, gif, webp) use `CachedNetworkImage` with a placeholder and error widget.
- Non-image files display a file-type icon and the file name; tapping opens the URL in the platform browser via `url_launcher` (already in the Flutter ecosystem; no new dependency decision needed unless not yet in pubspec — the Flutter Engineer must check).
- The upload button is visible to all session members.
- The delete icon is visible only to the note's uploader and the session host; this is a client-side UI guard. Authorization is enforced server-side by Firestore rules as the primary control.
- Upload progress is shown with a `LinearProgressIndicator` while bytes are transferring to Storage.
- All analytics events (note_uploaded, note_deleted) must be declared in `lib/core/analytics_events.dart` before use.
- No PII (file contents, user names) appears in any log call or Crashlytics key.

---

## Consequences

- The `notes` feature folder is added under `features/notes/` with the full domain/data/presentation structure. No existing feature folder is modified.
- Two Firebase products are now used for a single user action (upload): Firebase Storage and Cloud Firestore. The data layer repository implementation must handle partial-failure rollback (Storage upload succeeded but Firestore write failed) by deleting the orphaned Storage object in the catch block.
- The Firestore subcollection `sessions/{sessionId}/notes` must be included in Firestore backup and export configuration maintained by the release engineer.
- Firebase Storage billing now applies to the project; the release engineer must set a budget alert at 4 GB (80% of the 5 GB free cap) in the Firebase console.
- The QA engineer must add test cases for: cap enforcement at exactly 50 notes, rejection of files over 10 MB, rejection of disallowed MIME types, delete permission matrix (member cannot delete another member's note, host can delete any note), and persistence of notes after session end.
- The security reviewer must audit the Storage rules to confirm that the `firestore.get()` call in Storage rules correctly mirrors the Firestore member list and does not introduce a time-of-check/time-of-use gap.
- Negative: Deleting a note is not atomic across Storage and Firestore. A failed Storage delete with a successful Firestore delete leaves a dangling Storage object consuming quota. A failed Firestore delete with a successful Storage delete leaves an inaccessible record in the UI. The data layer must log both failure modes at the error level via `logger.dart`.
- Negative: The 50-note cap relies primarily on a client-side pre-check. A malicious or buggy client can bypass it; the cap is therefore a UX guardrail, not a hard security boundary.

---

## Reversal plan

If this decision is reversed or superseded:

1. A new ADR (NNNN-note-sharing-v2.md) must be written and accepted before any migration work begins.
2. The flutter-engineer migrates `lib/features/notes/data/` to point at the new backend. The domain layer (entities, interfaces, use cases) requires no changes because it is backend-agnostic.
3. All existing Storage objects under `notes/` must be exported and re-imported into the replacement backend. The release engineer owns this migration script under `tools/`.
4. Firestore documents in `sessions/{sessionId}/notes/` must have their `storageRef` and `downloadUrl` fields updated in bulk via a migration script.
5. Firebase Storage rules for the `notes/` path prefix must be removed or replaced.
6. The budget alert at 4 GB must be adjusted or removed.
7. The security reviewer must re-audit the new backend's access control rules before the feature goes live again.
