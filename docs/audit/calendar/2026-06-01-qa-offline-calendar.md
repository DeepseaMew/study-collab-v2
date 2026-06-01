# Audit report

| Field | Value |
|---|---|
| Agent | qa-engineer |
| Date | 2026-06-01 |
| Session ID | claude-sonnet-4-6 / qa-engineer / 2026-06-01 |
| Triggered by | Commits a078363 and b627903 on develop — offline-first calendar |
| Reviewed scope | lib/features/calendar/data/datasources/calendar_datasource.dart, lib/features/calendar/presentation/screens/calendar_screen.dart, lib/features/calendar/presentation/widgets/offline_banner.dart, lib/core/connectivity/connectivity_provider.dart |

---

## QA Engineer section

### Coverage

| Layer | File | Test file | Notes |
|---|---|---|---|
| Data — datasource | `calendar_datasource.dart` | `calendar_datasource_test.dart` | 6 unit tests pass; cache-vs-live log branch is exercised (mock returns `isFromCache: false`); `isFromCache: true` branch has no dedicated test — the log line emitting "serving from Firestore cache" is never asserted |
| Presentation — screen | `calendar_screen.dart` | `calendar_screen_test.dart` | 11 widget tests; `isOnlineProvider` is overridden to `true` in every test; the offline path (banner shown) has zero widget test coverage |
| Presentation — screen | `calendar_screen.dart` | `calendar_screen_golden_test.dart` | 2 golden tests at scale 1.0 and 1.5 — **both fail to compile** (see Failures) |
| Presentation — widget | `offline_banner.dart` | none | No dedicated widget test exists for `OfflineBanner` |
| Core — provider | `connectivity_provider.dart` | none | `isOnlineProvider` logic has no unit test verifying the `results == null` → true default or the `results.any(...)` evaluation |

- Domain coverage: all 4 calendar use cases continue to be covered at >80% (unchanged from previous QA report 2026-05-22); the offline feature adds no new domain use cases
- Screens with widget tests: 3 / 3 calendar screens have at least one smoke test; however the `CalendarScreen` offline path is not exercised in any test
- Golden tests: 1 screen (CalendarScreen) at 2 text scales — **both golden test files fail to compile** due to a missing codegen artifact in an unrelated feature; the stored golden PNG files in `test/features/calendar/presentation/goldens/` were regenerated in commit a078363 (diff images in `failures/` confirm pixel changes after the `OfflineBanner` import was added) but cannot be verified by re-running the test suite until the build error is resolved

**Test run result: 81 passed, 3 test files failed to load (load error, not test logic failure)**
- Passed: all data, domain, and `CalendarSyncSettingsScreen` tests — 81 tests across `calendar_datasource_test.dart`, `calendar_sync_repository_impl_test.dart`, `gcal_datasource_test.dart`, `calendar_sync_error_test.dart`, `gcal_usecases_test.dart`, `watch_sessions_in_range_usecase_test.dart`, `calendar_window_provider_test.dart`, `calendar_sync_settings_screen_test.dart`
- Failed to load: `calendar_day_screen_test.dart`, `calendar_screen_golden_test.dart`, `calendar_screen_test.dart` — all three fail with the same root-cause compilation error described below

### Failures

- `calendar_day_screen_test.dart` (load failure) → `note_sharing_flag_provider.g.dart` is missing from `lib/features/note_sharing/presentation/providers/`; `build_runner` has not been run after the note-sharing flag provider was added, so the generated `part` file is absent and the entire compilation unit fails → run `dart run build_runner build --delete-conflicting-outputs` from `apps/mobile/` to regenerate codegen files; this is a pre-existing issue introduced before these commits and blocks all widget tests that transitively import any note-sharing provider
- `calendar_screen_golden_test.dart` (load failure) → same root cause as above; golden verification cannot complete; the stored golden PNGs in `goldens/` were updated in commit a078363 but cannot be asserted until the build error is fixed
- `calendar_screen_test.dart` (load failure) → same root cause as above; the 11 widget tests covering `CalendarScreen` (including smoke test and overflow-pill logic) cannot run

### Flaky (quarantined)

- none — no test was observed to be flaky; the 3 failures are deterministic compilation errors, not intermittent failures

### Gaps

- `OfflineBanner` widget — no widget test covers the offline state: no test verifies that `OfflineBanner` renders when `isOnlineProvider` is `false`, that it disappears when `isOnlineProvider` switches back to `true`, or that the `Semantics` label "Offline — showing last loaded schedule" is present in the semantic tree → high risk; this is the primary new UI surface introduced by these commits and it has no automated coverage at all
- `isFromCache` log branch in `CalendarDatasource` — the `appLogger.debug` line emitting `'calendar: serving from Firestore cache count=...'` is never triggered in the unit test because the mock `SnapshotMetadata` always returns `isFromCache: false`; the complementary branch ("live data received") is exercised → low risk for log correctness, but the cache branch is untested
- `isOnlineProvider` unit test — the provider logic (`results == null → true`, `results.any(r => r != ConnectivityResult.none)`) has no unit test; the default-to-online fallback on null is especially important to verify so the app does not incorrectly show the offline banner on first launch before the connectivity stream emits → medium risk
- Golden tests at scale 1.5 with offline banner visible — the stored goldens in commit a078363 reflect the online state (`isOnlineProvider.overrideWithValue(true)`); there is no golden capturing the offline state with `OfflineBanner` at either scale → medium risk; dynamic-type overflow inside the banner text at scale 1.5 is unverified
- Transition test — no test verifies the banner disappears when the device reconnects (i.e., `isOnlineProvider` emits `true` after having emitted `false`); this is a reactive state change that requires a widget test with provider state mutation → medium risk

### Accessibility findings

- `OfflineBanner` widget — the `wifi_off_rounded` icon is wrapped in `ExcludeSemantics` — PASS; decorative icon is correctly hidden from screen readers per WCAG 1.1.1
- `OfflineBanner` widget — the outer `Semantics(label: 'Offline — showing last loaded schedule')` provides a programmatic name for the banner as a whole — PASS; WCAG 1.3.1
- `OfflineBanner` widget — the `Text` widget inside the banner is a child of the `Semantics` node; the text content "You're offline — showing your last loaded schedule" is readable by TalkBack/VoiceOver via the parent semantics label — PASS; WCAG 4.1.2
- `OfflineBanner` widget — background color is `Color(0xFFFFF8E1)` (pale yellow) and text color is `AppColors.text`; contrast ratio between `AppColors.text` (dark near-black, inferred from app theme as approximately #212121) and `0xFFFFF8E1` (approximately #FFF8E1) is expected to exceed 7:1, well above the 4.5:1 WCAG 2.2 AA threshold for normal text — PASS; WCAG 1.4.3; note: formal contrast measurement was not possible without running the accessibility tool on a rendered frame due to the build error; this finding should be re-confirmed once the build is green
- Dynamic type at scale 1.5 — the `OfflineBanner` uses `Theme.of(context).textTheme.bodySmall` inside an `Expanded` widget; `Expanded` prevents overflow by constraining the text to the remaining row width; the text will wrap rather than clip at large scales — PASS; WCAG 1.4.4; note: not verified by a passing golden test due to the build error

### Performance findings

- `calendar_datasource.dart` — all Firestore calls use `snapshots()` stream (async) — PASS
- `calendar_screen.dart` `_DaySessionsPanel` — pre-existing `ListView(children: [...])` convention violation (noted in 2026-05-22 QA report); not changed by these commits — carry-over finding, required fix pending
- No `Image.network` or `print()` calls introduced by these commits — PASS
- `isOnlineProvider` is annotated `keepAlive: true`; it holds a single boolean and a stream subscription — no memory concern — PASS

### Verdict

- FAIL — the three presentation test files (`calendar_screen_test.dart`, `calendar_screen_golden_test.dart`, `calendar_day_screen_test.dart`) fail to compile due to a missing `note_sharing_flag_provider.g.dart` codegen file; this blocks all widget-level and golden verification for the changed screens; additionally, the primary new surface (`OfflineBanner`) has no test coverage and the offline state of `CalendarScreen` is untested; both issues must be resolved before this change can be considered verified
