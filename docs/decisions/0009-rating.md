# 0009 — Rating Feature Architecture

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-05-25 |
| Architect session | claude-sonnet-4-6 / NichapaJongKmutt / 2026-05-25 |
| Affects | Rating (domain, data, presentation), sessions presentation screens (ADR 0003 amendment), Firestore schema (ADR 0001 amendment), core/analytics_events.dart, core/firestore_paths.dart, core/remote_config_startup.dart (ADR 0008), pubspec.yaml |

---

## Team approval

Approved by: NichapaJongKmutt
Date: 2026-05-25
Notes: —

---

## Problem

ADR 0001 defines the `sessions/{sessionId}/ratings/{raterUid}` Firestore schema and security rules but stops short of specifying the rating feature's UX flow, document-ID strategy, profile score storage approach, feature flag mechanism, and WriteBatch atomicity contract. Three design conflicts exist that, if left unresolved, will produce incompatible implementations. First, ADR 0001 models the ratings document ID as `raterUid`, enforcing one document per rater per session with a single `rateeUid` String field — but the feature requirement allows a rater to rate multiple members in the same session, which a single-`rateeUid` document cannot represent. Second, the profile score formula `thumbsUpReceived / endedSessionsJoined` requires two aggregate counts that are expensive on every profile read if computed on demand; the ADR 0001 schema already includes `users/{uid}.profileScore` as a denormalized float, but the contract for when and how that field is updated is not specified beyond "same WriteBatch as each rating creation." Third, no feature flag placement is specified, and two other flag mechanisms now exist in the codebase (Firebase Remote Config via ADR 0008 and a previous Firestore-based pattern), creating risk of fragmentation. Without authoritative answers to all three conflicts, engineers will implement incompatible document ID strategies, divergent score update sequences, and mismatched flag integration points. Additionally, the end-of-session rating UX must be defined precisely because the rating popup must not block the host's ability to mark the session as ended and must not be triggered for non-members who arrive at the screen after the fact.

---

## Constraints

- Domain layer has zero Flutter or Firebase imports. All Firestore path strings are constants in `lib/core/firestore_paths.dart` only.
- Repository interfaces in `domain/repositories/`; implementations in `data/repositories/`. No Firestore types cross the domain boundary.
- Entities use Freezed; datasource models use Freezed + json_serializable.
- All Riverpod providers use `@riverpod` codegen (riverpod_generator); no hand-written `StateNotifier`.
- Business logic (self-rating guard, duplicate-rating guard, score formula, edge-case division-by-zero) must not be defined in the presentation layer; it belongs in the use case.
- No provider may access Firestore directly; all access goes through the repository layer.
- Rating is available only after the host ends a session (`status == 'ended'`); Firestore rules enforce `sessionEnded(sessionId)` as a precondition on every rating create.
- No client-generated timestamps. Server-side `request.time` only, enforced in rules with `request.resource.data.ratedAt == request.time`.
- A rater may not rate themselves. Enforced both in `SubmitRatingsUseCase` (throws `RatingError.selfRatingNotAllowed`) and in Firestore rules (`request.resource.data.rateeUid != raterUid`).
- Each (rater, ratee) pair per session is unique — once a rating document exists for that pair it is immutable (`allow update: if false; allow delete: if false`).
- `profileScore` formula: `thumbsUpReceived / endedSessionsJoined`. Edge case: when `endedSessionsJoined == 0`, `profileScore = 0.0`. This guard lives in the use case.
- The rating WriteBatch must be atomic: all rating documents for a submission plus the `users/{rateeUid}.profileScore` update for each ratee must commit or all roll back together.
- Rating is online-only; no offline queue. The use case must throw `RatingError.offlineNotSupported` when Firestore returns an unavailable error.
- `firebase_remote_config` is already declared in `apps/mobile/pubspec.yaml` per ADR 0008. `lib/core/remote_config_startup.dart` is already established by ADR 0008 and must not be duplicated.
- Domain errors for this feature are sealed subclasses of a new `RatingError` class in `lib/core/errors/rating_error.dart`.
- KMUTT email gate (`@mail.kmutt.ac.th` / `@kmutt.ac.th`) enforced in Firestore rules via `isKmuttUser()` (ADR 0001).
- All log calls go through `lib/core/logger.dart` only; never `print()`. No PII in any log message or Crashlytics key.
- Every analytics event declared in `lib/core/analytics_events.dart` before use.
- No unbounded `ListView`; always `ListView.builder` with `itemCount`.
- All remote images (member avatars in the rating popup) must render through `cached_network_image`; never `Image.network` directly.
- Index 2 (`sessions`: `memberUids array-contains`, `status asc`, `endedAt desc`) and Index 6 (`sessions/{sessionId}/ratings`: collection-group, `rateeUid asc`, `ratedAt desc`) are already defined in ADR 0001 and are sufficient for this feature. No new composite index is required.

---

## Options considered

### Sub-decision 1 — Rating document ID strategy: how to support rating multiple members per session

The ADR 0001 schema uses `raterUid` as the document ID of `sessions/{sessionId}/ratings/{raterUid}`, with `rateeUid` as a single String. This enforces one document per rater per session but allows rating only one ratee. The feature requirement is for a rater to rate any number of other session members. Three options exist to reconcile this conflict.

| | Option A — Document ID `{raterUid}_{rateeUid}` (composite key) | Option B — Document ID `raterUid`; store `rateeUids` as `List<String>` | Option C — Keep `raterUid` document ID; restrict to one ratee per rater |
|---|---|---|---|
| Summary | Change the document path to `sessions/{sessionId}/ratings/{raterUid}_{rateeUid}`; one document per (rater, ratee) pair per session; `rateeUid` remains a String field | Keep document ID as `raterUid`; replace single `rateeUid` String with a `rateeUids` List\<String\>; one document per rater per session | Keep existing ADR 0001 schema exactly as written; UI constrains rater to pick exactly one ratee |
| Schema change required | Yes — ADR 0001 amendment required; document ID format changes; rules wildcard changes from `{raterUid}` to `{ratingId}`; self-rating prevention requires extracting raterUid from the document field rather than the path wildcard | Yes — ADR 0001 amendment required; `rateeUid` field type changes from String to List\<String\>; rules must iterate over the list (Firestore rules do not support list iteration for field-level checks — this is a hard constraint) | No — ADR 0001 schema and rules unchanged |
| Duplicate prevention | Natural: document ID uniqueness prevents duplicate (rater, ratee) pair per session without an extra rule | Impossible to prevent a duplicate `rateeUid` appearing twice in the same list using Firestore rules (`!list.hasAll(...)` patterns are not supported for intra-document duplicate checks) | Natural: document ID uniqueness prevents a second submission from the same rater; but second submission to a different ratee is blocked because the document already exists |
| Index 6 correctness | Correct: collection-group count on `rateeUid asc` counts one document per (rater, ratee) pair, which is what the formula numerator requires (number of thumbs-up received by each ratee) | Incorrect: collection-group count on `rateeUids` would require `array-contains` on a collection-group, which is not supported in Firestore | Correct: but only one thumb-up per rater per session is possible |
| Firestore rules complexity | Medium — wildcard changes to `{ratingId}`; self-rating check changes to `request.resource.data.raterUid != request.resource.data.rateeUid`; auth ownership check changes to `request.resource.data.raterUid == request.auth.uid` | High — Firestore rules cannot iterate over a List to enforce that `rateeUid != raterUid` for every element; would require moving that invariant entirely to the client, violating the security model | Low — rules unchanged from ADR 0001 |
| Reversal cost | Medium — changing document ID after data exists requires a migration; reversal would require deleting all existing rating documents and recreating with new IDs | High — changing from List to String after data exists requires a migration and a document-ID change simultaneously | Low — no change needed; but feature is permanently restricted to one ratee per rater |
| Recommendation | Yes | No | No |

Option A is recommended. Firestore rules for Option B cannot enforce the `rateeUid != raterUid` invariant over a list, which is a hard security gap. Option C permanently degrades the feature below the stated requirement. Option A requires an ADR 0001 amendment (changing the document path wildcard from `{raterUid}` to `{ratingId}` and adjusting the rule assertions to use document-field values rather than the path wildcard for raterUid), but the resulting schema is correct, secure, and supports the formula numerator calculation in Index 6 exactly. The composite document ID `{raterUid}_{rateeUid}` is constructed in the data layer only (`RatingDatasource`) and never exposed to the domain or presentation layers; the domain entity carries separate `raterUid` and `rateeUid` String fields.

---

### Sub-decision 2 — Rating flow UX: how the rating popup integrates with the existing session detail screen

| | Option A — Rating popup shown immediately after end-session confirmation popup closes | Option B — Persistent rating banner on session detail screen after `status == 'ended'` | Option C — Separate GoRouter route `/sessions/:id/rate` pushed by the end-session popup |
|---|---|---|---|
| Summary | Host confirms end-session in the existing end-session popup; on success, the presentation layer shows a rating `AlertDialog` or `BottomSheet` in the same screen context; the host rates members before or after dismissing | A `RatingBannerWidget` renders at the top of the session detail screen whenever `status == 'ended'` and the current user has not yet rated; tapping opens a rating bottom sheet | End-session popup calls `context.push('/sessions/$id/rate')` on success; a dedicated `RatingScreen` handles the full rating flow before navigating back |
| ADR 0003 alignment | Works within existing `HostSessionDetailScreen` and `MemberSessionDetailScreen` without new routes | Works within existing screens; banner is a widget added to each screen's scaffold | Requires a new route in `app_router.dart`; amends ADR 0003 route table |
| Who sees the rating UI | Host sees it immediately after ending; members see it the next time they open the session detail (via the banner condition on `status == 'ended'`) — Option A does not naturally surface the rating to members unless combined with a banner | Both host and members see the banner independently whenever they open the ended session; the banner disappears once the user has submitted ratings (tracked locally by checking whether the user's rating document exists) | Host is pushed to the route immediately; members would need a separate navigation entry point |
| Timing | Rating is optional and non-blocking — the popup has a "Skip" action; the session is already ended in Firestore before the popup appears | Rating is non-blocking by nature; banner can be dismissed or ignored | Rating is non-blocking — user can navigate back without rating |
| Deep-linkable | No | No | Yes — route has its own path |
| Implementation effort | Low — `showModalBottomSheet` in `HostSessionDetailScreen.onEndSessionConfirmed`; members see the banner (Option B combined) | Low — stateless widget reads `status` and `ratingSubmitted` from providers | Medium — new route, new screen, new route constant |
| Reversal cost | Low | Low | Low — remove route and screen |
| Recommendation | Partial — recommended for host-triggered flow; combined with a persistent banner for member-triggered flow (see Decision) | Partial — recommended as the member entry point and as a fallback for the host if they dismissed the popup | No |

The recommended approach is a combination: the host sees the rating bottom sheet immediately after confirming end-session (Option A); all members (including the host, as a fallback) see a persistent rating banner on the ended session detail screen (Option B). The banner is hidden once the user's rating document(s) for the session exist in Firestore. A separate route (Option C) is not recommended because it adds navigation complexity for a flow that is initiated from a single well-known screen and does not require independent deep-linking.

---

### Sub-decision 3 — Profile score storage: denormalized field vs. on-read calculation

| | Option A — Denormalized `profileScore` float on `users/{uid}`, updated in the same WriteBatch as each rating creation | Option B — On-read calculation: collection-group count query on every profile open |
|---|---|---|
| Summary | `profileScore` is pre-calculated and stored on the user document after every rating write; the WriteBatch that creates the rating document(s) also updates `users/{rateeUid}.profileScore` | No stored field; when the profile screen opens, two `count()` queries run: (1) collection-group count on `ratings` where `rateeUid == uid`; (2) count on `sessions` where `memberUids array-contains uid` and `status == 'ended'` |
| Read cost | One user document read — `profileScore` is included in the document that is already loaded for the profile screen | Two `count()` queries per profile open; collection-group count (Index 6) spans all sessions; both queries run on the Firestore server but consume quota |
| Write complexity | WriteBatch must include both the rating document(s) and the `users/{rateeUid}.profileScore` update; requires reading the two count values before constructing the batch | No extra write needed; on-read calculation is stateless |
| Staleness | Immediately consistent: the batch is atomic; the profile screen always reads the current value | Always consistent at read time by definition |
| Offline support | `profileScore` readable from Firestore offline cache | Count queries do not work offline; profile score unavailable offline |
| Reversal cost | Medium — removing the denormalized field requires migrating existing `profileScore` values and removing the batch update from `RatingRepositoryImpl` | Low — add the denormalized field and batch update at any time |
| Recommendation | Yes | No |

Option A is recommended. `profileScore` is already declared as a field on `users/{uid}` in ADR 0001 with the formula and WriteBatch requirement explicitly stated; this decision formalizes and specifies the implementation contract. The two aggregate count queries needed for on-read calculation (Index 6 collection-group + Index 2) are more expensive per profile view than a single document read, and the profile screen is expected to be a high-frequency read surface. Offline cache availability is a secondary benefit. The WriteBatch complexity is bounded: the data layer executes the two counts once before constructing the batch, then commits atomically.

---

### Sub-decision 4 — Feature flag mechanism

| | Option A — Firebase Remote Config boolean `rating_enabled` (reuse `lib/core/remote_config_startup.dart` from ADR 0008) | Option B — Firestore document `config/feature_flags.rating` | Option C — Compile-time constant |
|---|---|---|---|
| Summary | Boolean flag read from Firebase Remote Config via the existing `remoteConfigStartup` provider established by ADR 0008; toggled from Firebase Console without a new build | Single Firestore document holding the flag; read on app startup; real-time stream if needed | `const bool kRatingEnabled` in code; requires a code change and new release to toggle |
| Toggle without release | Yes | Yes | No — violates stated requirement |
| Infrastructure | Remote Config free tier; `firebase_remote_config` package already in `pubspec.yaml` per ADR 0008 | One Firestore read per app launch; package already available | None |
| Offline default | Falls back to last cached value; `false` on first launch (safe-off-by-default) | Falls back to Firestore offline cache | Always the compiled value |
| Codebase consistency | Consistent with ADR 0008 pattern; `lib/core/remote_config_startup.dart` already exists | Introduces a second flag mechanism; inconsistent with ADR 0008 | N/A |
| Reversal cost | Low — replace `RemoteConfig.getBool` call with a constant; delete flag from Remote Config console | Low | N/A |
| Recommendation | Yes | No | No |

Firebase Remote Config is recommended. The package and the startup provider already exist from ADR 0008; adding a second flag to the same mechanism requires zero new infrastructure and maintains a single source of truth for all feature flags. The Firestore option would introduce a second flag mechanism inconsistent with the ADR 0008 precedent. Option C violates the stated requirement that the feature must be toggleable without a release.

---

### Sub-decision 5 — Rating WriteBatch atomicity strategy

| | Option A — Single WriteBatch per ratee: for each ratee the rater thumbs-up, one WriteBatch contains the rating document creation and the `users/{rateeUid}.profileScore` update | Option B — Cloud Function triggered by rating document write to recalculate `profileScore` server-side |
|---|---|---|
| Summary | Client constructs one WriteBatch per ratee; each batch contains exactly two document writes (rating doc + user doc `profileScore` update); batches are executed sequentially in the data layer | Client writes only the rating document(s); a Cloud Storage trigger (or Firestore trigger) fires for each new rating and recalculates `profileScore` server-side |
| Atomicity | Per-ratee atomic: each (rating doc + score update) pair either both commit or neither does; a failure on one ratee's batch does not affect other ratees' batches | Rating doc is committed first; score update happens asynchronously; there is a window where the rating doc exists but the score has not yet been updated |
| Write complexity | Medium — data layer executes N WriteBatches sequentially (where N = number of ratees thumbed-up in this submission); each batch requires reading the two count values first | Low on the client; High in infrastructure — requires a Cloud Function, Firestore trigger setup, and service account permissions |
| Offline support | No — count queries and WriteBatches require connectivity; consistent with the rating-is-online-only constraint | No — rating doc write would be queued offline, but trigger fires only after connectivity returns; score staleness window is longer |
| Infrastructure cost | Firestore writes only; no Cloud Function invocations | Firestore writes + Cloud Function invocations per rating |
| Reversal cost | Low — replace batch construction in `RatingRepositoryImpl` with a single Cloud Function call if needed | High — remove Cloud Function, add batch construction to client |
| Recommendation | Yes | No |

Option A is recommended. The rating-is-online-only constraint means connectivity is guaranteed when the WriteBatch executes, so the two-count read before each batch is always possible. Sequentially executing one WriteBatch per ratee keeps the atomicity guarantee per (rater, ratee) pair without requiring Cloud Function infrastructure. ADR 0001 explicitly states "both the rating creation and the score update must be in the same WriteBatch," making Option A the architecturally mandated choice. A Cloud Function (Option B) introduces latency, infrastructure cost, and asynchronous consistency windows that are inconsistent with the immediate profile score update shown on the profile screen after rating.

---

## Decision

Sub-decision 1 (document ID strategy): The ratings document ID is changed from `raterUid` to a composite key `{raterUid}_{rateeUid}` constructed in the data layer only. This supports one document per (rater, ratee) pair per session, satisfying the requirement for a rater to rate multiple members. ADR 0001 is amended (Amendment A below) to change the path wildcard from `{raterUid}` to `{ratingId}`, update the Firestore rules to derive `raterUid` and `rateeUid` from document fields rather than the path wildcard, and update the schema table. The domain entity, repository interface, and all use cases are unaffected by the ID format because the composite key is assembled in `RatingDatasource` only.

Sub-decision 2 (rating flow UX): The rating popup is a `ModalBottomSheet` shown to the host immediately after the end-session confirmation succeeds (`HostSessionDetailScreen.onEndSessionConfirmed`). For members — and as a fallback for the host if they dismissed the popup — a `RatingBannerWidget` is rendered at the top of the session detail screen whenever `status == 'ended'` and the current user has not yet submitted ratings for that session (determined by checking whether any rating document with `raterUid == currentUserId` exists in the session's ratings subcollection). No new GoRouter routes are added. The rating bottom sheet is a single self-contained widget pushed as a modal; it is not a screen.

Sub-decision 3 (profile score storage): `users/{uid}.profileScore` is a denormalized float updated atomically in the same WriteBatch as each rating document creation, consistent with the ADR 0001 schema and formula. The data layer reads the two count values (Index 6 collection-group count for thumbs-up received; Index 2 count for ended sessions joined) before constructing each WriteBatch. When `endedSessionsJoined == 0`, `profileScore` is written as `0.0`.

Sub-decision 4 (feature flag): The feature flag `rating_enabled` is a boolean read from Firebase Remote Config using the existing `lib/core/remote_config_startup.dart` provider established by ADR 0008. When `rating_enabled` is `false`, the rating banner is hidden and the end-session popup does not trigger the rating bottom sheet. The flag defaults to `false` on first launch before any Remote Config fetch resolves.

Sub-decision 5 (WriteBatch atomicity): The data layer executes one WriteBatch per ratee, sequentially. Each WriteBatch contains exactly two document writes: the rating document at `sessions/{sessionId}/ratings/{raterUid}_{rateeUid}` and the `users/{rateeUid}.profileScore` update. If any individual WriteBatch fails, `RatingRepositoryImpl` records a non-fatal Crashlytics event for that ratee, throws `RatingError.submitFailed`, and does not attempt subsequent ratee batches. The UI surfaces this error to the user with an option to retry.

---

## Consequences

### Required ADR 0001 amendments

#### Amendment A — `sessions/{sessionId}/ratings/{ratingId}` schema and rules update

This amendment supersedes the existing `sessions/{sessionId}/ratings/{raterUid}` schema entry and the corresponding Firestore rules block.

**Reason:** The existing schema uses `raterUid` as both the document ID and a field, which restricts each rater to rating exactly one ratee per session. The feature requires rating multiple ratees. The composite document ID `{raterUid}_{rateeUid}` resolves this while keeping the schema as flat documents and preserving Index 6 correctness.

**Schema table replacement** — replace the existing `sessions/{sessionId}/ratings/{raterUid}` table with:

`sessions/{sessionId}/ratings/{ratingId}`

Document ID is `{raterUid}_{rateeUid}` (underscore-concatenated), constructed by `RatingDatasource`. One document per (rater, ratee) pair per session. Immutable once created.

| Field | Type | Constraints / Notes |
|---|---|---|
| ratingId | String | Matches document ID; value is `{raterUid}_{rateeUid}` |
| raterUid | String | UID of the user submitting the rating; must equal `request.auth.uid` |
| rateeUid | String | UID of the rated member; must be a session member; must differ from `raterUid` |
| liked | bool | Always `true`; enforced in rules (`liked == true`). Absence of a document = user did not rate this ratee. |
| ratedAt | Timestamp | Set via `request.time` on creation; immutable |

**After each rating WriteBatch:** the data layer recalculates `users/{rateeUid}.profileScore` using:
1. Collection-group count on `ratings` where `rateeUid == uid` (Index 6, unchanged — field name is still `rateeUid`).
2. Count on `sessions` where `memberUids array-contains uid` and `status == 'ended'` (Index 2, unchanged).

Formula: `profileScore = thumbsUpCount / endedSessionsJoined`. If `endedSessionsJoined == 0`, write `profileScore = 0.0`.

**Firestore rules block replacement** — replace the existing `sessions/{sessionId}/ratings/{raterUid}` rule block with:

```
match /sessions/{sessionId}/ratings/{ratingId} {
  allow read: if isMember(sessionId);

  allow create: if isMember(sessionId)
    && sessionEnded(sessionId)
    && request.resource.data.raterUid == request.auth.uid
    && request.resource.data.rateeUid != request.resource.data.raterUid
    && request.resource.data.liked == true
    && request.resource.data.ratedAt == request.time
    && request.resource.data.ratingId == ratingId
    && request.resource.data.keys().hasAll([
         'ratingId', 'raterUid', 'rateeUid', 'liked', 'ratedAt'
       ])
    && request.resource.data.keys().hasOnly([
         'ratingId', 'raterUid', 'rateeUid', 'liked', 'ratedAt'
       ]);

  allow update: if false;
  allow delete: if false;
}
```

Note: The `isMember(sessionId)` check on `rateeUid` is not directly enforced by this rule (Firestore rules cannot look up a value inside a list without a `get()` call using a variable field). The `SubmitRatingsUseCase` enforces that every rateeUid in the submission is in the session's `memberUids` list before constructing any WriteBatch. The security reviewer must note this split-enforcement boundary in the audit report.

Note: Duplicate prevention (preventing two documents for the same `{raterUid}_{rateeUid}` pair) is enforced by Firestore document ID uniqueness — a second `create` for the same `ratingId` will be rejected by Firestore because the document already exists.

---

#### Amendment B — `users/{uid}` update rule: allow cross-user `profileScore` write

**Reason:** The rating WriteBatch writes `users/{rateeUid}.profileScore` where the caller is the rater (`request.auth.uid != rateeUid`). The existing `users/{uid}` update rule requires `request.auth.uid == uid`, so every `profileScore` write in the batch is rejected with `permission-denied`. Without this amendment the feature cannot commit any rating. The fix follows the same two-condition pattern used in ADR 0008 Amendment B (which allowed any session member to update `noteCount` on the session document).

Replace the `users/{uid}` `allow update` rule in ADR 0001 with a two-condition block. The first condition (self-update) is unchanged. The second condition (rating write) allows any KMUTT-authenticated user to update only `profileScore` on any user document — without requiring `request.auth.uid == uid` and without requiring `updatedAt`:

```
match /users/{uid} {
  // ... read, create, delete rules unchanged ...

  allow update: if
    (isKmuttUser()
      && request.auth.uid == uid
      && request.resource.data.diff(resource.data).affectedKeys()
           .hasOnly(['displayName', 'fullName', 'photoUrl', 'studentYear', 'academicLevel',
                     'faculty', 'bio', 'hasHostedBefore', 'profileScore', 'updatedAt'])
      && request.resource.data.updatedAt == request.time
      && request.resource.data.uid == resource.data.uid
      && request.resource.data.createdAt == resource.data.createdAt
      && request.resource.data.email == resource.data.email)
    || (isKmuttUser()
      && request.resource.data.diff(resource.data).affectedKeys()
           .hasOnly(['profileScore'])
      && request.resource.data.profileScore >= 0.0);
  // Note: the cross-user condition intentionally omits `updatedAt == request.time`.
  // The rating WriteBatch writes only profileScore on the ratee's document.
  // If a future change adds updatedAt to the rating batch, this rule must be updated
  // to include 'updatedAt' in the cross-user affectedKeys().hasOnly() list and add
  // the updatedAt == request.time assertion.
}
```

The cross-user condition permits any KMUTT-authenticated user to update `profileScore` to any non-negative value on any user document. The integrity of the value is enforced upstream: `SubmitRatingsUseCase` validates membership, `RatingDatasource` calculates the score from the two count queries, and the rating document create rule (Amendment A) enforces that the write originates from a session member after the session has ended. The security reviewer must note that the cross-user condition does not verify that the caller is actually a member of the session that produced the rating — this is accepted at MVP for the same reasons as the split-enforcement of `rateeUid` membership in Amendment A.

---

#### Amendment C — Persistent rating re-entry point for completed sessions

**Reason:** `MemberSessionDetailScreen` already auto-shows the rating popup once when navigated to via the Completed tab (`isCompleted == true`), controlled by `_ratingShownForCompleted` + `WidgetsBinding.instance.addPostFrameCallback`. After the user closes the popup with the X or Skip button, there is no way to re-open it — the screen gives no entry point to rate again later. Sub-decision 2 established `RatingBannerWidget` as the persistent fallback entry point but did not explicitly specify the interaction between the `isCompleted` auto-show path and the banner's visibility. This amendment closes that gap.

**Clarification — `isCompleted` path in `MemberSessionDetailScreen`:**

The `_ratingShownForCompleted` flag controls **auto-show behavior only**. It must never be used as a condition for hiding or showing `RatingBannerWidget`. The banner's visibility is governed solely by `ratingEnabledProvider` and `hasRatedProvider`.

Concretely:

1. **Auto-show (first open of a completed session):** When `isCompleted == true` and `_ratingShownForCompleted == false`, the rating bottom sheet is shown once via `addPostFrameCallback`. `_ratingShownForCompleted` is set to `true` immediately to prevent double-show.

2. **After close — persistent re-entry:** After the user closes the bottom sheet (tapping X or Skip), `_ratingShownForCompleted` remains `true` and the sheet will not auto-show again. However, `RatingBannerWidget` is **always rendered** at the top of the screen body (above the tab bar), independently of `_ratingShownForCompleted`. The banner stays visible until `hasRatedProvider` returns `true`. Tapping "Rate Now" on the banner re-opens `RatingBottomSheet` at any time.

3. **After submission:** Once the user submits ratings, `hasRatedProvider` returns `true` and the banner hides itself; the user is not prompted again.

The same principle applies to `HostSessionDetailScreen`: after the host dismisses the post-end-session rating popup, `RatingBannerWidget` remains visible as the persistent re-entry point.

**No new widget is needed.** `RatingBannerWidget` (Sub-decision 2) already satisfies this requirement. This amendment only clarifies that the banner must be rendered unconditionally — independent of the `_ratingShownForCompleted` auto-show flag. The implementation checklist entry for `MemberSessionDetailScreen` must reflect this coexistence explicitly.

---

### CI pipeline changes required

The following changes must be made before integration tests can pass in CI. The release engineer owns these changes.

- **Remote Config emulator seed** — the Firebase emulator job must seed `rating_enabled: false` in the Remote Config emulator before any test run. If a `remoteconfig.json` seed file was created for ADR 0008 (`note_sharing_enabled`), add `rating_enabled: false` to the same file.
- **Integration test placement** — `rating_submit_test.dart` and `profile_score_test.dart` must run in the existing Firebase emulator CI job against both the Android emulator and the Web (Chrome) target.
- **Merge gate** — the release engineer must confirm `rating_enabled` is set to `false` in production Firebase Remote Config before the PR is merged.

---

### New packages — add to `apps/mobile/pubspec.yaml`

No new packages are required. `firebase_remote_config` is already declared per ADR 0008.

---

### Firestore path constants — add to `lib/core/firestore_paths.dart`

```dart
static String ratings(String sessionId) =>
    'sessions/$sessionId/ratings';

static String rating(String sessionId, String raterUid, String rateeUid) =>
    'sessions/$sessionId/ratings/${raterUid}_$rateeUid';
```

---

### Domain errors — `lib/core/errors/rating_error.dart`

Sealed class with variants:

- `RatingError.selfRatingNotAllowed` — caller attempted to include their own UID in the ratee list
- `RatingError.sessionNotEnded` — session `status` is not `'ended'` at the time of submission
- `RatingError.alreadyRated(String rateeUid)` — a rating document for this (rater, ratee) pair already exists; `rateeUid` must not be logged as PII — use a truncated hash if needed, or omit the field
- `RatingError.submitFailed(String message)` — WriteBatch write failed; `message` must contain no PII
- `RatingError.offlineNotSupported` — Firestore returned unavailable; rating cannot proceed offline
- `RatingError.rateeNotMember(String rateeUid)` — rateeUid is not in `session.memberUids`; use same PII caution as `alreadyRated`

---

### Domain entity — `lib/features/rating/domain/entities/rating_entity.dart`

Freezed; fields:

| Field | Type | Notes |
|---|---|---|
| `ratingId` | String | Firestore document ID; value is `{raterUid}_{rateeUid}` |
| `raterUid` | String | UID of the rater |
| `rateeUid` | String | UID of the ratee |
| `liked` | bool | Always `true` in the current data model |
| `ratedAt` | DateTime | Converted from Firestore Timestamp in the model layer |

Value object for submission parameters — `lib/features/rating/domain/entities/rating_submission.dart` — Freezed; fields: `sessionId` (String), `rateeUids` (List\<String\>) — the list of member UIDs the rater wants to thumbs-up in this submission.

---

### Domain repository interface — `lib/features/rating/domain/repositories/rating_repository.dart`

```dart
abstract class RatingRepository {
  Future<void> submitRatings(String sessionId, List<String> rateeUids);
  Stream<List<RatingEntity>> watchSessionRatings(String sessionId);
  Future<bool> hasRatedInSession(String sessionId, String raterUid);
}
```

`submitRatings` creates one WriteBatch per rateeUid and updates each ratee's `profileScore`. `watchSessionRatings` streams all rating documents in the session's ratings subcollection ordered by `ratedAt` desc (used to determine which members have already been rated). `hasRatedInSession` checks whether any rating document with the given `raterUid` exists in the session; used by `RatingBannerWidget` and by `ratingEnabledProvider` to hide the banner once the user has submitted.

---

### Domain use cases

- `lib/features/rating/domain/usecases/submit_ratings_usecase.dart`
  — `Future<void> call(RatingSubmission submission)` — validates that `submission.rateeUids` is non-empty; validates that `submission.rateeUids` does not contain the current user's UID (throws `RatingError.selfRatingNotAllowed`); validates that each rateeUid is in the session's `memberUids` (throws `RatingError.rateeNotMember`); delegates to `RatingRepository.submitRatings`. The use case does not call Firestore directly; it reads `memberUids` from the `SessionEntity` passed through the provider layer, not from a direct Firestore read.

- `lib/features/rating/domain/usecases/watch_session_ratings_usecase.dart`
  — `Stream<List<RatingEntity>> call(String sessionId)` — delegates to `RatingRepository.watchSessionRatings`.

- `lib/features/rating/domain/usecases/check_has_rated_usecase.dart`
  — `Future<bool> call(String sessionId, String raterUid)` — delegates to `RatingRepository.hasRatedInSession`.

---

### Data layer files

- `lib/features/rating/data/models/rating_model.dart` — Freezed + json_serializable; maps the Firestore `ratings` document to `RatingEntity`; converts `ratedAt` Timestamp to `DateTime`.

- `lib/features/rating/data/datasources/rating_datasource.dart`
  — Path constants from `lib/core/firestore_paths.dart` only.
  — `Future<void> writeRatingBatch(String sessionId, String rateeUid, double newProfileScore)` — constructs a `WriteBatch`: (a) sets the rating document at `FirestorePaths.rating(sessionId, currentUid, rateeUid)` with fields `{ratingId, raterUid, rateeUid, liked: true, ratedAt: FieldValue.serverTimestamp()}`; (b) updates `users/{rateeUid}.profileScore` to `newProfileScore`. Commits the batch. Logs progress at `info` level. Records non-fatal Crashlytics event on `FirebaseException`.
  — `Future<int> countThumbsUpReceived(String rateeUid)` — executes a collection-group `count()` query on `ratings` (Index 6) filtered by `rateeUid == rateeUid`; returns the integer count.
  — `Future<int> countEndedSessionsJoined(String uid)` — executes a `count()` query on `sessions` filtered by `memberUids array-contains uid` and `status == 'ended'` (Index 2); returns the integer count.
  — `Stream<List<RatingModel>> watchSessionRatings(String sessionId)` — `collection(FirestorePaths.ratings(sessionId)).orderBy('ratedAt', descending: true).snapshots()`.
  — `Future<bool> hasRatedInSession(String sessionId, String raterUid)` — queries `collection(FirestorePaths.ratings(sessionId)).where('raterUid', isEqualTo: raterUid).limit(1).get()`; returns `docs.isNotEmpty`.

- `lib/features/rating/data/repositories/rating_repository_impl.dart`
  — Implements `RatingRepository`.
  — `submitRatings`: for each `rateeUid` in the list — (1) calls `RatingDatasource.countThumbsUpReceived(rateeUid)` and `RatingDatasource.countEndedSessionsJoined(rateeUid)` to get current counts; (2) calculates `newScore = (thumbsUp + 1) / max(1, endedSessions)` (the +1 accounts for the rating being written in the same batch); (3) calls `RatingDatasource.writeRatingBatch(sessionId, rateeUid, newScore)`; maps `FirebaseException` with code `permission-denied` to `RatingError.submitFailed`; maps `FirebaseException` with code `unavailable` to `RatingError.offlineNotSupported`; wraps other exceptions in `RatingError.submitFailed`.
  — `watchSessionRatings`: delegates to `RatingDatasource.watchSessionRatings`; maps `RatingModel` list to `RatingEntity` list.
  — `hasRatedInSession`: delegates to `RatingDatasource.hasRatedInSession`.

---

### Presentation providers

- `lib/features/rating/presentation/providers/rating_provider.dart`
  — `@riverpod` async notifier `RatingNotifier(String sessionId)` holding `AsyncValue<void>` state.
  — Exposes `Future<void> submitRatings(List<String> rateeUids, List<String> sessionMemberUids)` — checks `rating_enabled` Remote Config flag; calls `SubmitRatingsUseCase` with a `RatingSubmission(sessionId: sessionId, rateeUids: rateeUids)`; on success fires `rating_submitted` analytics event; on any `RatingError` sets state to `AsyncError` with the error for the UI to surface.

- `lib/features/rating/presentation/providers/session_ratings_provider.dart`
  — `@riverpod Stream<List<RatingEntity>> sessionRatings(ref, String sessionId)` — auto-dispose; watches `RatingRepository.watchSessionRatings(sessionId)`.

- `lib/features/rating/presentation/providers/has_rated_provider.dart`
  — `@riverpod Future<bool> hasRated(ref, String sessionId, String raterUid)` — auto-dispose; calls `CheckHasRatedUseCase(sessionId, raterUid)`.

- `lib/features/rating/presentation/providers/rating_flag_provider.dart`
  — `@riverpod bool ratingEnabled(ref)` — synchronous; reads `FirebaseRemoteConfig.instance.getBool('rating_enabled')`; defaults to `false` before the first successful fetch. Remote Config must be fetched and activated during app startup via the existing `remoteConfigStartup` provider in `lib/core/remote_config_startup.dart`.

---

### Presentation screens and widgets

**`RatingBottomSheet` widget — `lib/features/rating/presentation/widgets/rating_bottom_sheet.dart`**

Shown to the host immediately after the end-session confirmation succeeds (called from `HostSessionDetailScreen`), and shown to all users when they tap the `RatingBannerWidget`.

- Reads `ratingEnabledProvider`; if `false`, pops and shows a `SnackBar` ("Rating is not available yet").
- Reads `hasRatedProvider(sessionId, currentUserId)`. If the result is `true` (already rated), pops and shows a `SnackBar` ("You have already rated the members of this session").
- Renders the list of ratable members: all `session.memberUids` excluding the current user. Uses `ListView.builder` with `itemCount`.
- Each member row: `CachedNetworkImage` avatar (from `users/{uid}.photoUrl`); display name; a `ToggleButton` (thumbs-up icon) initialized to un-toggled. The row is wrapped in `Semantics(label: 'Rate ${member.displayName}', button: true)`.
- "Submit" `FilledButton` and "Skip" `TextButton` at the bottom. "Submit" is enabled only when at least one member is toggled. Both wrapped in `Semantics`.
- While `ratingNotifier` state is `AsyncLoading`, "Submit" is disabled and a `CircularProgressIndicator` overlays the button.
- On `AsyncError` state: renders an inline error banner below the member list showing the user-facing error message (mapped from `RatingError` variants); the banner does not contain PII.
- Minimum touch target for toggle buttons and action buttons: 44 × 44 dp.
- Color contrast for member name and subtitle text ≥ 4.5:1 (WCAG AA).
- All toggle buttons and action buttons carry `Semantics` labels readable by TalkBack and ChromeVox.

**`RatingBannerWidget` — `lib/features/rating/presentation/widgets/rating_banner_widget.dart`**

A stateless widget rendered at the top of the session detail screen scaffold body when `status == 'ended'`.

- Reads `ratingEnabledProvider`. If `false`, renders nothing (`SizedBox.shrink()`).
- Reads `hasRatedProvider(sessionId, currentUserId)`. If `true`, renders nothing.
- If both conditions are unmet (rating is enabled and user has not yet rated): renders a `Card` with a thumbs-up icon, a "Rate your session members" label, and a "Rate Now" `TextButton`. Tapping "Rate Now" calls `showModalBottomSheet(context, builder: (_) => RatingBottomSheet(...))`.
- Wrapped in `Semantics(label: 'Rate your session members banner', liveRegion: true)`.
- Color contrast for banner text ≥ 4.5:1.

**Detail screen amendments (ADR 0003)**

- `HostSessionDetailScreen` — in `onEndSessionConfirmed` (the callback invoked after the end-session `WriteBatch` succeeds): if `ratingEnabledProvider` is `true` and `hasRatedProvider` is `false`, call `showModalBottomSheet` with `RatingBottomSheet`. Insert `RatingBannerWidget(sessionId: sessionId, currentUserId: currentUserId)` at the top of the screen body, above the `TabBar`. After the host dismisses the post-end-session popup, the banner remains visible as the persistent re-entry point (see Amendment C).

- `MemberSessionDetailScreen` — insert `RatingBannerWidget(sessionId: sessionId, currentUserId: currentUserId)` at the top of the screen body, above the `TabBar`. The banner is rendered unconditionally (subject only to `ratingEnabledProvider` and `hasRatedProvider`). **The existing `isCompleted` auto-show behavior is preserved alongside the banner:** when `isCompleted == true`, the rating bottom sheet auto-shows once on first open via `addPostFrameCallback` + `_ratingShownForCompleted` flag; after the user closes the popup, the banner remains visible and serves as the persistent re-entry point until the user submits ratings (see Amendment C). The existing private `_RatingBottomSheet` widget in this file must be replaced by the new standalone `RatingBottomSheet` widget; `_RatingBottomSheet` must be converted to a `ConsumerStatefulWidget` (currently it is a plain `StatefulWidget`) or deleted entirely in favour of the standalone widget.

**`ProfileScoreWidget` — `lib/features/rating/presentation/widgets/profile_score_widget.dart`**

A reusable widget for the profile screen that displays `users/{uid}.profileScore`.

- Renders a thumbs-up icon and a percentage label: e.g. "85%" (formatted as `(profileScore * 100).toStringAsFixed(0)`).
- When `profileScore == 0.0` and the user has not yet joined any ended session, renders "No ratings yet" with `Semantics(label: 'No ratings yet')`.
- When `profileScore > 0`, renders a filled thumbs-up icon and the percentage, e.g. "85% positive" with `Semantics(label: '85 percent positive rating')`.
- Color contrast ≥ 4.5:1.

---

### Analytics events — declare in `lib/core/analytics_events.dart` before use

- `rating_submitted` — payload: `ratee_count` (int — number of members rated in this submission)
- `rating_skipped` — no payload (user tapped "Skip" in the rating bottom sheet)
- `rating_banner_tapped` — no payload
- `rating_submit_failed` — payload: `error_type` (String, no PII — e.g. `'submit_failed'`, `'offline'`, `'already_rated'`)

---

### Logging and observability

All log calls use `lib/core/logger.dart` only; never `print()`. No PII in any log message or Crashlytics key.

| Call site | Level | Message (no PII) |
|---|---|---|
| `SubmitRatingsUseCase` — self-rating guard triggered | `warning` | `'rating_submit: self-rating attempt blocked sessionId=$sessionId'` |
| `SubmitRatingsUseCase` — ratee not member | `warning` | `'rating_submit: rateeUid not in memberUids sessionId=$sessionId'` |
| `RatingDatasource.writeRatingBatch()` — batch started | `debug` | `'rating_batch: starting batch sessionId=$sessionId rateeCount=1'` |
| `RatingDatasource.writeRatingBatch()` — batch committed | `info` | `'rating_batch: committed sessionId=$sessionId'` |
| `RatingDatasource.writeRatingBatch()` — FirebaseException | `error` | `'rating_batch: FirebaseException code=$code sessionId=$sessionId'` |
| `RatingRepositoryImpl.submitRatings()` — offline error | `warning` | `'rating_submit: offline; cannot submit sessionId=$sessionId'` |
| `RatingRepositoryImpl.submitRatings()` — partial batch failure | `error` | `'rating_submit: batch failed for ratee index=$index sessionId=$sessionId'` |

Non-fatal Crashlytics events (`FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: false)`) must be recorded at:

- `RatingDatasource.writeRatingBatch()` on `FirebaseException`
- `RatingRepositoryImpl.submitRatings()` on any unhandled exception after at least one successful batch

---

### Test matrix (qa-engineer owns; must be complete before Flutter Engineer begins presentation layer)

| Test type | File | What to verify |
|---|---|---|
| Unit | `test/features/rating/domain/submit_ratings_usecase_test.dart` | Throws `RatingError.selfRatingNotAllowed` when current user UID is in rateeUids; throws `RatingError.rateeNotMember` when a rateeUid is not in memberUids; delegates to repository when valid; delegates with empty list throws (precondition: list must be non-empty) |
| Unit | `test/features/rating/domain/check_has_rated_usecase_test.dart` | Returns `true` when repository returns `true`; returns `false` when repository returns `false` |
| Unit | `test/features/rating/data/rating_datasource_test.dart` | `writeRatingBatch` constructs WriteBatch with correct document path using composite ID; `countThumbsUpReceived` uses collection-group query with `rateeUid` filter; `countEndedSessionsJoined` uses `memberUids array-contains` + `status == 'ended'` filter; `hasRatedInSession` returns `false` when no matching document |
| Unit | `test/features/rating/data/rating_repository_impl_test.dart` | `submitRatings` calls `writeRatingBatch` once per rateeUid; `permission-denied` FirebaseException maps to `RatingError.submitFailed`; `unavailable` FirebaseException maps to `RatingError.offlineNotSupported`; `profileScore` written as `0.0` when `endedSessionsJoined == 0` |
| Unit | `test/features/rating/data/profile_score_formula_test.dart` | Formula `(thumbsUp + 1) / endedSessions`; edge case `endedSessions == 0` returns `0.0`; edge case `thumbsUp == 0` and `endedSessions == 1` returns `0.0` (no new thumbs-up) — note: `+1` in formula is applied only for the current write, so use correct formula per `RatingRepositoryImpl` |
| Widget | `test/features/rating/presentation/rating_bottom_sheet_test.dart` | Renders "Rating is not available yet" SnackBar when `ratingEnabled` is `false`; renders "Already rated" SnackBar when `hasRated` is `true`; renders member list excluding current user; "Submit" disabled when no member toggled; "Submit" enabled when at least one member toggled; tapping "Skip" fires `rating_skipped` analytics event; `AsyncLoading` state disables "Submit" and shows progress indicator; `AsyncError` state renders inline error banner |
| Widget | `test/features/rating/presentation/rating_banner_widget_test.dart` | Renders nothing when `ratingEnabled` is `false`; renders nothing when `hasRated` is `true`; renders banner card when `ratingEnabled` is `true` and `hasRated` is `false`; tapping "Rate Now" fires `rating_banner_tapped` and opens bottom sheet |
| Widget | `test/features/rating/presentation/profile_score_widget_test.dart` | Renders "No ratings yet" when score is `0.0`; renders percentage string for score `> 0`; `Semantics` label matches expected string |
| Golden | `test/features/rating/presentation/goldens/rating_bottom_sheet_unselected.png` | Bottom sheet with all members unselected and "Submit" disabled |
| Golden | `test/features/rating/presentation/goldens/rating_bottom_sheet_selected.png` | Bottom sheet with one member selected and "Submit" enabled |
| Golden | `test/features/rating/presentation/goldens/rating_banner.png` | Banner card in session detail screen context |
| Golden | `test/features/rating/presentation/goldens/profile_score_positive.png` | `ProfileScoreWidget` showing e.g. "85% positive" |
| Golden | `test/features/rating/presentation/goldens/profile_score_zero.png` | `ProfileScoreWidget` showing "No ratings yet" |
| Integration | `test/integration/rating_submit_test.dart` | Android + Web: host ends session; rating bottom sheet appears; host rates two members; verify two rating documents created in Firestore with composite IDs; verify `profileScore` updated on both ratee user documents; verify `hasRated` returns `true` after submission |
| Integration | `test/integration/rating_self_block_test.dart` | Android + Web: current user's UID does not appear in the member list in the bottom sheet; attempting a direct WriteBatch with `raterUid == rateeUid` is rejected by Firestore rules |
| Integration | `test/integration/rating_duplicate_block_test.dart` | Android + Web: submitting ratings for a session where the user has already rated returns `RatingError.alreadyRated` for the duplicate ratee; the second WriteBatch for a different unrated ratee succeeds (partial re-submission scenario) |

Accessibility sweep (qa-engineer): run `flutter test --tags a11y` on `RatingBottomSheet` and `RatingBannerWidget`; verify every member toggle button, the "Submit" and "Skip" buttons, and the "Rate Now" button carry `Semantics` labels readable by TalkBack (Android) and ChromeVox (Web). Verify all text contrast ratios ≥ 4.5:1.

Performance check (qa-engineer): confirm that rendering a member list of up to 20 members in `RatingBottomSheet`'s `ListView.builder` produces no dropped frames on a mid-range Android device using Flutter's performance overlay. Verify that the sequential WriteBatch loop for N ratees completes within 5 seconds for N ≤ 10 on a standard emulator network.

---

### Implementation checklist for Flutter Engineer

- [ ] Amend `firestore.rules` — replace `sessions/{sessionId}/ratings/{raterUid}` block with the new `sessions/{sessionId}/ratings/{ratingId}` block per Amendment A above
- [ ] Amend `firestore.rules` — replace the `users/{uid}` `allow update` rule with the two-condition block per Amendment B above; deploy before any rating write reaches production
- [ ] Add `ratings(sessionId)` and `rating(sessionId, raterUid, rateeUid)` constants to `lib/core/firestore_paths.dart`
- [ ] Create `lib/core/errors/rating_error.dart` — sealed class with six variants
- [ ] Declare all four analytics events in `lib/core/analytics_events.dart`
- [ ] Create `RatingEntity` Freezed entity
- [ ] Create `RatingSubmission` value object (Freezed, domain layer)
- [ ] Create `RatingRepository` abstract interface
- [ ] Create three use cases: `SubmitRatingsUseCase`, `WatchSessionRatingsUseCase`, `CheckHasRatedUseCase`
- [ ] Create `RatingModel` (Freezed + json_serializable)
- [ ] Create `RatingDatasource` with `writeRatingBatch`, `countThumbsUpReceived`, `countEndedSessionsJoined`, `watchSessionRatings`, `hasRatedInSession`; add `logger.dart` calls at all specified call sites; add non-fatal Crashlytics records at all specified call sites
- [ ] Create `RatingRepositoryImpl`; implements sequential WriteBatch per ratee with score recalculation; handles `permission-denied` and `unavailable` error mapping
- [ ] Create `RatingNotifier`, `sessionRatingsProvider`, `hasRatedProvider`, `ratingEnabledProvider` Riverpod providers
- [ ] Add `rating_enabled: false` to `remoteconfig.json` emulator seed (alongside `note_sharing_enabled`)
- [ ] Create `RatingBottomSheet` widget; gate on `ratingEnabledProvider` and `hasRatedProvider`; wrap all interactive elements in `Semantics`; minimum 44 × 44 dp touch targets; verify contrast ≥ 4.5:1
- [ ] Create `RatingBannerWidget`; gate on `ratingEnabledProvider` and `hasRatedProvider`; wrap in `Semantics` with `liveRegion: true`
- [ ] Create `ProfileScoreWidget`; two display states (zero and positive); correct `Semantics` labels
- [ ] Amend `HostSessionDetailScreen` — call `showModalBottomSheet` with `RatingBottomSheet` in `onEndSessionConfirmed`; insert `RatingBannerWidget` at top of screen body; banner persists after popup is dismissed
- [ ] Amend `MemberSessionDetailScreen` — insert `RatingBannerWidget` at top of screen body rendered independently of `_ratingShownForCompleted`; preserve `isCompleted` auto-show behavior (popup + banner coexist on the completed-session path per Amendment C); replace private `_RatingBottomSheet` with the new standalone `RatingBottomSheet` widget
- [ ] Integrate `ProfileScoreWidget` into the profile screen (whichever screen displays `users/{uid}.profileScore`)
- [ ] Verify domain layer has zero Flutter and Firebase imports (`dart run build_runner build` must pass with no import lint errors)
- [ ] Add `rating_enabled` flag to Firebase Remote Config in the console before first QA deployment (set to `false` initially)
- [ ] Amend ADR 0001 inline (Amendments A and B) before implementation begins; ADR 0001 is the authoritative schema and rules document

---

### Agent hand-off

- **QA engineer** must produce the full test matrix above and complete the accessibility sweep and performance check before the Flutter Engineer begins the presentation layer.
- **Security reviewer** must audit `RatingDatasource` (composite ID construction, WriteBatch atomicity, self-rating enforcement boundary), `RatingRepositoryImpl` (permission-denied and unavailable mapping, partial batch failure handling), and the amended Firestore rules (`ratingId` wildcard, field-level self-rating check, `keys().hasOnly` enforcement, cross-user `profileScore` write condition in Amendment B) before the PR is merged. The reviewer must explicitly note the split-enforcement of `rateeUid` membership and the open cross-user `profileScore` write in the audit report.
- **Release engineer** must confirm `rating_enabled` Remote Config flag is set to `false` in production until integration tests pass on both Android and Web.
- **Architect** must amend ADR 0001 inline (Amendments A and B) before the Flutter Engineer begins; ADR 0001 is the authoritative schema and rules document.

**Parallel work windows:** The following tasks may run concurrently:

- While the Flutter Engineer builds the domain layer (entities, repository interface, use cases) and data layer (datasource, repository implementation), the QA engineer may concurrently author the full test matrix stubs and the security reviewer may concurrently draft the audit checklist against `RatingDatasource`, `RatingRepositoryImpl`, and the amended Firestore rules.
- The release engineer CI pipeline changes (Remote Config seed update) may begin as soon as Amendment A rules are finalized — they do not depend on the Flutter presentation layer being complete.
- ADR 0001 inline amendments (A and B) may be written by the architect concurrently with the Flutter Engineer beginning the domain layer, since the domain layer does not depend on Firestore rules being deployed. Amendment B must be deployed to the Firestore rules emulator before integration tests run.

---

## Reversal plan

**Sub-decision 1 (composite document ID):** If the document ID strategy must change (e.g., back to `raterUid` with a `rateeUids` list once Firestore rules gain list-iteration support), update `FirestorePaths.rating`, update `RatingDatasource` to write to the new path, update the Firestore rules block, and migrate existing rating documents via a one-off script. The domain entity, repository interface, and all use cases are unaffected by the ID format because it is an internal data-layer detail. An ADR amendment is required before the migration begins.

**Sub-decision 2 (rating flow UX):** If the combined banner + host-popup approach creates UX confusion (e.g., the host sees both the popup and the banner), add a flag to suppress the banner for the session immediately after the popup is shown. If a separate route becomes necessary (e.g., for push-notification deep-linking into the rating flow), add a new route constant `/sessions/:id/rate` to `RouteConstants`, create `RatingScreen` wrapping `RatingBottomSheet` content, and wire it in `app_router.dart`. Amend ADR 0003 to record the new route. The domain, data, and provider layers are unaffected.

**Sub-decision 3 (denormalized profileScore):** If the WriteBatch pre-calculation strategy proves incorrect under concurrent rating submissions (race condition on the count values), replace the client-side count reads with a Cloud Function that recalculates `profileScore` server-side after each rating document write. The `RatingRepository` interface and all use cases are unaffected. A new ADR covering the Cloud Function's responsibilities is required.

**Sub-decision 4 (Remote Config flag):** If Remote Config is replaced or the flag must be per-user, change only `ratingEnabledProvider` to read from the new source. All consumers of the provider are unaffected.

**Sub-decision 5 (sequential WriteBatch per ratee):** If the sequential WriteBatch loop introduces unacceptable latency for sessions with many members, replace with parallel `Future.wait` over the batch list. The `RatingRepository` interface is unchanged; only `RatingRepositoryImpl.submitRatings` is modified. If partial failure handling becomes complex under parallelism, fall back to a Cloud Function approach (see sub-decision 3 reversal).
