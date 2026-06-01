# Audit report

| Field | Value |
|---|---|
| Agent | release-engineer |
| Date | 2026-06-01 |
| Session ID | claude-sonnet-4-6 / DeepseaMew / 2026-06-01 |
| Triggered by | v1.0.0+1 public release candidate — develop branch (commits a078363, b627903) |
| Reviewed scope | docs/audit/ (all QA and security reports), apps/mobile/lib/ (print scan, PII scan), CLAUDE.md (rating_enabled rollback), apps/mobile/pubspec.yaml, CHANGELOG.md, Android + Web debug builds |

---

## Release Engineer section

### Pre-release checklist
- [ ] CI green on latest commit: fail — gh CLI not installed; CI status on origin/develop (commit a078363) cannot be verified programmatically; must be confirmed manually in GitHub Actions
- [ ] QA report present and PASS: fail — no QA report exists for commits a078363 (calender offline) or b627903 (fix andriod run); the only calendar QA report (docs/audit/calendar/2026-05-22-qa-feat-calendar.md) covers the original calendar feature, not the offline caching layer introduced in a078363
- [ ] Security report present and APPROVED: fail — no security report exists for the calendar feature at any point; docs/audit/calendar/ contains only a QA report; no security report covers commits a078363 or b627903
- [ ] No unresolved Critical or High findings: blocked — security review has never been conducted for the calendar feature or the offline-first caching layer; cannot confirm absence of Critical or High findings
- [x] Crashlytics evidence file exists in docs/audit/evidence/: pass — docs/audit/evidence/crashlytics-test-crash.png present
- [x] No print() calls in codebase: pass — 0 files found matching print( in apps/mobile/lib/**/*.dart
- [x] No PII in logs confirmed: pass — grep of appLogger calls found only structural messages (no email addresses, display names, or message content interpolated)
- [ ] rating_enabled rollback documented in CLAUDE.md: fail — CLAUDE.md contains a rating_enabled section but documents a code-change + redeploy procedure (~5 min), not the required Firebase Remote Config no-deploy rollback (~1 min); the required procedure (Firebase Console → Remote Config → set rating_enabled = false → Publish Changes) is absent
- [x] Compiles on Android: pass — flutter build apk --debug succeeded; Built build\app\outputs\flutter-apk\app-debug.apk
- [x] Compiles on Web: pass — flutter build web --debug succeeded; Built build\web (WASM dry-run warnings present, non-blocking)

### Gate results
- QA: FAIL — no QA report for offline-first calendar commits (a078363, b627903); prior calendar QA (102 tests, PASS) does not cover the offline caching layer
- Security: BLOCKED — no security report for calendar feature; severity_max unknown
- Crashlytics evidence: PRESENT — docs/audit/evidence/crashlytics-test-crash.png
- Feature flag rollback: MISSING — rating_enabled rollback in CLAUDE.md describes code-change + redeploy, not Firebase Remote Config no-deploy procedure

### Changelog
#### v1.0.0 — 2026-06-01

**feat**
- Calendar: offline-first caching layer; sessions load from local cache when device has no connectivity (commit a078363)
- Calendar: offline banner widget displayed when connectivity is absent
- Calendar: connectivity provider added (lib/core/connectivity/connectivity_provider.dart)
- Auth: KMUTT email domain gate (@mail.kmutt.ac.th, @kmutt.ac.th) with email verification
- Sessions: create, edit, delete, end sessions; public and private (PIN/invite) visibility
- Friends: send, accept, decline friend requests; bidirectional friendship
- Chat: DM between friends (ADR 0011); session group chat for members (ADR 0012)
- Search: filter sessions by name, hashtag, academic level, student year
- Rating: thumbs-up rating between session members after session ends; profile score
- Note-Sharing: images, documents, archives up to 10 MB per file, 50 per session
- Calendar: monthly/weekly view of historical and upcoming sessions (ADR 0007)
- Notification settings

**fix**
- Android: build configuration fix (commit b627903)
- Minor UI fixes (commits da2f69d, 4d5ee10)
- Removed debug test crash button (commit f9026bf)

**chore**
- Version bumped to 1.0.0+1

### Verdict
- BLOCKED — three gates fail: (1) no QA report for offline-first calendar commits a078363 and b627903; (2) no security report for the calendar feature at any revision; (3) rating_enabled rollback in CLAUDE.md does not document the required Firebase Remote Config no-deploy procedure. Do not cut tag v1.0.0+1 until all three blockers are resolved.