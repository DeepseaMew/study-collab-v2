# 0007 — Calendar Feature Architecture

| Field | Value |
|---|---|
| Status | Proposed |
| Date | 2026-05-22 |
| Architect session | claude-sonnet-4-6 / NichapaJongKmutt / 2026-05-22 |
| Affects | Calendar feature (domain, data, presentation), core/analytics_events.dart, core/firestore_paths.dart, app_router.dart, RouteConstants, pubspec.yaml, no Firestore schema changes (reuses ADR 0001 indexes 1 and 2) |

---

## Team approval

Approved by:
Date:
Notes:

---

## Problem

The Calendar feature requires a monthly/weekly calendar view that shows a KMUTT student's upcoming and past sessions, lets them tap into a session detail screen, and optionally synchronises those sessions to Google Calendar using their registered KMUTT email. Before a Flutter Engineer begins any file, the team needs authoritative answers to five questions. (1) Which calendar UI library renders a monthly/weekly toggle with event markers without introducing a commercial license dependency or excessive build size? (2) How should sessions be loaded from Firestore — a bounded sliding window, an all-time unbounded read, or per-day point queries — given that Index 1 (`memberUids array-contains, scheduledAt asc`) and Index 2 (`memberUids array-contains, status asc, endedAt desc`) already exist in ADR 0001? (3) Should Google Calendar synchronisation use the `google_sign_in` package with incremental OAuth scope, or a custom PKCE OAuth 2.0 flow implemented in the app, or be deferred entirely? (4) Should sync be export-only (sessions → Google Calendar) for MVP, or bidirectional (also importing arbitrary GCal events into the study app)? (5) How should GCal event identity be managed across re-syncs and reinstalls — by storing API-generated event IDs in a Firestore subcollection, deriving a deterministic ID from the session ID, or ignoring identity and risking duplicates? Without a single record, engineers will make incompatible choices on data loading window width, OAuth token storage, and GCal event ID strategy.

---

## Constraints

- Domain layer has zero Flutter or Firebase imports; all Firestore path strings are constants in `lib/core/firestore_paths.dart` only.
- `SessionEntity` is shared from `lib/features/sessions/domain/entities/session_entity.dart` (ADR 0003); it must not be duplicated in the calendar feature.
- Repository interfaces in `domain/repositories/`; implementations in `data/repositories/`; no Firestore or Google API types cross the domain boundary.
- Entities use Freezed; use cases are plain Dart classes.
- All Riverpod providers use `@riverpod` codegen; no hand-written `StateNotifier`.
- No provider may access Firestore or Google APIs directly; all access goes through the repository layer.
- Business logic must not be defined in the presentation layer.
- No unbounded `ListView`; always `ListView.builder` with `itemCount` or paginated.
- All remote images through `cached_network_image`.
- Google Calendar OAuth must validate that the authenticated Google account email matches `users/{uid}.email` before any API call proceeds; comparison must be case-insensitive (`googleUser.email.toLowerCase() == storedEmail.toLowerCase()`); if emails differ the sync operation is aborted and a `CalendarSyncError.emailMismatch` domain error is thrown.
- `connect()` must handle user cancellation of the Google consent screen gracefully; a cancelled sign-in must leave the notifier in its previous disconnected state and must not throw an unhandled exception.
- Domain errors for this feature are sealed subclasses of a new `CalendarSyncError` class in `lib/core/errors/calendar_sync_error.dart`: `emailMismatch`, `apiFailure`, `cancelled`.
- KMUTT email domain gate (`@mail.kmutt.ac.th` / `@kmutt.ac.th`) is enforced in Firestore rules (ADR 0001); this ADR does not amend those rules.
- No new Firestore collection or subcollection is introduced; no ADR 0001 amendment is required.
- Token lifecycle for `google_sign_in` is managed by the package itself; only the last-sync timestamp is persisted by the app via `flutter_secure_storage`.
- Target platforms are Android and Web (not iOS), matching CLAUDE.md. `google_sign_in` requires platform-specific setup on both: Android needs the debug/release SHA-1 fingerprint registered in Firebase Console; Web needs a web OAuth client ID added as a `<meta>` tag in `web/index.html`.
- Window-sliding logic (detecting when the user has navigated beyond ±1 month and computing new `windowStart`/`windowEnd`) is business logic and must live in a `CalendarWindowNotifier` Riverpod provider, not in `CalendarScreen`.
- All log calls go through `lib/core/logger.dart` only; never `print()`. Google Calendar API errors must be logged at `error` level and recorded as non-fatal Crashlytics events.
- The Google Calendar sync capability must be gated behind a feature flag (`gcal_sync_enabled`) so it can be disabled independently of the calendar view in case of GCal API instability.
- No PII in logs, Crashlytics keys, or analytics events.
- Every analytics event declared in `lib/core/analytics_events.dart` before use.
- Calendar navigation to session detail follows the routing rule established in ADR 0003: if `session.hostUid == currentUserId` push `/my-sessions/session/:id/host`, otherwise push `/my-sessions/session/:id/member`.

---

## Options considered

### Sub-decision 1 — Calendar UI library

| | Option A — `table_calendar` | Option B — Custom-built calendar widget | Option C — Syncfusion Flutter Calendar |
|---|---|---|---|
| Summary | MIT-licensed package; monthly/weekly `CalendarFormat` toggle built-in; event marker API; selected-day callback | Bespoke Flutter widget built for this project only | Commercial package (community license free up to a revenue threshold; Enterprise license required above threshold) |
| Implementation effort | Low — integrate and configure | High — build and maintain scroll logic, date math, touch targets, accessibility | Low — integrate and configure |
| Monthly/weekly toggle | Built-in `CalendarFormat` enum | Must be hand-coded | Built-in |
| Event markers | Built-in `eventLoader` callback | Must be hand-coded | Built-in |
| License cost | None (MIT) | None | Free community tier with revenue cap; Enterprise license required at scale |
| Binary size impact | Small | Minimal | Large (full suite bundled) |
| Reversal cost | Low — contained to one screen file | Medium — widget is bespoke and spread through presentation layer | Medium — license change could force migration |
| Recommendation | Yes | No | No |

`table_calendar` is recommended. It provides the required monthly/weekly toggle and event marker APIs under MIT license with minimal binary impact. The custom-built option carries unacceptable implementation cost for MVP. Syncfusion introduces commercial license risk as the app scales.

---

### Sub-decision 2 — Session data loading strategy

| | Option A — Sliding 3-month window stream | Option B — All-time unbounded stream | Option C — Per-day point queries |
|---|---|---|---|
| Summary | One Firestore stream covering `scheduledAt` from start of previous month to end of next month; re-query when user navigates more than one month beyond the window | Single stream `memberUids array-contains uid` with no date filter | Separate Firestore query per selected calendar day |
| Firestore read cost | Bounded; ~3 months of sessions per stream; re-queries only on far navigation | Unbounded; grows with the user's session history indefinitely | One query per tapped day; no pre-fetching; cost accrues with taps |
| Index reuse | Reuses Index 1 from ADR 0001 (`memberUids array-contains, scheduledAt asc`); no new index needed | Reuses Index 1 partially but requires client-side sorting only; still unbounded | Requires a different composite index: `memberUids array-contains, scheduledAt` with equality range — effectively still Index 1; acceptable, but latency appears on every day tap |
| Offline support | Firestore offline cache covers the current window | Full history cached (cache bloat risk) | Only cached if that specific day has been queried before; effectively no predictable offline support |
| UI responsiveness | Event markers available for the full 3-month window before any day is tapped | Same, but at unbounded read cost | Event markers unavailable until per-day queries complete; visible loading latency per day tap |
| Reversal cost | Low — window width change is confined to `calendar_datasource.dart` and `calendarSessions` provider parameter | Low — add date filters to narrow the stream | Low — switch to window query; requires adding provider state for window bounds |
| Recommendation | Yes | No | No |

The 3-month sliding window is recommended. It bounds read costs, reuses Index 1 with no new index, and ensures event markers are populated for the visible month before any day is tapped. The unbounded stream grows indefinitely with session history. Per-day queries produce visible latency on every tap and provide no predictable offline support.

---

### Sub-decision 3 — Google Calendar OAuth approach

| | Option A — `google_sign_in` with incremental scope | Option B — Custom PKCE OAuth 2.0 flow | Option C — Defer Google Calendar sync |
|---|---|---|---|
| Summary | Use `google_sign_in` package; request `calendar.events` scope only when user enables sync in settings; bridge to `googleapis` via `extension_google_sign_in_as_googleapis_auth` | Implement OAuth 2.0 authorization code flow with PKCE manually; handle token refresh, storage, and revocation in the app | Do not implement Google Calendar sync in this iteration; calendar is display-only |
| Implementation effort | Low — packages handle token refresh, revocation, and platform sign-in UI | High — manual token request, refresh rotation, secure storage, revocation endpoint calls, cross-platform deep-link handling | None |
| Token refresh | Automatic (`google_sign_in` handles it) | Manual — app must detect expiry and call refresh endpoint | N/A |
| Incremental scope | Built-in — scope requested at first sync tap, not at app launch | Possible but requires additional code | N/A |
| Secure storage | `google_sign_in` manages tokens natively; app stores only last-sync timestamp via `flutter_secure_storage` | App must store `access_token`, `refresh_token`, and expiry via `flutter_secure_storage` | N/A |
| Error surface | Package-contained; well-tested on Android and Web | Large — custom code for every error path | N/A |
| Reversal cost | Low — replace `google_sign_in` with `flutter_appauth` or custom flow in `CalendarSyncRepositoryImpl`; domain interface unchanged | Medium — custom token logic is spread through the data layer | N/A |
| Recommendation | Yes | No | No |

`google_sign_in` with incremental scope is recommended. The package manages token lifecycle, minimises error surface, and requires the app to store only the last-sync timestamp. A custom PKCE flow would require several hundred lines of manual token management code for no benefit over the established package. Deferring sync is acceptable but the feature is already in the approved feature list.

---

### Sub-decision 4 — Google Calendar sync direction

| | Option A — Export-only (sessions → GCal) | Option B — Bidirectional (sessions ↔ GCal) |
|---|---|---|
| Summary | Export study sessions to GCal so students see them alongside their university timetable; no import of arbitrary GCal events into the study app | Both directions: export sessions to GCal and import GCal events into the study app calendar view |
| Scope | `calendar.events` write; read used only to check event existence before insert | `calendar.events` read + write; plus deduplication logic, GCal-event entity type, separate tile rendering |
| Implementation effort | Low | High — requires deduplication, a new entity type, separate UI tile for GCal events, and conflict resolution |
| User value | High — study sessions appear in a calendar students already use daily | Moderate — importing arbitrary GCal events into a study-session app is low value for MVP |
| Domain model impact | No new entity required | Requires a new `GCalEventEntity` and separate tile type in `CalendarScreen` |
| Reversal cost | Low — add import method to `CalendarSyncRepository` in a future ADR; no schema changes required | Medium — removing import would require cleaning up the extra entity, provider state, and tile type |
| Recommendation | Yes | No |

Export-only is recommended for MVP. Students benefit immediately from seeing study sessions in Google Calendar alongside their university timetable. Importing arbitrary GCal events is low value and requires deduplication logic that is premature at this stage. The `calendar.events` scope already covers read, so import can be added without a scope change in a future ADR.

---

### Sub-decision 5 — Google Calendar event identity (idempotency)

| | Option A — Deterministic SHA-1 event ID from sessionId | Option B — Store API-generated event ID in Firestore subcollection | Option C — No identity tracking; always insert |
|---|---|---|---|
| Summary | Derive GCal event ID as `'sc' + sha1hex(sessionId)` (42 chars, charset `[a-v0-9]`); re-syncing calls `events.patch` with the same ID | On first sync, store the GCal-returned event ID in `users/{uid}/gcal_events/{sessionId}`; on re-sync, read that ID then call `events.patch` | On every sync, call `events.insert`; rely on GCal deduplication or accept duplicates |
| Idempotency | Yes — same sessionId always produces the same 42-char GCal event ID within GCal's allowed charset (`[a-v0-9]`, 5–1024 chars) | Yes — stored ID is looked up before each patch | No — creates duplicate GCal events on re-sync or reinstall |
| Extra Firestore reads | None | One read per session per sync | None |
| ADR 0001 amendment required | No | Yes — new subcollection required | No |
| Package required | `crypto` (explicit dependency; SHA-1 from `dart:convert` digest) | None beyond existing stack | None |
| Reversal cost | Low — change confined to `gcal_datasource.dart`; if GCal changes charset requirements, fall back to Option B | Medium — subcollection documents must be migrated or cleaned up | N/A (this option is not viable) |
| Recommendation | Yes | No | No |

The SHA-1 deterministic event ID is recommended. It eliminates duplicate GCal events across re-syncs and reinstalls without adding a Firestore subcollection or requiring an ADR 0001 amendment. The `'sc'` prefix (both chars in `[a-v]`) combined with 40 hex chars from SHA-1 produces a 42-character ID within GCal's allowed charset. Re-syncing always calls `events.patch`, which updates the existing event in place.

---

## Decision

The Calendar feature adopts five coordinated decisions. Sub-decision 1: `table_calendar` (MIT) provides the monthly/weekly `CalendarFormat` toggle and event marker API with no license risk and minimal binary impact. Sub-decision 2: a sliding 3-month window Firestore stream (`memberUids array-contains uid` AND `scheduledAt >= startOfPrevMonth` AND `scheduledAt <= endOfNextMonth`) reuses Index 1 from ADR 0001 with no new composite index; the window bounds are managed by a `CalendarWindowNotifier` Riverpod notifier (not in `CalendarScreen`) so that business logic stays outside the presentation layer; the day session list is rendered inline below the calendar widget (not as a pushed screen) via `ListView.builder`. Sub-decision 3: Google Calendar OAuth uses `google_sign_in` with incremental scope (`calendar.events` requested only when the user enables sync in the sync-settings screen), bridged to `googleapis` via `extension_google_sign_in_as_googleapis_auth`; the app validates email case-insensitively before any API call and aborts with a `CalendarSyncError.emailMismatch` domain error on mismatch; cancellation of the consent screen is caught and surfaced as `CalendarSyncError.cancelled`; token lifecycle is managed by `google_sign_in` and only the last-sync timestamp is persisted via `flutter_secure_storage`; the GCal sync capability is gated behind a `gcal_sync_enabled` feature flag. Sub-decision 4: sync is export-only for MVP; study sessions are written to Google Calendar so students see them alongside their university timetable; bidirectional import is deferred. Sub-decision 5: GCal event identity uses a deterministic ID of `'sc' + sha1hex(sessionId)` (42 chars, charset `[a-v0-9]`), eliminating duplicate events on re-sync or reinstall without a new Firestore subcollection and without amending ADR 0001. Navigation from calendar session tiles follows ADR 0003's routing rule: host-owned sessions push `/my-sessions/session/:id/host`; joined sessions push `/my-sessions/session/:id/member`.

---

## Consequences

### New packages — add to `apps/mobile/pubspec.yaml`

- `table_calendar`
- `google_sign_in` (explicit direct dependency; may already be transitive)
- `googleapis`
- `extension_google_sign_in_as_googleapis_auth`
- `crypto` (explicit direct dependency for SHA-1)

### New routes — add to `RouteConstants` and wire in `app_router.dart`

| Route | Screen | Notes |
|---|---|---|
| `/calendar` | `CalendarScreen` | StatefulShellRoute branch 2 — matches bottom nav bar |
| `/calendar/sync-settings` | `CalendarSyncSettingsScreen` | Pushed from `CalendarScreen` app bar action |

### Domain errors

- `lib/core/errors/calendar_sync_error.dart` — sealed class with three variants:
  - `CalendarSyncError.emailMismatch` — Google account email does not match `users/{uid}.email`
  - `CalendarSyncError.apiFailure(String message)` — Google Calendar API returned an error; `message` must contain no PII
  - `CalendarSyncError.cancelled` — user dismissed the Google consent screen

### Domain entities

- `lib/features/calendar/domain/entities/sync_result.dart` — Freezed; fields: `syncedCount` (int), `failedCount` (int), `syncedAt` (DateTime).
- `SessionEntity` is **not** duplicated; import from `lib/features/sessions/domain/entities/session_entity.dart`.

### Domain use cases

- `lib/features/calendar/domain/usecases/watch_sessions_in_range_usecase.dart` — delegates to `CalendarRepository.watchSessionsInRange`; no additional logic.
- `lib/features/calendar/domain/usecases/connect_gcal_usecase.dart` — reads `users/{uid}.email` via `UserRepository`, then calls `CalendarSyncRepository.connect(email)`; throws `CalendarSyncError.emailMismatch` on mismatch.
- `lib/features/calendar/domain/usecases/sync_gcal_usecase.dart` — receives a `List<SessionEntity>` and delegates to `CalendarSyncRepository.syncSessions`.
- `lib/features/calendar/domain/usecases/disconnect_gcal_usecase.dart` — delegates to `CalendarSyncRepository.disconnect`.

### Domain repository interfaces

- `lib/features/calendar/domain/repositories/calendar_repository.dart`
  - `Stream<List<SessionEntity>> watchSessionsInRange(String uid, DateTime start, DateTime end)`
- `lib/features/calendar/domain/repositories/calendar_sync_repository.dart`
  - `Future<bool> isConnected()`
  - `Future<void> connect(String expectedEmail)` — triggers Google OAuth; validates email case-insensitively; throws `CalendarSyncError.emailMismatch` on mismatch; throws `CalendarSyncError.cancelled` on consent dismissal
  - `Future<void> disconnect()` — revokes OAuth grant and clears stored last-sync timestamp
  - `Future<SyncResult> syncSessions(List<SessionEntity> sessions)` — exports sessions to GCal via `events.patch`; throws `CalendarSyncError.apiFailure` on Google API error

### Data layer files

- `lib/features/calendar/data/datasources/calendar_datasource.dart` — Firestore stream with `memberUids array-contains uid` + `scheduledAt` range filter; path constants from `lib/core/firestore_paths.dart`
- `lib/features/calendar/data/datasources/gcal_datasource.dart` — `googleapis` `CalendarApi` calls; converts `SessionEntity` to `Event`; derives event ID as `'sc' + sha1hex(session.sessionId)`; calls `events.patch` (upsert semantics); no `supportsAttachments`
- `lib/features/calendar/data/repositories/calendar_repository_impl.dart`
- `lib/features/calendar/data/repositories/calendar_sync_repository_impl.dart` — `google_sign_in` + `extension_google_sign_in_as_googleapis_auth`; email validation; stores last-sync timestamp under `flutter_secure_storage` key `gcal_last_sync_{uid}`

### Presentation providers

- `lib/features/calendar/presentation/providers/calendar_window_provider.dart` — `@riverpod` notifier (`CalendarWindowNotifier`) holding `windowStart` and `windowEnd` as `DateTime`; exposes `advanceToMonth(DateTime month)` which computes a new 3-month window and invalidates `calendarSessionsProvider`; `keepAlive: true` on the StatefulShellRoute branch so the window survives tab switches.
- `lib/features/calendar/presentation/providers/calendar_sessions_provider.dart` — `@riverpod Stream<List<SessionEntity>> calendarSessions(ref, String uid, DateTime windowStart, DateTime windowEnd)`; `autoDispose` disabled while the calendar shell branch is active.
- `lib/features/calendar/presentation/providers/calendar_sync_provider.dart` — `@riverpod` async notifier exposing `isConnected`, `lastSyncAt`, `syncNow()`, `connect()`, `disconnect()`; exposes `AsyncValue<SyncResult?>` so `CalendarSyncSettingsScreen` can render loading, error (`CalendarSyncError`), and success states without presentation-layer branching.

### Presentation screens

- `lib/features/calendar/presentation/screens/calendar_screen.dart` — `table_calendar` widget in top half; `ListView.builder` in bottom half showing sessions for the selected day; month-page change calls `CalendarWindowNotifier.advanceToMonth()`; session tile tap routes per ADR 0003 rule; every calendar cell and session tile wrapped in `Semantics` with `label` and `selected` attributes; minimum cell touch target 44 × 44 dp.
- `lib/features/calendar/presentation/screens/calendar_sync_settings_screen.dart` — shows connected-account badge, "Sync Now" button, "Disconnect" button, last-sync timestamp display; renders `AsyncValue.error` as an inline error banner naming the `CalendarSyncError` variant; email-mismatch warning is distinct from generic API failure.

### Session → Google Calendar event field mapping

| GCal event field | Source |
|---|---|
| `id` | `'sc' + sha1hex(session.sessionId)` |
| `summary` | `session.title` |
| `description` | `session.description ?? ''` + `'\n\nHost: ${session.hostDisplayName}'` + `'\nStatus: ${session.status}'` |
| `location` | `session.location` |
| `start.dateTime` | `session.scheduledAt` converted to RFC 3339 in local timezone |
| `end.dateTime` | `session.scheduledEndAt` converted to RFC 3339 in local timezone |
| `source.title` | `'Study Collab'` |
| `source.url` | Omit until deep-link is implemented |

### Analytics events — declare in `lib/core/analytics_events.dart` before use

- `calendar_view_format_toggled` — payload: `format` (`'monthly'` | `'weekly'`)
- `calendar_day_selected` — no payload
- `calendar_session_tapped` — no payload
- `calendar_sync_connected` — no payload
- `calendar_sync_disconnected` — no payload
- `calendar_sync_completed` — payload: `synced_count` (int), `failed_count` (int)
- `calendar_sync_failed` — payload: `error_type` (String, no PII — e.g. `'email_mismatch'`, `'api_error'`)

### Logging and observability

All log calls use `lib/core/logger.dart` only; never `print()`. No PII in any log message.

| Call site | Level | Message (no PII) |
|---|---|---|
| `CalendarDatasource` — window query start | `debug` | `'calendar: querying sessions windowStart=$start windowEnd=$end'` |
| `CalendarSyncRepositoryImpl.connect()` — email mismatch | `warning` | `'gcal_sync: email mismatch; aborting connect'` |
| `CalendarSyncRepositoryImpl.connect()` — cancelled | `info` | `'gcal_sync: user cancelled consent screen'` |
| `GcalDatasource.patchEvent()` — API error | `error` | `'gcal_sync: events.patch failed errorCode=$code'` |
| `GcalDatasource.syncSessions()` — completed | `info` | `'gcal_sync: sync complete synced=$count failed=$failed'` |

Google Calendar API errors caught in `GcalDatasource` must be recorded as non-fatal Crashlytics events via `FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: false)` before being re-thrown as `CalendarSyncError.apiFailure`.

### Test matrix (qa-engineer owns; must be complete before Flutter Engineer begins presentation layer)

| Test type | File | What to verify |
|---|---|---|
| Unit | `test/features/calendar/data/calendar_datasource_test.dart` | Stream emits correct `SessionEntity` list for a date range; empty result when no sessions in range |
| Unit | `test/features/calendar/data/gcal_datasource_test.dart` | SHA-1 event ID is deterministic for a fixed sessionId; `events.patch` called with correct field mapping; `CalendarSyncError.apiFailure` thrown on `DetailedApiRequestError` |
| Unit | `test/features/calendar/data/calendar_sync_repository_impl_test.dart` | Email mismatch throws `CalendarSyncError.emailMismatch`; cancellation throws `CalendarSyncError.cancelled`; `disconnect()` clears `flutter_secure_storage` key |
| Unit | `test/features/calendar/domain/connect_gcal_usecase_test.dart` | Delegates to repository; propagates domain errors |
| Widget | `test/features/calendar/presentation/calendar_screen_test.dart` | Month/week toggle changes `CalendarFormat`; tapping a day updates the session list; session tile tap pushes correct route (host vs. member) |
| Widget | `test/features/calendar/presentation/calendar_sync_settings_screen_test.dart` | Renders connected-account badge when `isConnected`; "Sync Now" button triggers notifier; `CalendarSyncError.emailMismatch` renders correct banner text |
| Golden | `test/features/calendar/presentation/goldens/calendar_screen_monthly.png` | Monthly layout, event markers, selected-day highlight |
| Golden | `test/features/calendar/presentation/goldens/calendar_screen_weekly.png` | Weekly layout |
| Integration | `test/integration/calendar_sync_test.dart` | Mocked `googleapis`; verify correct number of `events.patch` calls per session count; verify no duplicate calls for same sessionId |

Accessibility sweep (qa-engineer): run `flutter test --tags a11y` on `CalendarScreen` and verify all calendar cells and session tiles carry `Semantics` labels readable by TalkBack (Android) and ChromeVox (Web).

### Web and Android platform setup (Flutter Engineer + release-engineer)

These steps are required before `google_sign_in` works on either platform and must be completed before the CI pipeline can run integration tests for the sync flow.

**Web:**
- Add web OAuth 2.0 client ID to `web/index.html`:
  ```html
  <meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID.apps.googleusercontent.com">
  ```
- Add `google_sign_in_web` to `pubspec.yaml` (platform override for Web).
- Verify `CalendarScreen` renders correctly on Chrome (no scroll physics regression from `table_calendar`).

**Android:**
- Register the debug SHA-1 fingerprint in Firebase Console → Project Settings → Android app.
- Register the release SHA-1 fingerprint before first production build.
- `google-services.json` must include the OAuth client block for `google_sign_in` — regenerate after adding the fingerprint.

### Firestore indexes

No new composite index is required. The 3-month window query reuses:
- Index 1: `sessions` | `memberUids` (array-contains), `scheduledAt` asc | already justified in ADR 0001 as "Calendar — upcoming sessions"
- Index 2: `sessions` | `memberUids` (array-contains), `status` asc, `endedAt` desc | already justified in ADR 0001 as "Calendar — past sessions"

### Implementation checklist for Flutter Engineer

- [ ] Add six packages to `pubspec.yaml`: `table_calendar`, `google_sign_in`, `google_sign_in_web`, `googleapis`, `extension_google_sign_in_as_googleapis_auth`, `crypto`
- [ ] Create `lib/core/errors/calendar_sync_error.dart` — sealed class with `emailMismatch`, `apiFailure`, `cancelled` variants
- [ ] Declare all seven analytics events in `lib/core/analytics_events.dart`
- [ ] Add `/calendar` and `/calendar/sync-settings` to `RouteConstants` and `app_router.dart`
- [ ] Create `SyncResult` Freezed entity
- [ ] Create `CalendarRepository` and `CalendarSyncRepository` interfaces (domain)
- [ ] Create four use cases (domain): `WatchSessionsInRangeUseCase`, `ConnectGCalUseCase`, `SyncGCalUseCase`, `DisconnectGCalUseCase`
- [ ] Create `CalendarDatasource` and `GcalDatasource` (data); add `logger.dart` calls at specified call sites
- [ ] Create `CalendarRepositoryImpl` and `CalendarSyncRepositoryImpl` (data); handle `cancelled` path from `google_sign_in`
- [ ] Non-fatal Crashlytics record in `GcalDatasource` on API error
- [ ] Create `CalendarWindowNotifier`, `calendarSessionsProvider`, `calendarSyncProvider` (presentation)
- [ ] Create `CalendarScreen` and `CalendarSyncSettingsScreen` (presentation); wrap all interactive elements in `Semantics`; verify 44 × 44 dp minimum touch target on calendar cells
- [ ] Add `gcal_sync_enabled` feature flag check in `CalendarSyncSettingsScreen` before rendering sync controls
- [ ] Complete Web platform setup (meta tag in `index.html`, `google_sign_in_web`)
- [ ] Complete Android platform setup (SHA-1 in Firebase Console, regenerate `google-services.json`)
- [ ] Verify domain layer has zero Flutter and Firebase imports (`dart run build_runner build` must pass with no import lint errors)

### Agent hand-off

- **QA engineer** must produce the full test matrix above and complete the accessibility sweep before the Flutter Engineer begins the presentation layer.
- **Security reviewer** must audit `CalendarSyncRepositoryImpl` and `GcalDatasource` (email validation logic, token lifecycle, Crashlytics key usage) before the PR is merged.
- **Release engineer** must confirm `gcal_sync_enabled` feature flag is off in the production release until the sync integration test passes in CI.

---

## Reversal plan

**Sub-decision 1 (table_calendar):** If the library is abandoned or becomes incompatible with a future Flutter version, replace the `table_calendar` widget section in `CalendarScreen` only. The domain, data, and provider layers are entirely unaffected. Reversal cost: low — one screen file and its imports.

**Sub-decision 2 (3-month sliding window):** If session volume grows such that a 3-month window returns too many documents, narrow the window to the current month only and pre-fetch ±1 month lazily. The change is confined to `calendar_datasource.dart` and the `calendarSessions` provider's `windowStart`/`windowEnd` parameters. No domain entity, use case, or presentation logic changes are required.

**Sub-decision 3 (google_sign_in):** If `google_sign_in` is replaced (e.g., by `flutter_appauth` for PKCE compliance), changes are confined to `CalendarSyncRepositoryImpl`. The `CalendarSyncRepository` domain interface, all use cases, and both screens are unaffected. The `CalendarSyncError` sealed class remains unchanged.

**Sub-decision 4 (export-only sync):** To add import (GCal events → study app), add a `watchGCalEvents(String uid, DateTime start, DateTime end)` method to `CalendarSyncRepository`, request `calendar.readonly` scope (already covered by `calendar.events`), introduce a `GCalEventEntity` in the calendar domain, and render GCal events as a distinct tile type in `CalendarScreen`. No Firestore schema changes are required; a new ADR covering the import strategy is required before the Flutter Engineer begins.

**Sub-decision 5 (SHA-1 event ID):** If Google changes the allowed GCal event ID charset or deprecates custom event IDs, amend ADR 0001 to add a `users/{uid}/gcal_events/{sessionId}` subcollection for storing API-generated event IDs, update `GcalDatasource` to look up or store the ID on each sync, and update `CalendarSyncRepositoryImpl` accordingly. The domain interface (`CalendarSyncRepository`) is unaffected.
