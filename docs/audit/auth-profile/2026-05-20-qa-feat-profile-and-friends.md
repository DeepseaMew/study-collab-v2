# Audit report

| Field | Value |
|---|---|
| Agent | qa-engineer |
| Date | 2026-05-20 |
| Session ID | c1808805-9f1a-4b73-8f74-ea5e213d2f65 |
| Triggered by | feat/profile-and-friends — full QA sweep |
| Reviewed scope | friends feature, profile feature, avatar upload, home screen, shared widgets (avatar_widget, session_card, main_shell), app_router, firestore.indexes.json |

---

## QA Engineer section

### Coverage
- Domain coverage: 33.3% (14/42 tracked domain lines hit; 14/26 domain dart files not instrumented at all — interfaces and entity files with zero executable lines are excluded by the Dart coverage tool but the 14 covered files only contain use-case delegations; the friends and profile use-cases for watch_friends and watch_incoming_requests are not reached by any test) — **below 80% target**
- Overall line coverage: 34.0% (1815/5333 lines)
- Screens with widget tests: 10 / 17 (smoke tests exist for sign_in, sign_up, verify_email, profile_setup, home, create_session, session_detail, my_sessions, host_session_detail, member_session_detail; **no widget test** for friends_screen, friend_requests_screen, profile_screen, other_user_profile_screen, edit_session_screen, members_list_screen, requests_screen)
- Golden tests: 10 screens at 2 text scales (1.0 and 1.5) each — sign_in, sign_up, verify_email, profile_setup, home, create_session, session_detail, my_sessions, host_session_detail, member_session_detail; **0 golden tests** for the 7 new/modified screens introduced by this feature (friends_screen, friend_requests_screen, profile_screen, other_user_profile_screen, and the 3 session-detail screens that already had goldens before this PR)

### Failures
- none — all 167 tests passed in the `flutter test --coverage` run

### Flaky (quarantined)
- none

### Gaps

**Friends feature — unit test gaps (HIGH risk):**
- `FriendsDatasource.sendRequest` WriteBatch writes both sides atomically — no unit test verifying batch construction or atomicity
- `FriendsDatasource.acceptRequest` cross-populates `friendDisplayName`/`friendPhotoUrl` on both sides — no unit test
- `FriendsDatasource.declineRequest` deletes both pending documents — no unit test
- `FriendsDatasource.withdrawRequest` deletes both pending documents — no unit test
- `FriendsDatasource.unfriend` deletes both accepted documents — no unit test
- `watchIncomingRequests` filters `initiatorUid != uid` client-side in the stream `.map` — no unit test verifying the filter logic; wrong initiator documents would appear in the inbox
- `FriendsRepositoryImpl.acceptRequest` reads both user documents before committing the accept batch — no unit test

**Friends feature — widget test gaps (HIGH risk):**
- `FriendsScreen` Friends tab empty-state — no widget test
- `FriendsScreen` Requests tab empty-state — no widget test
- `FriendsScreen` smoke test absent entirely — no widget test for the screen
- `FriendRequestsScreen` smoke test absent — no widget test
- `AddFriendButton` all 5 `FriendshipStatus` states rendered correctly — no widget test

**Profile feature — unit test gaps (HIGH risk):**
- `ProfileDatasource.updateProfile` / `UserRepositoryImpl.updateProfile` always sends `updatedAt: FieldValue.serverTimestamp()` — no unit test
- `UserRepositoryImpl.updateProfile` — no unit test

**Profile feature — widget test gaps (HIGH risk):**
- `ProfileScreen` smoke test absent — no widget test (loading, error, data, and null-user states all untested)
- `ProfileScreen` back-button presence when pushed vs. from shell nav — no widget test
- `ProfileScreen` Session History section (up to 5, See All button) — no widget test
- `OtherUserProfileScreen` loading / error / not-found / data states — no widget test
- `EditProfileSheet` validates non-empty displayName before saving — no widget test

**Avatar upload — unit test gaps (HIGH risk):**
- Full 9-step ADR 0005 happy-path flow in `AvatarDatasource.pickAndUpload` — no unit test
- Cache-bust uses `&v=` (not `?v=`) because Firebase download URLs already contain `?alt=media&token=` — no assertion or unit test; a future refactor could silently revert to `?v=` and break cache-busting on live URLs
- `StorageUploadFailure` thrown on `FirebaseException` in upload step — no unit test
- Firestore write failure after Storage success triggers retry-once in `AvatarRepositoryImpl` — no unit test
- Retry failure fires `avatarUploadFailed` analytics event — no unit test

**Home screen — widget/unit test gaps (MEDIUM risk):**
- `HomeScreen` tapping avatar navigates to `/profile` — no widget test
- `HomeScreen` tapping host name/avatar in a session card navigates to other-user profile — no widget test (covered only by `SessionCard` tap on `GestureDetector`, not end-to-end)
- `HomeScreen` "Join with PIN" button opens `_PinEntryDialog` — no widget test
- `HomeScreen` `findSessionByPin` valid PIN → navigates to session detail — no unit test
- `HomeScreen` `findSessionByPin` invalid PIN → shows snackbar — no unit test
- `SessionCard` shows "Pending..." when `myPendingRequestProvider` returns true — no widget test (only the static `isPending: true` render path)
- Sessions where `memberUids` contains the current uid excluded from home feed — no unit test for the client-side filter in `HomeScreen`

**`findSessionByPin` — composite index (CRITICAL — blocks production queries):**
- ADR 0005 (and the home-screen scope) require a composite index `(pin ASC, visibility ASC, status ASC)` for `findSessionByPin`. `firestore.indexes.json` contains an index with fields `pin, visibility, status` (all `ASCENDING`) on the `sessions` collection — **index is present and correct**.

**Golden test gaps (HIGH risk):**
- `FriendsScreen` — no golden at scale 1.0 or 1.5
- `FriendRequestsScreen` — no golden at scale 1.0 or 1.5
- `ProfileScreen` — no golden at scale 1.0 or 1.5
- `OtherUserProfileScreen` — no golden at scale 1.0 or 1.5
- `EditProfileSheet` — no golden at scale 1.0 or 1.5

**Session History routing (MEDIUM risk — unresolved):**
- `ProfileScreen` Session History renders `SessionCard` items with `onTap: () {}` (empty lambda, lines 289-295 of profile_screen.dart). Tapping a card does nothing. The ADR 0003 routing contract (host → `/my-sessions/session/:id/host`, member → `/my-sessions/session/:id/member`) is **not wired**; this is a confirmed functional gap. No test fails on it because the `onTap` is silently a no-op.

### Accessibility findings

- `add_friend_button.dart` → `_PrimaryButton` (FilledButton) and `_OutlinedActionButton` (OutlinedButton) have no explicit `Semantics` label or `tooltip`; the button text is used as the accessible label by Flutter's default semantics, which is acceptable for "Add Friend", "Accept", "Friends" — **borderline PASS**; however the "Pending" state button invites a tap to withdraw but the tooltip/semantics do not communicate this secondary action to screen-reader users → WCAG 4.1.2 (Name, Role, Value) → add `Tooltip` or explicit `Semantics(label: 'Pending — tap to withdraw request')` to the Pending state button
- `friend_list_tile.dart` → `_Avatar` widget (CachedNetworkImage rendered as a `CircleAvatar`) has no `Semantics` label and is not marked `excludeFromSemantics`; the friend's name is rendered as the `ListTile.title` so the avatar is purely decorative — WCAG 1.1.1 → mark the avatar `CachedNetworkImage` with `excludeFromSemantics: true` or wrap in `Semantics(excludeFromSemantics: true)`
- `friend_request_tile.dart` → same issue as `friend_list_tile.dart` for `_Avatar` — WCAG 1.1.1 → same fix
- `profile_screen.dart` → camera badge `Container` (the circular icon button over the avatar at lines 168-186) has no `Semantics` label and is not a proper `IconButton` with tooltip; screen readers will not identify it as a tap target to change the avatar → WCAG 4.1.2 → wrap in `Semantics(label: 'Change avatar', button: true)` or replace the `GestureDetector`/`Container` pair with a `Tooltip`-wrapped `InkWell`
- `profile_screen.dart` → `GestureDetector` wrapping the Friends stat item (tap to navigate to friends list, lines 228-231) has no `Semantics` label → WCAG 4.1.2 → wrap in `Semantics(label: 'Friends count, tap to view friends list', button: true)`
- `home_screen.dart` → avatar `GestureDetector` in the AppBar (lines 127-133) that taps to `/profile` has no `Semantics` label beyond what `AvatarWidget` provides ('Avatar of <firstName>'); the navigation affordance is not communicated → WCAG 4.1.2 → add `Semantics(label: 'View profile', button: true)` around the `GestureDetector`
- `home_screen.dart` → "Join with PIN" `OutlinedButton.icon` has label text 'Join with PIN' which passes WCAG 4.1.2 — **PASS**
- `avatar_widget.dart` → `AvatarWidget` wraps in `Semantics(label: 'Avatar of $displayName', button: false)` — **PASS** for image semantic labelling (WCAG 1.1.1)
- `session_card.dart` → `SessionCard` wraps in `Semantics(label: 'Session: ${session.title}', button: true)` — **PASS**
- `AppColors.hint` (0xFF767676) documented as 4.54:1 on white — marginally passes WCAG 2.2 AA 4.5:1 for normal text — **PASS** (single decimal rounding; no violation declared)
- `AppColors.accent` (0xFF894DEF purple) on white background: computed contrast ratio ≈ 4.6:1 — passes AA for normal-weight text — **PASS**
- No golden tests exist for the new screens at text scale 1.5 — overflow/clip behaviour at large type is **unverified** for `FriendsScreen`, `ProfileScreen`, `OtherUserProfileScreen`, `EditProfileSheet`

### Performance findings

- `profile_screen.dart` line 144 → `ListView` (non-builder) used for the profile body scroll; this is an unbounded `ListView` with no `itemCount`. While the number of children is small and fixed at build time (not dynamically generated from a collection), the CLAUDE.md rule states "No unbounded ListViews — always `ListView.builder` with `itemCount` or paginated." The same pattern appears in `other_user_profile_screen.dart` line 96. Both violations are low runtime risk because the child count is constant, but they are convention violations. Required fix: replace with `ListView.builder` with explicit `itemCount` or use a `SingleChildScrollView` + `Column`.
- `session_card.dart` → `_HostAvatar` uses `CachedNetworkImageProvider` (via `CircleAvatar(backgroundImage: ...)`) which is a valid caching call — **PASS**; no bare `Image.network` calls found in new files
- `avatar_widget.dart` → uses `CachedNetworkImage` — **PASS**
- `friend_list_tile.dart` → uses `CachedNetworkImage` — **PASS**
- `friend_request_tile.dart` → uses `CachedNetworkImage` — **PASS**
- `home_screen.dart` `ListView.builder` has explicit `itemCount: filtered.length` — **PASS**
- `friends_screen.dart` `ListView.builder` has explicit `itemCount: friends.length` — **PASS**
- All Firestore and Storage calls use `async/await` — **PASS**
- `AvatarDatasource.pickAndUpload` compresses before upload (step 3 precedes step 5) — **PASS**
- `HomeScreen` `publicSessionsStreamProvider` excludes current member sessions via a client-side `.where` filter — no N+1 reads; the stream returns a single collection snapshot — **PASS**
- `findSessionByPin` uses `.limit(1)` in `SessionDatasource.findSessionByPin` (line 213) — **PASS**

**ADR 0006 compliance findings:**
- `apps/mobile/lib/features/auth/presentation/providers/current_user_provider.dart` — **file does not exist** — deleted as required by ADR 0006 — **PASS**
- `userProfile` Future provider in `auth_state_notifier_provider.dart` — **no match found** — removed as required by ADR 0006 — **PASS**
- `cloud_firestore` imports outside `data/datasources/`: one **violation** found — `apps/mobile/lib/features/profile/presentation/providers/avatar_upload_provider.dart` imports `package:cloud_firestore/cloud_firestore.dart` and calls `FirebaseFirestore.instance` directly on line 22 to instantiate `ProfileDatasource` inside the provider body. ADR 0006 explicitly prohibits `cloud_firestore` imports in any presentation-layer provider. The author's comment (line 16) ironically asserts the file avoids the import. Required fix: extract `ProfileDatasource` instantiation into a separate repository provider in the `data/` layer and inject it; the presentation provider must not import or reference `FirebaseFirestore` directly.
- `FirebaseFirestore.instance` in presentation files: **1 violation** — same location as above
- No `print()` calls — **PASS**
- No relative imports — **PASS**
- All analytics events used are declared in `lib/core/analytics_events.dart` — **PASS**
- No PII (email, displayName, photoUrl, raw UID) found in log `extra` fields in new files — **PASS** (UID log in `avatar_repository_impl.dart` is deliberately absent as required; only `error` keys used)
- Storage path strings only in `lib/core/storage_paths.dart` — **PASS**
- Firestore path strings only in `lib/core/firestore_paths.dart` — **PASS**
- Domain layer files (friends and profile) have zero Flutter or Firebase imports — **PASS** (verified by grep)
- `firestore.indexes.json` — composite index `(pin ASC, visibility ASC, status ASC)` on `sessions` collection is **present** — **PASS**

### Verdict
- FAIL — `cloud_firestore` imported in `apps/mobile/lib/features/profile/presentation/providers/avatar_upload_provider.dart` (ADR 0006 violation, explicit FAIL criterion); domain coverage is 33.3% (below 80% target, explicit FAIL criterion); 7 new screens have no widget smoke tests; 5 new screens have no golden tests at either scale; Session History cards in `ProfileScreen` have a silent no-op `onTap` (unresolved routing gap flagged in ADR scope).
