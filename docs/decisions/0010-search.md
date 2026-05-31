# 0010 — Search Feature UX/UI Enhancements

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-05-30 |
| Architect session | claude-sonnet-4-6 / NichapaJongKmutt / 2026-05-30 |
| Affects | Search feature (domain, data, presentation), home/presentation/screens/home_screen.dart, core/analytics_events.dart, core/firestore_paths.dart, core/feature_flags.dart, app_router.dart, RouteConstants |

---

## Team approval

Approved by: NichapaJongKmutt
Date: 2026-05-30
Notes: Accepted via Claude Code session. Q1: amend SearchFilter to add Set<String>? subjects (domain change approved). Q2: Friends chip UI-only, no backend. Q4: delete filter_panel.dart and search_suggestions.dart.

---

## Problem

The home screen currently renders a non-functional search bar placeholder that shows a "Search coming soon" snackbar on tap (`home_screen.dart` line 61–63). No search feature folder exists under `lib/features/search/`. The CLAUDE.md specification requires search by session name, hashtag, academic level, and student year against the existing Firestore schema defined in ADR 0001 (Index 3: `hashtags array-contains, academicLevel asc, studentYear asc`; Index 8: `hostFaculty asc, status asc, scheduledAt asc`). Before a Flutter Engineer writes a single file, the team needs authoritative answers to four questions. First, how should the search screen be integrated — as a dedicated GoRouter route or as a modal overlay on the home screen — given that state must survive back navigation? Second, how should multiple simultaneous filters be composed given that Firestore does not support server-side OR queries across different fields, and that Index 3 covers the hashtag + level + year combination while no single index covers all four filter dimensions simultaneously? Third, where should recent searches be persisted — locally via `flutter_secure_storage` or in Firestore on the user document — given the online-only constraint and the no-PII-in-logs rule? Fourth, which of the ten Nielsen heuristics require structural decisions (routing, state shape, debounce contract, local storage schema) versus which are purely presentational and can be deferred to the Flutter Engineer? Without this record, engineers will create incompatible state models, violate the domain isolation rule, add unbounded queries without index justification, and produce a search UX inconsistent with the rest of the app.

---

## Constraints

- Domain layer has zero Flutter or Firebase imports. All Firestore path strings are constants in `lib/core/firestore_paths.dart` only.
- Repository interfaces in `domain/repositories/`; implementations in `data/repositories/`. No Firestore types cross the domain boundary.
- Entities use Freezed; use cases are plain Dart classes. All Riverpod providers use `@riverpod` codegen; no hand-written `StateNotifier`.
- Business logic (filter composition, debounce trigger, whitespace trimming, lowercase normalisation, result count) must not be defined in the presentation layer; it belongs in use cases or the repository implementation.
- No new Firestore composite indexes. All queries must be expressible using the ten indexes already declared in ADR 0001. Index 3 (`hashtags array-contains, academicLevel asc, studentYear asc`) and Index 8 (`hostFaculty asc, status asc, scheduledAt asc`) are the only indexes relevant to search.
- Search is online-only; no offline queue and no offline cache of results. The use case must throw `SearchError.offlineNotSupported` when Firestore returns an unavailable error.
- KMUTT email gate (`@mail.kmutt.ac.th` / `@kmutt.ac.th`) is enforced in Firestore rules by `isKmuttUser()` (ADR 0001); the `sessions` read rule already restricts all reads to verified KMUTT users.
- Firestore read rule for `sessions`: `visibility == 'public' || request.auth.uid in resource.data.memberUids` (ADR 0001). The search datasource must only query public sessions, or scope results to sessions the current user may read, to avoid permission-denied errors on the client.
- No unbounded `ListView`; always `ListView.builder` with `itemCount` or paginated.
- All remote images (host avatars on session cards) through `cached_network_image`; never `Image.network` directly.
- Recent searches stored locally only — never in Firestore. No PII in any log output or analytics event.
- All analytics events declared in `lib/core/analytics_events.dart` before use.
- All log calls go through `lib/core/logger.dart` only; never `print()`.
- No new packages unless absolutely necessary. `flutter_secure_storage` is already declared in `pubspec.yaml`. No additional search or debounce packages may be added.
- All search enhancements are gated behind `FeatureFlags.searchEnhancementsEnabled` in `lib/core/feature_flags.dart`. The compile-time constant pattern already established by that file must be followed; no new flag mechanism is introduced.
- Hashtags are stored as `List<String>` on session documents, lowercase, free-text (ADR 0001 schema). Client-side input must be lowercased and trimmed before any Firestore query.
- `SessionEntity` is the shared entity from `lib/features/sessions/domain/entities/session_entity.dart` (ADR 0003). It must not be duplicated in the search feature; the search domain layer imports it from the sessions domain.

---

## Options considered

### Sub-decision 1 — Search route: dedicated GoRouter route vs. in-place modal overlay on the home screen

| | Option A — Dedicated `/search` GoRouter route (`SearchScreen`) | Option B — Modal overlay expanded in-place on the home screen | Option C — Full-screen dialog pushed via `Navigator.push` |
|---|---|---|---|
| Summary | A new route `/search` is registered in `app_router.dart`; tapping the home screen placeholder navigates to `SearchScreen` via `context.push('/search')`; back navigation restores the previous home screen state | Tapping the search bar expands it into a full-content overlay within the home screen scaffold; no route change; state lives in a local `StatefulWidget` or a scoped provider | A `MaterialPageRoute` with `fullscreenDialog: true` is pushed; no GoRouter route is added; state is local to the dialog widget |
| Back-navigation state preservation | Natural: GoRouter preserves the home screen's scroll and session list when the user pops `/search`; search state survives if the search provider is kept alive | Depends on the home screen provider scope; back-navigation is a widget toggle, not a route pop; deep-linking not possible | State is discarded when the dialog is popped; no deep-link entry point |
| Deep-linkable | Yes — `/search` can be navigated to from any part of the app or from a push notification | No | No |
| Alignment with existing app router pattern | Consistent: `app_router.dart` already hosts all feature routes; every feature in the app uses GoRouter screens | Inconsistent: home screen becomes responsible for rendering two distinct UI surfaces | Inconsistent: bypasses GoRouter entirely; contradicts ADR 0002 routing decisions |
| Filter state survival across back | Provider auto-dispose controls this; `keepAlive` annotation preserves filter state across pops if needed | State is in-widget; survives as long as the home screen widget is alive | State is discarded on pop |
| Implementation effort | Low — new `GoRoute` entry + new screen widget; filter state in a Riverpod provider scoped to the route | Low — modify `HomeScreen` to toggle an overlay; no router change | Low — `Navigator.push` call; no router change |
| Reversal cost | Low — remove the route from `app_router.dart` and delete `SearchScreen`; home screen placeholder reverts to SnackBar | Low — remove the overlay toggle from `HomeScreen` | Low — remove the `Navigator.push` call |
| Recommendation | Yes | No | No |

Option A is recommended. A dedicated GoRouter route is consistent with every other feature in this codebase and with ADR 0002's routing decisions. It enables deep-linking, isolates search state in its own provider scope, and preserves home-screen state naturally through GoRouter's shell branch stack. Options B and C are rejected because they place routing responsibility in the wrong layer and cannot be deep-linked.

---

### Sub-decision 2 — Filter composition: server-side Firestore query vs. client-side post-filter vs. hybrid

Firestore does not support server-side OR across different field combinations. Index 3 covers `hashtags array-contains + academicLevel + studentYear`; Index 8 covers `hostFaculty + status + scheduledAt`. No single index covers all four user-facing filter dimensions simultaneously. The user may activate any combination of: keyword (session title), hashtag, academic level, student year. The question is which filters to push to Firestore and which to apply client-side after fetching.

| | Option A — Server-side Index 3 query (hashtag + level + year) with client-side keyword and additional field filter | Option B — Fetch all public sessions (bounded window), filter entirely client-side | Option C — Two parallel server queries (Index 3 and Index 8) merged client-side |
|---|---|---|---|
| Summary | When any of hashtag, academicLevel, or studentYear is active, fire an Index 3 query with those fields; if only a keyword is active, query `sessions` ordered by `scheduledAt asc` without the array-contains constraint; all results are then post-filtered client-side for keyword (title `contains`), and any remaining active filters not supported by the live index combination | Fetch all public `sessions` with `status == 'scheduled'` and `scheduledAt >= now` (bounded to the next 30 days) into memory; apply all filters client-side; re-fetch on pull-to-refresh only | Execute two Firestore queries in parallel (Index 3 and Index 8); merge result sets client-side; deduplicate by `sessionId`; apply keyword filter client-side |
| Firestore read cost | One query per search submission; reads only documents matching the server-side predicate; result set is smaller when index fields are active | One bounded query; reads all scheduled public sessions regardless of active filters; cost is proportional to the total count of active sessions, not the filtered set | Two concurrent queries; combined read cost is higher; deduplication is required |
| Index usage | Uses Index 3 when hashtag is active; falls back to a collection scan ordered by `scheduledAt` when only keyword is active — acceptable given online-only constraint and bounded result set (public sessions with `status == 'scheduled'`) | Uses no special index beyond the status + scheduledAt ordering; one query | Uses Index 3 and Index 8 simultaneously; marginally more complex deduplication logic in the data layer |
| Client-side logic complexity | Low: one filtering pass over the server result set; keyword filter is a `String.contains` on `title.toLowerCase()`; hashtag filter is an `Iterable.any` on the `hashtags` list (already lowercase) | Medium: all filters in one client-side pass; but result set may be large for active deployments | High: merge + deduplicate + multi-filter pass; two async results must be combined before the provider emits |
| Correctness with AND logic | Correct: all active filters are applied (server handles hashtag/level/year; client handles title keyword and any remaining filter) | Correct: all active filters are applied client-side in a single pass | Correct but complex: union of two queries may over-fetch; AND logic requires intersection of two sets, not union — Option C is architecturally wrong for AND semantics and would require intersection logic, not merge |
| Reversal cost | Low — change the datasource query method | Low — change the datasource query method | High — the parallel-query pattern would need to be unwound if index changes are made |
| Recommendation | Yes | No — acceptable at MVP scale but degrades as sessions grow | No — the merge-then-intersect pattern is architecturally incorrect for AND semantics |

Option A is recommended. Pushing the hashtag + academicLevel + studentYear combination to Firestore via Index 3 minimises reads; applying the keyword (title) filter client-side after fetching avoids the need for a full-text index. Firestore does not support substring queries on String fields natively, so client-side keyword filtering is architecturally mandatory regardless. Option B is rejected because the result set grows unbounded with active sessions. Option C is rejected because merging two queries and then applying AND intersection is more complex and more expensive than a single query with client-side post-filtering.

---

### Sub-decision 3 — Recent searches persistence: flutter_secure_storage (local) vs. Firestore user document field

| | Option A — `flutter_secure_storage` (local device only) | Option B — Firestore `users/{uid}` document field `recentSearches: List<String>` |
|---|---|---|
| Summary | Recent searches serialised as a JSON array and stored under a single secure-storage key per user (keyed by UID to prevent cross-user leakage on shared devices); max 10 entries; FIFO eviction | Recent searches stored as a new field on `users/{uid}`; synced across devices; always up to date on re-install |
| Cross-device sync | No — searches are device-local | Yes — any device shows the same recent list |
| Firestore writes | Zero | One write per new search term; subject to ADR 0001 `users/{uid}` update rule (`affectedKeys` must include `recentSearches`; requires an ADR 0001 amendment) |
| PII risk | Contained to the device; secure storage is encrypted; no PII leaves the device via this path | Search terms may contain display names or other PII; stored in Firestore and visible in any admin console or rules audit |
| ADR 0001 alignment | No schema change required | Requires ADR 0001 amendment to add `recentSearches` field to `users/{uid}` schema and update rules |
| Offline availability | Available offline (secure storage reads are synchronous) | Unavailable when Firestore is offline; inconsistent with the search-is-online-only constraint |
| Package requirement | `flutter_secure_storage` already in `pubspec.yaml` | No new package, but requires Firestore write and rules amendment |
| Reversal cost | Low — delete the secure storage key and remove the local storage service | Medium — remove the field from `users/{uid}`, amend ADR 0001 again, migrate existing documents |
| Recommendation | Yes | No |

Option A is recommended. `flutter_secure_storage` is already declared in `pubspec.yaml` and requires zero schema or rules changes. Search terms may contain personal references (peer names, topics) that should not transit Firestore or appear in admin logs. Cross-device sync of recent searches is a convenience feature that does not justify the PII risk, the ADR 0001 amendment, and the added Firestore write cost at every search submission.

---

## Decision

Sub-decision 1 (routing): A new GoRouter route `/search` is registered in `app_router.dart` as a `GoRoute` inside the existing shell branch. The home screen's `_openSearch` method is replaced with `context.push(RouteConstants.search)`. The placeholder `GestureDetector` container on the home screen is updated to navigate to `/search` rather than showing a SnackBar. The `SearchScreen` widget lives at `lib/features/search/presentation/screens/search_screen.dart`. No modal overlay or `Navigator.push` is used.

Sub-decision 2 (filter composition): The `SearchDatasource` fires one Firestore query per search submission. When a hashtag filter is active, the query uses Index 3 (`hashtags array-contains` the active hashtag, plus `academicLevel` and `studentYear` equality constraints when those filters are also active). When only a keyword or only non-hashtag filters are active, the query fetches public sessions with `status == 'scheduled'` and `scheduledAt >= DateTime.now()` ordered by `scheduledAt asc` (a bounded window, no new index required). All results are post-filtered client-side in the `SearchRepositoryImpl` using AND logic: keyword match on `title.toLowerCase().contains(query)`, hashtag match on `hashtags.any((h) => h == activeHashtag)`, `academicLevel` equality, `studentYear` equality. The quick-filter chips "Today" and "This Week" are implemented as client-side date range filters on `scheduledAt`; no new Firestore index is required. The "My Level" chip filters by the current user's `academicLevel`, read from the `userProvider`, client-side only.

Sub-decision 3 (recent searches): Recent searches are stored in `flutter_secure_storage` under the key `search_recent_<uid>` (UID-scoped to prevent cross-user leakage on shared devices), serialised as a JSON array of strings, capped at 10 entries with FIFO eviction. The `RecentSearchLocalDatasource` in `lib/features/search/data/datasources/recent_search_local_datasource.dart` owns all reads and writes to this key. No Firestore writes are performed for recent searches.

All UX enhancements (loading indicator, result count label, hashtag chips, clear button, debounce, recent search suggestions, quick-filter chips, collapsible filter panel, zero-results state, network error state with retry, search tips tooltip) are gated behind `FeatureFlags.searchEnhancementsEnabled`. When the flag is `false`, the search screen renders only the bare search bar and a flat, unfiltered list of public scheduled sessions — replicating the current home screen behaviour in a dedicated route.

---

## Consequences

- `lib/core/feature_flags.dart` — add `static const bool searchEnhancementsEnabled = false;` following the existing `gcalSyncEnabled` pattern.
- `lib/core/router/app_router.dart` — register `GoRoute(path: '/search', builder: (_, __) => const SearchScreen())` inside the existing shell branch.
- `lib/core/router/route_constants.dart` (or equivalent) — add `static const String search = '/search';`.
- `lib/features/home/presentation/screens/home_screen.dart` — replace `_openSearch` snackbar body with `context.push(RouteConstants.search)`; the fake search bar `GestureDetector` becomes a navigation trigger; no other home screen logic changes.
- New files — domain layer (zero Flutter/Firebase imports):
  - `lib/features/search/domain/entities/search_filter.dart` — Freezed value object holding `String? query`, `String? hashtag`, `String? academicLevel`, `int? studentYear`, `SearchDateRange? dateRange`; `SearchDateRange` is an enum with `today`, `thisWeek`, `myLevel` values (note: `myLevel` is resolved to an `academicLevel` string before the filter reaches the datasource — it is a UI convenience alias only).
  - `lib/features/search/domain/repositories/search_repository.dart` — abstract interface: `Future<List<SessionEntity>> searchSessions(SearchFilter filter)`.
  - `lib/features/search/domain/usecases/search_sessions_usecase.dart` — validates and normalises the filter (trims whitespace, lowercases query and hashtag, throws `SearchError.queryTooShort` if trimmed keyword is non-empty but shorter than 2 characters); delegates to `SearchRepository.searchSessions`; throws `SearchError.offlineNotSupported` when the repository maps a Firestore unavailable error.
- New files — data layer:
  - `lib/features/search/data/datasources/search_datasource.dart` — Firestore calls using path constants from `lib/core/firestore_paths.dart`; implements the Index 3 / bounded-window branching logic described in Sub-decision 2; returns `List<SessionModel>`.
  - `lib/features/search/data/datasources/recent_search_local_datasource.dart` — reads and writes the JSON array from `flutter_secure_storage` under key `search_recent_<uid>`; exposes `Future<List<String>> getRecentSearches(String uid)` and `Future<void> addRecentSearch(String uid, String term)`.
  - `lib/features/search/data/repositories/search_repository_impl.dart` — implements `SearchRepository`; calls `SearchDatasource`; applies client-side AND post-filter; maps `FirebaseException(code: 'unavailable')` to `SearchError.offlineNotSupported`; reuses `SessionModel` from `lib/features/sessions/data/models/`.
- New files — presentation layer:
  - `lib/features/search/presentation/screens/search_screen.dart` — `ConsumerStatefulWidget`; owns the `TextField` with 300 ms debounce (implemented via a `Timer` field, no new package); dispatches to `SearchNotifier` on debounce trigger or on filter chip change; renders result count label, `ListView.builder` of `SessionCard` widgets, zero-results state, and network error state with retry button; collapses filter panel by default.
  - `lib/features/search/presentation/widgets/filter_panel.dart` — collapsible widget containing academic level selector, student year selector, and quick-filter chips (Today, This Week, My Level); gated on `FeatureFlags.searchEnhancementsEnabled`.
  - `lib/features/search/presentation/widgets/hashtag_chip.dart` — renders a single hashtag as a Material chip (visual pill); not a raw string display.
  - `lib/features/search/presentation/widgets/search_suggestions.dart` — renders recent search list and suggested hashtags (derived from the already-loaded result set, not an extra Firestore query) when the text field has focus and query is empty; gated on `FeatureFlags.searchEnhancementsEnabled`.
  - `lib/features/search/presentation/providers/search_provider.dart` — `@riverpod` `AsyncNotifier<List<SessionEntity>>` named `SearchNotifier`; exposes `Future<void> search(SearchFilter filter)`; auto-disposes.
  - `lib/features/search/presentation/providers/filter_provider.dart` — `@riverpod` `Notifier<SearchFilter>` named `SearchFilterNotifier`; exposes `void updateFilter(SearchFilter filter)` and `void clearFilter()`; keeps the current active `SearchFilter`; auto-disposes with the search route.
  - `lib/features/search/presentation/providers/recent_searches_provider.dart` — `@riverpod Future<List<String>> recentSearches(ref, String uid)`; reads from `RecentSearchLocalDatasource`; auto-disposes.
- `lib/core/errors/search_error.dart` — sealed class with variants: `SearchError.queryTooShort`, `SearchError.offlineNotSupported`, `SearchError.unknown(String message)` (message must contain no PII).
- `lib/core/analytics_events.dart` — declare before use:
  - `search_performed` — payload: `has_keyword` (bool), `has_hashtag` (bool), `has_level_filter` (bool), `has_year_filter` (bool), `result_count` (int)
  - `search_filter_applied` — payload: `filter_type` (String: `'academic_level'`, `'student_year'`, `'hashtag'`, `'today'`, `'this_week'`, `'my_level'`)
  - `search_filter_cleared` — no payload
  - `search_result_tapped` — no payload (session ID must not be logged)
  - `search_retry_tapped` — no payload
- `lib/core/firestore_paths.dart` — no new path constants are required; `sessions` collection is already declared; the datasource queries the root `sessions` collection only.
- The existing `SessionCard` widget in `lib/shared/widgets/session_card.dart` is reused on the search results list; no new card widget is created.
- The `userProvider` (already established by ADR 0003 / profile feature) is read by `SearchFilterNotifier` to resolve the `myLevel` chip to the current user's `academicLevel`; this read happens in the presentation layer and is acceptable because it is UI state, not business logic.
- No new composite Firestore indexes are required or permitted.
- No new packages are required.

---

## Reversal plan

If the GoRouter route approach (`/search`) must be reversed (e.g., stakeholders decide the home screen in-place overlay is preferable), remove the `GoRoute` entry from `app_router.dart`, remove `RouteConstants.search`, delete `SearchScreen`, and restore the `_openSearch` snackbar body in `home_screen.dart`. The domain layer (use case, repository interface, entity) and data layer (datasource, repository implementation, local datasource) are unaffected by the route change. The `SearchNotifier` and `SearchFilterNotifier` providers are also unaffected — they can be instantiated from any widget tree. The reversal is low-cost and scoped to three files.

If the Index 3 / client-side hybrid filter composition must be reversed (e.g., a new full-text search service is adopted), replace `SearchDatasource` and `SearchRepositoryImpl` only. The `SearchRepository` abstract interface, the `SearchSessionsUseCase`, and all presentation providers and widgets are unaffected because no Firestore types cross the domain boundary.

If `flutter_secure_storage` for recent searches must be reversed (e.g., cross-device sync becomes a requirement), replace `RecentSearchLocalDatasource` with a Firestore-backed implementation, amend ADR 0001 to add `recentSearches` to `users/{uid}` schema and update the rules `affectedKeys` list, and delete the secure-storage key on migration. The `recentSearchesProvider` consumer in `search_suggestions.dart` is unaffected because it reads from the repository interface. An ADR 0001 amendment and a security review are required before that migration begins.

If `FeatureFlags.searchEnhancementsEnabled` is permanently enabled and the flag constant is no longer needed, remove the compile-time guard from `feature_flags.dart` and from each gated widget. No architectural files change; only the flag constant and the conditional blocks in `SearchScreen`, `FilterPanel`, and `SearchSuggestions` are modified.
