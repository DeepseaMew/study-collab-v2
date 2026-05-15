# 0002 — Offline-First Scope: Selective Read Cache via Firestore SDK

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-05-15 |
| Architect session | claude-sonnet-4-6 / DeepseaMew / 2026-05-15 |
| Affects | Sessions, Friends, Chat, Search, Rating, Note-Sharing, Calendar, core/errors, shared connectivity infrastructure |

---

## Team approval

Approved by: DeepseaMew
Date: 2026-05-15
Notes: -

---

## Problem

Study Collab has no agreed policy on which features are expected to function without a network connection. Without a policy, each feature team makes independent assumptions: some may queue writes optimistically and silently drop them, others may crash on a Firestore timeout, and others may show a blank screen. This inconsistency produces an unpredictable user experience and creates a real risk of data corruption — for example, a rating submitted while offline could be written to a stale document without server-side timestamp validation, violating the rating feature's explicit requirement for `request.time`. The absence of a shared policy also makes it impossible for the QA engineer to write a coherent offline test matrix. A decision is needed that classifies every feature in the app as either offline-capable (read-only cached view) or online-only, and that specifies exactly how the implementation signals and enforces each classification.

---

## Constraints

- The domain layer must remain free of Flutter and Firebase imports; offline state must be communicated through domain-layer sealed error classes, not raw Firebase exceptions.
- No additional local database package (Drift, Hive, SQLite, or any custom store) may be introduced. The only persistence mechanism permitted is the Firestore SDK's built-in offline cache.
- Write operations that require server-side validation — rating (requires `request.time`), session state changes, friend request mutations — must not be attempted while the device is offline.
- The KMUTT email gate and email verification check run on Firebase Auth, which itself requires connectivity for initial sign-in; this is acceptable because Auth already enforces this.
- All timestamp fields use `request.time` server-side in Firestore rules; no client-generated timestamp may bypass this.
- Firestore rules must use `diff().affectedKeys()` for field-level write validation on all collections; this rule is enforced regardless of offline scope.
- Users may only read and write their own documents unless their role explicitly permits otherwise; offline caching must not surface documents the user would not be permitted to read online.
- No PII may appear in log output; the offline state flag itself is not PII, but user identifiers must not be logged when reporting cache misses.
- All error types must be sealed classes in `lib/core/errors/`; never throw raw strings or unwrapped `FirebaseException` objects across layer boundaries.
- Package imports only (`package:mobile/...`); never relative imports.

---

## Options considered

### Option A — Full offline-first with a local database as the source of truth

A dedicated local database (Drift with SQLite on mobile, or Hive on web) stores all data. Firestore becomes a remote sync target. A custom sync engine reconciles local writes with Firestore when connectivity is restored. The local DB is the single source of truth for all reads.

**Trade-offs**
- Pro: Every feature works fully offline, including writes; users can compose messages, submit ratings, and create sessions without connectivity.
- Pro: Well-understood pattern for consumer apps with aggressive offline requirements.
- Con: Requires a sync engine — conflict resolution, optimistic locking, and retry queues — estimated at significant additional complexity (new packages, new domain layer abstractions, new test surface).
- Con: Rating and note-sharing have explicit server-side timestamp requirements (`request.time`). Queuing these writes offline and replaying them later means the server timestamp recorded is the replay time, not the user action time — this may be acceptable for notes but is semantically wrong for ratings, where the timestamp anchors the end-of-session window.
- Con: Introduces Drift or Hive, adding package dependencies that conflict with the "no extra local DB" constraint established for this project.
- Con: The sync engine becomes a fifth architectural layer that every feature team must understand and test; QA matrix grows substantially.
- Reversal cost: Very high. Removing a sync engine requires deleting all local DB schema migrations, all conflict-resolution logic, and rewriting every repository implementation. All data/repositories/ files across every feature are affected.

### Option B — Online-only for all features

No offline behaviour is intentional. When the device loses connectivity, every screen shows an error state. Providers surface a `NetworkUnavailableError` and the UI displays a retry button. Firestore's SDK cache is disabled or ignored.

**Trade-offs**
- Pro: Simplest possible implementation; no connectivity-awareness code beyond a single error boundary.
- Pro: Zero risk of stale write corruption or timestamp mismatch.
- Con: KMUTT students frequently use the app on campus Wi-Fi that drops intermittently. The friends list and session browse screen are read-heavy and their data changes infrequently; forcing a hard error on every connectivity blip degrades UX unnecessarily for the most common usage patterns.
- Con: Disabling the Firestore SDK cache wastes a capability that ships for free with the Firebase SDK.
- Con: Session browse showing a blank screen when the user's phone briefly loses signal is a product regression relative to what Firestore's default cache already provides at no cost.
- Reversal cost: Low for features that were online-only by choice. Moderate for features where offline support is added later, because provider contracts and error handling must be extended without breaking existing callers.

### Option C — Selective offline reads via Firestore SDK cache only (chosen)

Firestore SDK offline persistence is enabled at app startup. Features whose data is read-heavy and whose staleness is tolerable (sessions browse, friends list, calendar) serve cached reads transparently. All write operations and all features where stale data is semantically dangerous (chat, search, rating, note-sharing) are blocked while offline and surface a typed domain error. A shared connectivity helper — wrapping `connectivity_plus` and Firestore's `SnapshotMetadata.isFromCache` — exposes an `isFromCache` flag that providers pass through to the UI as a banner or badge.

**Trade-offs**
- Pro: No new packages beyond `connectivity_plus`, which is a lightweight dependency with no native database overhead.
- Pro: The Firestore SDK cache is already active by default on Android and iOS; enabling it explicitly on web is a one-line change. No sync engine or conflict resolution is needed.
- Pro: Write-blocking while offline prevents any violation of the `request.time` server-side timestamp requirement.
- Pro: The domain layer remains clean: one sealed error class (`OfflineWriteAttemptError`) covers all blocked write paths.
- Con: Cached reads may be stale; users on the session browse screen may see a session that was deleted while they were offline. A stale-data banner is required to set expectations.
- Con: Chat history is read-only while offline — users cannot send messages. This is an explicit product constraint, but it may surprise users who expect messaging apps to queue outgoing messages.
- Con: Firestore SDK cache size is bounded (default 100 MB on mobile; configurable). Very active users with large session histories may find the cache evicting older documents.
- Reversal cost: Moderate. Moving from Option C to full offline-first (Option A) requires adding a local DB, writing a sync engine, and extending every repository interface in domain/ to expose optimistic-write semantics. Estimated files affected: all `data/repositories/` and `domain/repositories/` across Sessions, Friends, Chat, Calendar. Moving from Option C to online-only (Option B) is low cost: remove the `isFromCache` flag from providers and disable Firestore persistence.

---

## Decision

Option C is chosen. The Firestore SDK offline cache is already shipped with the Firebase SDK used by this project; enabling it costs one configuration call and no additional dependencies. The two features most likely to be used during intermittent connectivity — session browsing and friends list — are read-heavy and tolerate short-term staleness when accompanied by a clear UI indicator. All write paths and all features where stale data causes correctness problems (rating requires `request.time`; chat requires ordering guarantees; search results must reflect the live index; note-sharing requires Firebase Storage reachability) are blocked at the use-case boundary with a typed `OfflineWriteAttemptError` from `lib/core/errors/`. This approach satisfies the domain isolation constraint — no Firebase type crosses into the domain layer — while delivering a materially better experience than online-only for the most common read patterns on a university campus network.

---

## Feature classification

The table below is authoritative. The Flutter Engineer must implement each feature exactly as classified here; any deviation requires a new or amended ADR.

| Feature | Offline classification | Reason |
|---|---|---|
| Auth (sign-in, email verification) | Online-only | Firebase Auth requires network for token issuance and email verification. flutter_secure_storage persists the session token so already-authenticated users do not need to re-authenticate on every launch, but initial sign-in and email verification are always online. |
| Sessions — browse / list | Cached read (offline-capable) | The session list is read-heavy and changes at human-pace (hosts create/end sessions, not at sub-second frequency). A stale list with a "you are offline" banner is better than a blank screen. No write is involved in browsing. |
| Sessions — create / edit / delete / end | Online-only | All mutations require Firestore writes. End-session also triggers the rating availability window, which must use `request.time` server-side. Optimistic offline writes would corrupt the host-approval flow and the rating timestamp. |
| Sessions — join request (public) | Online-only | Joining requires a write to the session's member subcollection; host approval is a subsequent write. Both must be online. |
| Sessions — PIN / invite code entry (private) | Online-only | Invite code validation is a Firestore read that must be live to prevent replay of expired codes. |
| Friends — friends list view | Cached read (offline-capable) | The friends list changes only when a friend request is accepted or a user unfriends; this is infrequent. Showing a cached list with a staleness indicator is safe and useful. |
| Friends — send / accept / decline / unfriend | Online-only | All four actions are writes. Friendship is bidirectional; both documents must be updated atomically. Queuing offline would create inconsistency if the other party acts before the write replays. |
| Chat — DM and group message history (read) | Online-only | Although Firestore caches recent messages, chat ordering depends on server timestamps. Surfacing a partially-cached, out-of-order message thread is worse than a clear offline error. Message history is classified online-only to avoid this UX hazard. |
| Chat — send message | Online-only | Writing a message requires a Firestore write with a server timestamp. Queuing offline is not permitted under Option C. |
| Search and filtering | Online-only | Explicitly stated as online-only in CLAUDE.md. Search queries hit a live Firestore index; cached partial results would produce misleading "no results" responses. |
| Rating — submit thumbs-up | Online-only | Explicitly stated as online-only in CLAUDE.md. Rating requires `request.time` server-side for the submission timestamp; any offline queue would record the replay time, not the user's action time, corrupting the end-of-session window. |
| Rating — view profile score | Online-only | The score is a derived aggregate; a cached value may reflect votes that were cast before the session ended, making the displayed score incorrect. |
| Note-Sharing — upload / delete | Online-only | Requires a Firebase Storage write followed by a Firestore document write. Both are unavailable offline. The 50-note cap check must read the live subcollection count. |
| Note-Sharing — view / download | Online-only | Notes are stored in Firebase Storage; download URLs resolve at runtime. The Firestore SDK cache stores document metadata but not the binary file content. Treating note viewing as online-only avoids showing broken download links. |
| Calendar — session history and upcoming view | Cached read (offline-capable) | Calendar data is a filtered projection of the sessions collection, which is already cached for browse. Showing a cached calendar with a staleness banner is accurate enough for planning purposes. No writes occur in the calendar view. |

---

## Implementation guidance

### Enabling Firestore offline persistence

In `apps/mobile/lib/core/` (or the Firebase initialization site, before any Firestore call), enable persistence explicitly:

```
// Android and iOS: persistence is ON by default.
// Web requires explicit opt-in.
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // or a bounded value, e.g. 104857600 for 100 MB
);
```

This call belongs in the Firebase bootstrap code, not in any feature's data layer. The architect will create a separate ADR if the initialization site is disputed.

### Detecting offline state and cache provenance

Two complementary signals are available:

1. `connectivity_plus` — `ConnectivityResult.none` means no network interface is active. This is the fast, synchronous signal used to block write attempts before they are dispatched.
2. `SnapshotMetadata.isFromCache` — present on every `DocumentSnapshot` and `QuerySnapshot` returned by Firestore. This is the accurate, per-read signal used to annotate read results.

A shared infrastructure class in `apps/mobile/lib/core/` (not inside any feature) must expose these two signals. A suggested interface (domain layer, no Firebase types):

```
// lib/core/connectivity/connectivity_service.dart
abstract interface class ConnectivityService {
  /// True when the device has no active network interface.
  bool get isOffline;

  /// Stream that emits true when connectivity is lost, false when restored.
  Stream<bool> get offlineStream;
}
```

The Firestore-backed implementation lives in `lib/core/connectivity/` under `data/` if the team adopts a core-layer data/domain split, or directly in `lib/core/` as an infrastructure class.

### How providers expose cache provenance

Every Riverpod provider that serves a cacheable read (Sessions list, Friends list, Calendar) must return a result type that includes the cache flag. Use a Freezed value type:

```
// lib/core/connectivity/cached_result.dart  (domain layer — no Firebase import)
@freezed
class CachedResult<T> with _$CachedResult<T> {
  const factory CachedResult({
    required T data,
    required bool isFromCache,
  }) = _CachedResult;
}
```

The data-layer repository implementation maps `SnapshotMetadata.isFromCache` to this field before returning to the domain layer. The domain layer never imports `SnapshotMetadata` directly.

Provider example pattern (presentation layer):

```
// In the screen/widget:
final result = ref.watch(sessionListProvider);
result.when(
  data: (cachedResult) {
    if (cachedResult.isFromCache) {
      // Show OfflineBanner widget (shared/widgets/offline_banner.dart)
    }
    // Render cachedResult.data
  },
  loading: () => ...,
  error: (e, _) => ...,
);
```

The `OfflineBanner` is a shared widget in `apps/mobile/lib/shared/widgets/offline_banner.dart`. It must not contain business logic; it is purely presentational.

### Blocking write operations while offline

Before dispatching any write use case, the use case class must check `ConnectivityService.isOffline`. If offline, it must throw (or return, depending on the use case's return type convention) a typed domain error — never a raw `FirebaseException`.

The sealed error class to add in `lib/core/errors/`:

```
// lib/core/errors/app_error.dart  (extend the existing sealed class)
sealed class AppError { ... }

final class OfflineWriteAttemptError extends AppError {
  const OfflineWriteAttemptError({required this.operation});
  final String operation; // e.g. 'sendMessage', 'submitRating'
}
```

Use-case pattern:

```
// In any write use case (domain layer — no Firebase import):
class SubmitRatingUseCase {
  const SubmitRatingUseCase(this._repo, this._connectivity);

  final RatingRepository _repo;
  final ConnectivityService _connectivity;

  Future<Either<AppError, void>> call(RatingParams params) async {
    if (_connectivity.isOffline) {
      return Left(const OfflineWriteAttemptError(operation: 'submitRating'));
    }
    return _repo.submitRating(params);
  }
}
```

The presentation layer translates `OfflineWriteAttemptError` into a user-facing snackbar: "You are offline. Please reconnect to perform this action." No stack trace or Firebase error message is shown to the user.

### Logging

Log connectivity events at `info` level and write-block events at `warning` level through `lib/core/logger.dart`. No PII (user email, UID, or session content) in any log message.

```
// Example — warning level, no PII:
logger.warning('Write blocked: offline', extra: {'operation': 'submitRating'});
```

---

## Consequences

- The Friends list and Sessions browse screen will remain functional during intermittent connectivity, which is the most common failure mode on KMUTT campus Wi-Fi.
- A `CachedResult<T>` wrapper type and `OfflineBanner` shared widget become cross-feature infrastructure that every cached-read provider must adopt; the Flutter Engineer must implement these before any cacheable feature is built.
- Chat message history is intentionally degraded to online-only, which may surprise users familiar with mobile messaging apps that queue outgoing messages; this is an explicit product decision and must be documented in user-facing help text.
- Rating integrity is fully preserved: `request.time` is always the server time of the actual Firestore write, never a client timestamp or a replayed timestamp.
- The QA engineer's offline test matrix covers two categories: (a) cached reads — verify that each offline-capable screen renders with a staleness banner and does not show an error state, and (b) write blocks — verify that each online-only write surface returns `OfflineWriteAttemptError` and shows the correct snackbar.
- Firestore SDK cache is bounded. If the default 100 MB cache fills up, Firestore evicts least-recently-used documents. Users with very large session histories may find older cached sessions missing. The cache size is configurable at the initialization site; a future ADR may adjust this limit.
- No new package is required beyond `connectivity_plus`. The pubspec change is minimal and does not affect the build pipeline.
- The `ConnectivityService` abstraction and `CachedResult<T>` type must be created before any feature that depends on them. This is a mild sequencing constraint for the Flutter Engineer.
- If the team later adopts full offline-first (Option A), the `ConnectivityService` interface and `OfflineWriteAttemptError` class remain useful; only the repository implementations change.

---

## Reversal plan

If the team decides Option C is insufficient and wants full offline-first (Option A):

1. A new ADR supersedes this one; Status of this record is updated to "Superseded by NNNN".
2. The architect specifies the chosen local DB package (Drift for mobile, or an in-memory fallback for web) and the sync strategy.
3. The Flutter Engineer adds the local DB package to `apps/mobile/pubspec.yaml` and `packages/` if shared.
4. Every `domain/repositories/` interface across Sessions, Friends, Chat, Calendar, and Rating must be extended with optimistic-write method signatures.
5. Every `data/repositories/` implementation must be rewritten to write to the local DB first and sync to Firestore asynchronously.
6. The rating use case requires special handling: the sync engine must mark rating writes as requiring server-timestamp confirmation and surface a pending state in the UI until the write is acknowledged.
7. The `CachedResult<T>` type and `OfflineBanner` widget remain in place but may be extended to show a "pending sync" state in addition to "from cache".
8. The QA engineer must extend the offline test matrix to cover write-queue flushing, conflict resolution, and sync failure recovery.

If the team decides Option C is too permissive and wants fully online-only (Option B):

1. A new ADR supersedes this one.
2. Remove `persistenceEnabled: true` from the Firestore settings call.
3. Remove the `isFromCache` field from `CachedResult<T>` (or remove the type entirely if all providers return plain data).
4. Remove the `OfflineBanner` widget and all call sites.
5. The `OfflineWriteAttemptError` class and `ConnectivityService` remain useful for showing user-facing error messages; the write-block logic stays unchanged.
