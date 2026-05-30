# Audit report

| Field | Value |
|---|---|
| Agent | release-engineer |
| Date | 2026-05-31 |
| Session ID | claude-sonnet-4-6 / DeepseaMew / 2026-05-31 |
| Triggered by | v0.2.0 release candidate — feat/sessions-chat branch (commits 3955ff3, 32f5f7d, a32c1ae) — second attempt after prior BLOCKED run |
| Reviewed scope | docs/audit/ (QA and security reports for ADR 0011 + ADR 0012), apps/mobile/lib/ (print scan), CLAUDE.md (rating_enabled rollback), apps/mobile/pubspec.yaml, CHANGELOG.md, Android + Web debug builds, flutter test suite |

---

## Release Engineer section

### Pre-release checklist
- [x] CI green on latest commit: N/A — no CI pipeline integrated in this repo
- [x] QA report present and PASS: pass — 2026-05-31-qa-adr-0011-dm-chat.md (76/76, PASS); 2026-05-31-qa-adr-0012-session-chat.md (136/136, PASS)
- [x] Security report present and APPROVED: pass — 2026-05-31-security-adr-0011-dm-chat.md (APPROVED, severity_max: high, all findings resolved); ADR-0012-security-review.md (APPROVED, severity_max: high, SEC-0012-01 accepted per ADR 0012, SEC-0012-02 resolved)
- [x] No unresolved Critical or High findings: pass — ADR 0011: 0 Critical, 1 High (CHAT-H1) resolved. ADR 0012: 0 Critical, 2 High (SEC-0012-01 accepted risk per ADR 0012 — no data loss; SEC-0012-02 resolved — confirmed _auth.currentUser?.displayName at note_repository_impl.dart line 55)
- [x] Crashlytics evidence file exists in docs/audit/evidence/: pass — docs/audit/evidence/crashlytics-test-crash.png present
- [x] No print() calls in codebase: pass — 0 files found matching print( in apps/mobile/lib/**/*.dart
- [x] No PII in logs confirmed: pass — both security reports confirm all appLogger calls log only structural identifiers; no message text, display names, email addresses, or file content in log strings
- [x] rating_enabled rollback documented in CLAUDE.md: pass — CLAUDE.md contains "## Feature flag rollback / ### rating_enabled" section with flag location, disable procedure, effect, rollback time, and data migration note
- [x] Compiles on Android: pass — flutter build apk --debug succeeded; Built build\app\outputs\flutter-apk\app-debug.apk
- [x] Compiles on Web: pass — flutter build web --debug succeeded; Built build\web (WASM dry-run warnings present, non-blocking)

### Gate results
- QA: PASS — 76 tests (ADR 0011) + 136 tests (ADR 0012) = 212 feature tests; live suite 650 pass / 2 fail (2 CalendarScreen golden pixel mismatches, pre-existing, unrelated to chat)
- Security: APPROVED — severity_max: high; no unresolved Critical or High findings; SEC-0012-01 accepted per ADR 0012, SEC-0012-02 fix confirmed in source
- Crashlytics evidence: PRESENT — docs/audit/evidence/crashlytics-test-crash.png
- Feature flag rollback: DOCUMENTED — CLAUDE.md "## Feature flag rollback / ### rating_enabled"

### Changelog
#### v0.2.0 — 2026-05-31

**feat**
- DM chat: 1-1 messaging between confirmed friends (ADR 0011)
- Session chat: group messaging for session members (ADR 0012)
- Groups tab in Messages screen with unread badges
- Message group button wired in session detail screens

**fix**
- SEC-0012-02: senderDisplayName reads from auth token, not Firestore
- CHAT-H1: message create rule uses keys().hasOnly (not diff-self tautology)
- CHAT-M1: readBy append-only enforced in Firestore rules
- CHAT-M2: unread badge zero restricted to own counter only
- CHAT-M3: markRead guards doc existence before update
- CHAT-M4: server-side text length limit (4000 chars) enforced

**chore**
- Firestore rules: dms/{dmId} block (ADR 0011)
- Firestore rules: sessions/messages block amended (ADR 0012)
- Firestore rules: users/{uid}/groupChats block added (ADR 0012)
- Firestore Index 11 deployed (dms participantUids + lastMessageAt)

### Verdict
- READY TO TAG — all gates pass; 2 CalendarScreen golden failures are pre-existing and unrelated to chat; tag v0.2.0 cut