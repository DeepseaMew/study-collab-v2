# Audit report

| Field | Value |
|---|---|
| Agent | release-engineer |
| Date | 2026-05-22 |
| Session ID | claude-sonnet-4-6 / NichapaJongKmutt / 2026-05-22 |
| Triggered by | feat/calendar — CI fix for Integration Tests (Android) job |
| Reviewed scope | .github/workflows/ci.yml, feat/calendar branch (commits 43a5860–0ccf378), docs/audit/ |

---

## Release Engineer section

### Pre-release checklist
- [ ] CI green on latest commit: fail — `Integration Tests (Android)` job is failing; this report documents the CI fix applied in this session; green status must be confirmed after the fix lands
- [x] QA report present and PASS: pass — `docs/audit/2026-05-22-qa-feat-calendar.md`, verdict PASS, 102 tests
- [ ] Security report present and APPROVED: fail — no security report exists for feat/calendar
- [ ] No unresolved Critical or High findings: blocked — security review has not been conducted for feat/calendar; cannot confirm absence of Critical or High findings
- [x] Crashlytics evidence file exists in docs/audit/evidence/: pass — `docs/audit/evidence/crashlytics-test-crash.png` present
- [x] No print() calls in codebase: pass — 0 found across apps/mobile/lib
- [x] No PII in logs confirmed: pass — all logging routed through lib/core/logger.dart; no PII found in log call sites
- [ ] rating_enabled rollback documented in CLAUDE.md: missing — no `rating_enabled` feature flag rollback procedure exists in CLAUDE.md
- [ ] Compiles on Android: fail — CI Android job failing; local compilation not verified in this session
- [ ] Compiles on Web: fail — not verified in this session

### Gate results
- QA: PASS — >80% domain coverage, 102 tests, 3/3 screens with widget tests
- Security: BLOCKED — no security report for feat/calendar; severity_max unknown
- Crashlytics evidence: PRESENT — `docs/audit/evidence/crashlytics-test-crash.png`
- Feature flag rollback: MISSING — `rating_enabled` rollback not documented in CLAUDE.md

### Changelog
#### v0.1.0 — 2026-05-22

**feat**
- Calendar: monthly/weekly view of historical and upcoming sessions (ADR 0007)
- Calendar: day-detail screen with session list sorted by start time
- Calendar: overflow pill for days with more than 3 sessions
- Calendar: GCal sync settings screen (feature-flagged off in production)

**fix**
- CI: add `--verbose` flag to both `flutter test` integration test commands so exception messages appear in CI logs
- CI: add ADB emulator reachability check for Auth (port 9099) and Firestore (port 8080) emulators before running tests
- CI: add Firebase emulator JAR cache step to reduce download time per run
- CI: add `dart format` step for injected `firebase_options.dart` in the Android integration test job, mirroring the analyze-and-test job

**chore**
- none

### Verdict
- BLOCKED — security review for feat/calendar is missing; `rating_enabled` rollback is not documented in CLAUDE.md; CI green status must be re-confirmed after this fix lands; do not cut a release tag until all three blockers are resolved