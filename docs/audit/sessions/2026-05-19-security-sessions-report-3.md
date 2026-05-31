# Audit report

| Field | Value |
|---|---|
| Agent | security-reviewer |
| Date | 2026-05-19 |
| Session ID | re-audit-3 |
| Triggered by | Re-audit of feat/sessions after report-2 residual findings |
| Reviewed scope | firestore.rules, join_request_datasource.dart, join_request_repository_impl.dart, session_detail_screen.dart, member_session_detail_screen.dart, session_repository_impl.dart |

---

## Security Reviewer section

# Security Audit - Sessions Feature (Re-audit 3)
**Date:** 2026-05-19
**Branch:** feat/sessions
**Auditor:** security-reviewer
**Prior audit:** 2026-05-19-security-sessions-report-2.md
**ADR:** 0003-sessions-architecture

## Verdict: APPROVED
SEC-002 (the residual High from report-2) is now FIXED. No new critical or high findings were introduced. Four medium findings carry forward.

## Finding Status

| ID | Prior Severity | Status | Evidence |
|----|---------------|--------|----------|
| SEC-002 | High (PARTIAL) | FIXED | firestore.rules lines 140-141: allow create rule now contains the conditional `(resource.data.visibility == 'public' \|\| request.resource.data.pin == get(...).data.pin)`. Private sessions require exact PIN match against the stored session document; wrong PIN returns permission-denied. Public sessions correctly exempt - no PIN required. join_request_datasource.dart lines 87-91: comment now accurately states server-side PIN validation and InvalidPinException on permission-denied. Misleading claim from report-2 is resolved. |
| SEC-007 | Medium | UNCHANGED | session_repository_impl.dart line 93: `data['pin'] = plainTextPin` still writes raw PIN string to sessions/{sessionId}. Carry-forward. |
| SEC-008 | Medium | UNCHANGED | join_request_repository_impl.dart lines 96-99: submitPinRequest and approveRequest remain two sequential unguarded calls. Crash between them leaves dangling request document with PIN field exposed. Carry-forward. |
| SEC-009 | Medium | PARTIAL | session_detail_screen.dart lines 981-982: `if (me == null)` falls through to `_NotJoinedActions(session: session, me: me)` rendering actionable join buttons when me is null. Both _requestJoin (line 1062) and _joinWithPassword (line 1096) guard with `if (me == null) return` so no Firestore write occurs, but a tappable button is rendered with no sign-in prompt. Unchanged characterisation. |
| SEC-010 | Medium | UNCHANGED | member_session_detail_screen.dart line 228: `_showLeaveDialog(me?.uid ?? '')` passes empty string when me is null. PopupMenuButton rendered whenever `widget.isCompleted == false` with no null guard on me. Carry-forward. |

## New Findings

None. No new `print()` calls, hardcoded secrets, bare `Image.network` usages, new unprotected Firestore path subscriptions, or new mutations without caller-identity checks were found in the six files under audit.

Informational: `_showRatingSheet` at member_session_detail_screen.dart lines 182-186 passes `me?.uid ?? ''` as currentUserId to the rating bottom sheet. The Submit Rating button (line 960) logs but does not write to Firestore in the current implementation. No security risk at this time. When rating Firestore writes are wired in, a null guard on me will be required before `_showRatingSheet` is called.

## Open Items

**SEC-007** (Medium, carry-forward) - session_repository_impl.dart line 93. PIN stored in plaintext. Required fix before public release: store a hashed PIN (SHA-256 hex) and compare the hash in the Firestore rule. An ADR amendment is required.

**SEC-008** (Medium, carry-forward) - join_request_repository_impl.dart lines 96-99. Non-atomic joinWithPin. Required fix: wrap submitPinRequest and approveRequest in a single WriteBatch or Cloud Function transaction.

**SEC-009** (Medium, partial) - session_detail_screen.dart line 981. Join buttons shown before auth resolves. Recommended fix: when me is null, render a sign-in prompt instead of `_NotJoinedActions(me: null)`.

**SEC-010** (Medium, carry-forward) - member_session_detail_screen.dart line 228. Leave action with empty uid. Recommended fix: add `if (me == null) return;` inside onSelected before calling `_showLeaveDialog`, or hide the PopupMenuButton when me is null.

## Checklist

| Category | Status | Notes |
|----------|--------|-------|
| Firestore rules - auth gate | PASS | All session rules require isKmuttUser() enforcing request.auth != null and email_verified |
| Firestore rules - host RBAC | PASS | Sessions update/delete use isHost(sessionId); requests subcollection enforces host for collection read and approve/decline |
| Firestore rules - PIN server-side validation | PASS | lines 140-141: PIN comparison predicate present; wrong PIN returns permission-denied for private sessions; public sessions correctly exempt |
| Firestore rules - requests subcollection | PASS | match /requests/uid block present at lines 132-147 |
| Firestore rules - field-level diff | PASS | Sessions update and users update both use affectedKeys().hasOnly(...) |
| Firestore rules - request.time timestamps | PASS | requestedAt == request.time on requests create; createdAt/updatedAt == request.time on session and user |
| Firestore rules - KMUTT domain | PASS | isKmuttUser() enforces both @mail.kmutt.ac.th and @kmutt.ac.th with email_verified == true |
| Non-host collection stream subscription | PASS | joinRequestsProvider only called inside _HostRequestsSection gated on isHost == true (line 360) |
| Single-doc pending check for non-hosts | PASS | myPendingRequestProvider used in _JoinActionRow after me != null branch |
| isViewerHost race condition | PASS | Confirmed fixed in prior audit; unchanged |
| PII in _userFromMap | PASS | fullName and email hard-coded to empty string; bio not mapped |
| ADR 0003 Status field | PASS | Status: Accepted on line 4 |
| PIN comment accuracy in datasource | PASS | join_request_datasource.dart lines 87-91 comment now accurately describes server-side validation and InvalidPinException |
| PIN not in logs | PASS | No log statement emits the PIN value |
| PIN server-side isolation | PARTIAL | SEC-002 FIXED; SEC-007 (plaintext storage) still open |
| No path injection | PASS | All Firestore paths via FirestorePaths constants |
| Auth boundary client-side | PASS | All mutating operations check callerUid == hostUid in repository layer before Firestore write |
| No PII in logs | PASS | All appLogger.extra maps contain only sessionId, error codes, aggregate counts |
| No hardcoded secrets | PASS | No API keys or Firebase config values found in source |
| Images via CachedNetworkImageProvider | PASS | All remote images use CachedNetworkImageProvider; no bare Image.network |
| No print() calls | PASS | Zero print() calls in any audited file |
| Frozen models - no hand-rolled JSON | PASS | SessionModel and JoinRequestModel use Freezed + json_serializable |
| Isolated data - users own documents | PASS | users/uid create and update both require request.auth.uid == uid |
| Isolated data - requests subcollection | PASS | Read scoped to host or own document; create scoped to own UID |
| Security path emulator tests | FAIL | No emulator integration tests for PIN validation (wrong PIN to permission-denied) or requests subcollection access control exist. Required before next public release. |

### JSON report

```json
{
  "agent": "security-reviewer",
  "date": "2026-05-19",
  "findings": [
    {
      "id": "SEC-002",
      "severity": "high",
      "status": "FIXED",
      "title": "PIN comparison predicate added to requests create rule; wrong PIN now rejected server-side",
      "file": "firestore.rules",
      "line": 140
    },
    {
      "id": "SEC-007",
      "severity": "medium",
      "status": "UNCHANGED",
      "title": "PIN stored in plaintext in sessions/sessionId.pin",
      "file": "apps/mobile/lib/features/sessions/data/repositories/session_repository_impl.dart",
      "line": 93
    },
    {
      "id": "SEC-008",
      "severity": "medium",
      "status": "UNCHANGED",
      "title": "joinWithPin non-atomic; dangling PIN document on crash between submitPinRequest and approveRequest",
      "file": "apps/mobile/lib/features/sessions/data/repositories/join_request_repository_impl.dart",
      "line": 96
    },
    {
      "id": "SEC-009",
      "severity": "medium",
      "status": "PARTIAL",
      "title": "Join buttons rendered when me is null; write blocked but tappable UI is misleading",
      "file": "apps/mobile/lib/features/sessions/presentation/screens/session_detail_screen.dart",
      "line": 981
    },
    {
      "id": "SEC-010",
      "severity": "medium",
      "status": "UNCHANGED",
      "title": "Leave action passes empty-string uid when me is null",
      "file": "apps/mobile/lib/features/my_sessions/presentation/screens/member_session_detail_screen.dart",
      "line": 228
    }
  ],
  "severity_max": "medium",
  "verdict": "APPROVED",
  "summary": "SEC-002 is now FIXED: the Firestore requests create rule at lines 140-141 contains the required PIN comparison predicate, correctly scoped to private sessions only, and the misleading comment in join_request_datasource.dart has been updated. No new critical or high findings were introduced. Four medium findings remain open: SEC-007 (plaintext PIN), SEC-008 (non-atomic joinWithPin), SEC-009 (join buttons before auth resolves, partial), SEC-010 (leave action with empty uid). None blocks merge. All four should be resolved before next public release."
}
```

### Verdict

APPROVED - SEC-002 (the residual High finding from report-2) is FIXED: the PIN comparison predicate is present in the Firestore rules and correctly scoped to private sessions only. No new critical or high findings were found. Four medium findings carry forward (SEC-007, SEC-008, SEC-009 partial, SEC-010) and must be resolved before the next public release.
