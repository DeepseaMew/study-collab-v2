# 0005 — Avatar Upload and Firebase Storage Architecture

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-05-19 |
| Architect session | claude-sonnet-4-6 / DeepseaMew / 2026-05-19 |
| Affects | Profile (avatar upload), Friends (friendPhotoUrl rendering), Sessions (hostPhotoUrl rendering), storage.rules (new file), lib/core/storage_paths.dart (new file), data/datasources/avatar_datasource.dart, domain/repositories/profile_repository.dart, data/repositories/profile_repository_impl.dart, pubspec.yaml |

---

## Team approval

Approved by: DeepseaMew
Date: 2026-05-19
Notes:

---

## Problem

The project has no `storage.rules` file and no authoritative decision on avatar Storage path structure, file versioning, size limits, client-side resize strategy, or how the resulting download URL is persisted in Firestore. Without this record the Flutter Engineer will make ad-hoc choices that conflict with the Note-Sharing feature planned for the same Storage bucket, and the denormalized `hostPhotoUrl` and `friendPhotoUrl` fields established in ADR 0001/ADR 0003/ADR 0004 will have no defined write path. This ADR establishes the Firebase Storage rules baseline for the entire project. Note-Sharing (planned in CLAUDE.md) will extend this ADR by adding rules for the `/notes/{sessionId}/{noteId}` path — it does not replace this record.

---

## Constraints

- Firebase Storage is on the Spark free tier: 5 GB total storage, 1 GB/day download. Avatar uploads and planned Note-Sharing uploads both draw from this shared quota.
- No Cloud Functions are available on the Spark plan; all upload and cleanup logic must run on the client.
- Target platforms: Android and Web only.
- Domain layer has zero Flutter or Firebase imports; all Storage path strings are constants in `lib/core/storage_paths.dart` (justification in Sub-decision 1 comparison table and Decision section).
- Repository interfaces in `domain/repositories/`; implementations in `data/repositories/`; no Firebase Storage types cross this boundary.
- All Riverpod providers use `@riverpod` codegen; no hand-written `StateNotifier`.
- No PII in logs, Crashlytics keys, or analytics events.
- KMUTT email gate is already enforced in Firestore rules via `isKmuttUser()` (ADR 0001); Firebase Storage rules must require authentication but cannot reuse Firestore helper functions — domain validation remains Firestore-side.
- `users/{uid}.photoUrl` is already defined as a nullable `String` in ADR 0001 schema. After upload, `UserRepositoryImpl` updates this field via a profile update write to Firestore.
- The Note-Sharing Storage path `/notes/{sessionId}/{noteId}/{fileName}` is reserved and must appear as a comment-only placeholder in `storage.rules`; rules for that path are out of scope for this ADR.
- `cached_network_image` is the only permitted widget for rendering remote avatar images (CLAUDE.md).
- Business logic must not be defined in the presentation layer.
- Every analytics event must be declared in `lib/core/analytics_events.dart` before use.

---

## Options considered

### Sub-decision 1 — Avatar Storage path and versioning strategy

| | Option A | Option B | Option C |
|---|---|---|---|
| Summary | `avatars/{uid}/avatar.jpg` — single file per user; overwrite on replace | `avatars/{uid}/{timestamp}.jpg` — new file per upload; old files accumulate | `avatars/{uid}/avatar.jpg` with a cache-bust query param appended to the URL stored in Firestore (`?v=<timestamp>`) |
| Storage quota cost | Minimal: exactly one avatar file per user regardless of how many times they change their photo | Unbounded: every upload adds a new file; quota grows without a cleanup mechanism (no Cloud Functions on Spark to prune old files) | Minimal: same single file as Option A; no extra files accumulate |
| URL caching behaviour | Stale: `cached_network_image` uses the URL string as its cache key; if the path never changes, a cached stale image is served until the OS-level HTTP cache expires | Not applicable: path changes on every upload so `cached_network_image` always fetches the new file, but old files consume quota indefinitely | Correct: the URL stored in Firestore changes on each upload (the `?v=<timestamp>` suffix changes) so `cached_network_image` treats it as a new URL and fetches the new image |
| Write complexity | Simple: upload overwrites the same path; call `getDownloadURL()` once | Simple: generate a new path per upload; old paths are never referenced again | Simple: upload overwrites the same Storage path; append `?v=<epoch-ms>` to the URL before writing to Firestore |
| Reversal cost | Medium: if cache-busting is added later, all existing `photoUrl` values in Firestore must be rewritten to append the query param | Medium: pruning accumulated old files requires a migration script or a Cloud Function (unavailable on Spark) | Low: removing the query param means stripping the suffix from all stored URLs; a one-time Firestore batch write per user suffices |
| Recommendation | Not recommended | Not recommended | Recommended |

Option C is recommended. Option A's single-file simplicity is desirable, but `cached_network_image` caches by URL string; a constant path means a user will see their old avatar in list views until the HTTP cache expires, which can be hours. Option B avoids the stale-cache problem but accumulates files indefinitely — with no Cloud Functions on Spark, old avatar files consume quota forever. Option C combines Option A's single-file quota efficiency with a deterministic cache-bust: appending `?v=<epoch-ms>` to the URL written to Firestore causes `cached_network_image` to treat each new avatar as a distinct URL while the Storage object itself is overwritten in place.

---

### Sub-decision 2 — Client-side resize before upload

| | Option A | Option B | Option C |
|---|---|---|---|
| Summary | Resize to max 512×512 px, JPEG quality 85, using `flutter_image_compress` before upload | Use `image_picker` `imageQuality: 80` as the only compression step (JPEG quality only; dimensions unchanged) | No compression; upload raw picked file |
| Storage quota cost | Low: a 512×512 JPEG at quality 85 is typically 30–80 KB regardless of the original photo resolution | Medium: quality reduction compresses well for typical phone photos (1–2 MB → 200–500 KB) but a high-resolution photo (12 MP+) can still produce a file of 1–3 MB after quality reduction alone because dimensions are unchanged | High: a single raw 12 MP photo can be 4–8 MB; 1,000 users each uploading once would consume 4–8 GB, exceeding the 5 GB free-tier limit |
| Upload time on mobile | Fast: bounded file size means predictable upload time on mobile networks | Variable: a high-resolution original can still take 5–15 seconds on a slow mobile connection | Unacceptable: upload time is unbounded and unpredictable |
| Package dependency cost | One new package: `flutter_image_compress` (actively maintained, Android + Web supported) | No new package: `imageQuality` is a native `image_picker` parameter already present in the dependency tree | No new package |
| Reversal cost | Low: remove the compress call in `AvatarDatasource`; delete the `flutter_image_compress` dependency from `pubspec.yaml`; upload behaviour reverts to the raw file from `image_picker` | Low: add the `flutter_image_compress` step in `AvatarDatasource`; no schema changes | Low: add any compression step in `AvatarDatasource` |
| Recommendation | Recommended | Not recommended | Not recommended |

Option A is recommended. The Spark free tier has 5 GB total shared between avatars and planned Note-Sharing uploads; unconstrained avatar dimensions directly risk quota exhaustion. A 512×512 px cap at JPEG quality 85 produces a file consistently under 100 KB, making upload time negligible on any mobile connection and preserving the majority of the quota for Note-Sharing documents. `flutter_image_compress` supports Android and Web (the two required platforms) and adds one compile-time dependency with no runtime permissions beyond those already required by `image_picker`. Option B's dimension-unbounded approach would allow a single high-resolution photo to be 1–3 MB; 2,000 users each uploading twice would alone approach the 5 GB ceiling before Note-Sharing has been used at all.

---

### Sub-decision 3 — Download URL persistence strategy

| | Option A | Option B | Option C |
|---|---|---|---|
| Summary | Store the full download URL (with cache-bust suffix) in `users/{uid}.photoUrl` immediately after upload | Store only the Storage path in Firestore; call `getDownloadURL()` at render time | Call `getDownloadURL()` at render time; store nothing in Firestore |
| Read cost | Low: all list renders (friend list, session card, join-request card) read from Firestore documents that already carry the URL; zero additional Storage SDK calls per render | High: every list item that needs an avatar must issue a `getDownloadURL()` call — O(N) Storage reads per list render | High: identical to Option B; O(N) Storage reads per render; download bandwidth counts against the 1 GB/day free-tier limit |
| Offline support | Full: the URL is persisted in the Firestore document and available from the Firestore offline cache | None: `getDownloadURL()` requires a network call and cannot be served from any local cache | None: same as Option B |
| Consistency with ADR 0001 | Directly consistent: `users/{uid}.photoUrl` is already defined as a nullable String in ADR 0001; `hostPhotoUrl` and `friendPhotoUrl` denormalization patterns in ADR 0001/ADR 0003/ADR 0004 all store a URL string, not a Storage path | Inconsistent: the existing denormalized `hostPhotoUrl` and `friendPhotoUrl` fields on session and friend documents already store full URLs; storing only a path on the canonical user document creates two incompatible reference formats in the same codebase | Inconsistent: no Firestore field is written; all existing `photoUrl` references in ADR 0001 schema are undefined |
| Write complexity | Low: one Firestore `update` to `users/{uid}.photoUrl` after `getDownloadURL()` | Low: one Firestore `update` to `users/{uid}.storageRef` after upload | Zero Firestore writes for the URL; but downstream features cannot read the URL from Firestore |
| Reversal cost | Low: if Storage paths replace URLs, strip the URL from Firestore and store paths instead; update all denormalized `hostPhotoUrl`/`friendPhotoUrl` fields via a migration script | Medium: if full URLs are required later, a migration must call `getDownloadURL()` for every stored path and rewrite the Firestore field | High: no migration path exists without reading every user's Storage object to generate a URL |
| Recommendation | Recommended | Not recommended | Not recommended |

Option A is recommended. Storing the full download URL in `users/{uid}.photoUrl` is directly consistent with the ADR 0001 schema, the `hostPhotoUrl` denormalization established in ADR 0003, and the `friendPhotoUrl` denormalization established in ADR 0004 — all three already store URL strings. Options B and C introduce O(N) Storage reads per list render, consume download quota against the 1 GB/day free-tier limit, and break offline rendering. Option A's single Firestore write after upload satisfies both the quota constraint and the offline requirement with no architectural divergence from the existing schema.

---

## Decision

The avatar system uses three coordinated decisions. For path and versioning (sub-decision 1), avatars are stored at `avatars/{uid}/avatar.jpg` — a single overwrite-in-place file per user — and the URL written to Firestore always carries a `?v=<epoch-ms>` cache-bust suffix so `cached_network_image` detects the new image by URL-string comparison. This eliminates quota accumulation from old file versions while solving the stale-cache problem that plain Option A would cause. For client-side compression (sub-decision 2), the `flutter_image_compress` package resizes the picked image to a maximum of 512×512 px at JPEG quality 85 before upload; this bounds every avatar to under 100 KB regardless of the original photo resolution, protecting the shared 5 GB Spark quota that Note-Sharing will also consume. For URL persistence (sub-decision 3), the full download URL (including the `?v=<epoch-ms>` suffix) is stored in `users/{uid}.photoUrl` immediately after upload, consistent with the nullable String field defined in ADR 0001 and the URL-string denormalization pattern used for `hostPhotoUrl` (ADR 0003) and `friendPhotoUrl` (ADR 0004).

All Storage path strings are defined as constants in a new `lib/core/storage_paths.dart` file, separate from `lib/core/firestore_paths.dart`. The separation is justified because Storage paths and Firestore paths are consumed by different SDK clients (`FirebaseStorage` vs. `FirebaseFirestore`); co-locating them in a single file would either introduce a dependency on both SDKs in the constants file or force an arbitrary ordering that obscures which constants belong to which service. A dedicated `storage_paths.dart` file keeps the data-layer boundaries explicit and mirrors the existing `firestore_paths.dart` convention.

---

## Consequences

### storage.rules file

The Flutter Engineer must create `storage.rules` at the repository root with the following content as the authoritative specification:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    // Deny everything by default.
    allow read, write: if false;

    // Avatar uploads.
    // Owner-only write. File must be an image. Max size: 200 KB (204800 bytes),
    // consistent with 512x512 px JPEG at quality 85 with headroom.
    match /avatars/{uid}/avatar.jpg {
      allow read: if request.auth != null;
      allow write: if request.auth != null
        && request.auth.uid == uid
        && request.resource.contentType.matches('image/.*')
        && request.resource.size <= 204800;
    }

    // Notes path — reserved for the Note-Sharing feature.
    // Rules for this path are defined in a future Note-Sharing ADR; do not add rules here yet.
    // match /notes/{sessionId}/{noteId}/{fileName} { ... }

  }
}
```

Notes on the rules:
- `request.auth != null` is the only authentication gate Firebase Storage rules can enforce. KMUTT domain validation (`@mail.kmutt.ac.th` / `@kmutt.ac.th`) is enforced in Firestore rules via `isKmuttUser()` (ADR 0001); Storage rules cannot call Firestore helper functions and do not duplicate that check.
- The 200 KB size limit (204800 bytes) is set with headroom above the typical 30–80 KB output of a 512×512 JPEG at quality 85. Client-side compression (Sub-decision 2) keeps uploads well within this limit under normal conditions; the rule provides a server-side backstop against a client that skips compression.
- The content-type check (`image/.*`) prevents non-image uploads to the avatar path.
- The root `allow read, write: if false` default-deny rule ensures that paths not explicitly matched are blocked even if the Note-Sharing or future ADRs are delayed.

### New files required

- `storage.rules` — at repository root, adjacent to `firestore.rules`. Contains the Storage rules specified above.
- `lib/core/storage_paths.dart` — all Firebase Storage path templates as static string-returning methods; no Storage SDK import. Separate from `firestore_paths.dart` because Storage paths are consumed by `FirebaseStorage` while Firestore paths are consumed by `FirebaseFirestore`; mixing them in one file blurs the service boundary.
- `apps/mobile/lib/features/profile/data/datasources/avatar_datasource.dart` — the only file in the codebase permitted to import `firebase_storage`. Responsible for: compressing the image via `flutter_image_compress`, uploading to `avatars/{uid}/avatar.jpg`, calling `getDownloadURL()`, and appending the cache-bust suffix.
- `apps/mobile/lib/features/profile/domain/repositories/profile_repository.dart` — new file. Abstract interface. ADR 0002 defines `auth_repository.dart` for sign-in/sign-up flows; it does not define a profile repository. This interface owns profile mutation operations that are distinct from auth: `updateProfile({String? displayName, String? photoUrl, String? faculty, String? bio})`.
- `apps/mobile/lib/features/profile/data/repositories/profile_repository_impl.dart` — new file. Implements `ProfileRepository`. Calls `AvatarDatasource` for the upload, then writes `users/{uid}.photoUrl` and `users/{uid}.updatedAt` to Firestore via the existing `UserDatasource` (or directly to `cloud_firestore` if a user datasource does not yet exist at the time of implementation — the Flutter Engineer must check the existing datasource surface before creating a duplicate).

**New packages to add to `apps/mobile/pubspec.yaml`:**

- `firebase_storage: ^11.x` (latest stable) — not currently in `pubspec.yaml`; required for `FirebaseStorage`, `Reference`, and `UploadTask`.
- `image_picker: ^1.x` (latest stable) — not currently in `pubspec.yaml`; required to access the device photo gallery and camera.
- `flutter_image_compress: ^2.x` (latest stable) — not currently in `pubspec.yaml`; required for sub-decision 2 client-side resize. Supports Android and Web (the two required platforms).

### Upload flow contract

The Flutter Engineer must follow this exact sequence in `AvatarDatasource` and `ProfileRepositoryImpl`:

1. User picks image via `image_picker` (`ImagePicker().pickImage(source: ImageSource.gallery)`). `imageQuality` is left at the default (100); quality reduction is handled by `flutter_image_compress` in the next step, not by `image_picker`.
2. Compress the picked file using `flutter_image_compress`: max width 512, max height 512, JPEG quality 85. The output is a `Uint8List`.
3. Show local image preview immediately in the presentation layer using the `Uint8List` from step 2 (optimistic UI — display the local file while the upload is in progress; do not wait for the Firestore URL to update before showing the new avatar).
4. Upload the compressed `Uint8List` to Firebase Storage at `avatars/{uid}/avatar.jpg` using `putData()`.
5. Call `getDownloadURL()` on the `Reference` to obtain the persistent download URL string.
6. Append a cache-bust suffix: `'$downloadUrl?v=${DateTime.now().millisecondsSinceEpoch}'`. This is the value that will be stored in Firestore and propagated to all denormalized `photoUrl` fields.
7. Call `ProfileRepositoryImpl.updateProfile(photoUrl: cachebustedUrl)`, which writes `users/{uid}.photoUrl` and `users/{uid}.updatedAt` to Firestore.
8. The presentation layer discards the local optimistic preview once the Firestore stream emits the updated `photoUrl`.

**Error handling:**
- If the upload (step 4) fails, do not write to Firestore. Revert the UI to the previous `photoUrl`. Show an error snackbar.
- If the Firestore write (step 7) fails after a successful upload, retry once. If the retry also fails, log the inconsistency at `warning` level via `logger.dart` (message: "Avatar uploaded to Storage but Firestore update failed; photoUrl may be stale for uid: [uid redacted in log, use a non-PII identifier]"). Do not expose the URL or uid in the log message.
- On any failure, fire the `avatar_upload_failed` analytics event.

### Analytics events

Declare the following in `lib/core/analytics_events.dart` before any call site is written:

- `avatar_upload_started` — no payload; fired when the user confirms image selection before compression begins.
- `avatar_upload_succeeded` — no payload; fired after the Firestore `photoUrl` write succeeds.
- `avatar_upload_failed` — payload: `reason` (String enum: `compression_error` | `storage_error` | `firestore_error`); no PII.

---

## Reversal plan

**Sub-decision 1 (path and versioning strategy):** If the cache-bust query param causes issues with a future CDN or Storage rule (e.g., a CDN that treats `?v=` params as separate cache entries and bills per-variant), remove the suffix by stripping `?v=...` from all `users/{uid}.photoUrl` values in a one-time Firestore batch write. Update `AvatarDatasource` to store the bare `getDownloadURL()` URL and accept the stale-cache limitation, or switch to Option B (per-upload paths) and add a scheduled Cloud Function to prune old files once the team upgrades to a paid Firebase plan. Files that change: `AvatarDatasource`, `ProfileRepositoryImpl`, and a migration script; no domain entity, repository interface, or presentation-layer files change.

**Sub-decision 2 (client-side resize):** If `flutter_image_compress` introduces a build issue on Web or a future platform (e.g., if a desktop or iOS target is added), remove the compress step from `AvatarDatasource` and replace it with `image_picker`'s `imageQuality: 80` as the sole compression mechanism. Steps: (a) remove `flutter_image_compress` from `pubspec.yaml`; (b) change `AvatarDatasource` to pass `imageQuality: 80` to `ImagePicker().pickImage()`; (c) increase the `storage.rules` size limit to 2097152 (2 MB) to accommodate larger unresized uploads. No domain entity, repository interface, or presentation-layer files change. A Storage rules update requires redeployment via `firebase deploy --only storage`.

**Sub-decision 3 (URL persistence strategy):** If the team decides to store only the Storage path in Firestore (e.g., to support URL rotation without re-uploading), write a migration script that: (a) reads every `users/{uid}.photoUrl` value; (b) strips the download URL back to the Storage path `avatars/{uid}/avatar.jpg`; (c) updates the Firestore field. Update `AvatarDatasource` to store the path instead of the URL. Update `ProfileRepositoryImpl` and every downstream read site that calls `getDownloadURL()`. Update all denormalized `hostPhotoUrl` and `friendPhotoUrl` fields on session and friend documents to store paths instead of URLs. A new ADR is required before this change begins because it affects the ADR 0001 schema, ADR 0003, and ADR 0004.
