# Audit report

| Field | Value |
|---|---|
| Agent | security-reviewer |
| Date | 2026-05-19 |
| Session ID | claude-sonnet-4-6 / 2026-05-19 |
| Triggered by | feat/sessions branch -- re-audit after 2026-05-18 BLOCKED verdict |
| Reviewed scope | firestore.rules, lib/features/sessions/, lib/features/my_sessions/, lib/shared/widgets/session_card.dart, lib/core/firestore_paths.dart, docs/decisions/0003-sessions-architecture.md |

---

## Security Reviewer section

### Critical (block merge)

- **SEC-001 UNCHANGED: sessions/{sessionId}/requests subcollection has no Firestore rules block** -- firestore.rules covers messages, ratings, and notes subcollections but contains no match /requests/{uid} block. Every read/write to the subcollection falls to implicit deny-all. Consequence: (a) joinRequestsProvider streams return permission-denied for all callers so the Requests tab is silently broken; (b) once any rule block is added without the correct host-reads-all or requester-reads-own constraint, all requesters displayName and photoUrl become visible to any authenticated KMUTT user who opens a collection listener. Required fix: add the match /sessions/{sessionId}/requests/{uid} block from ADR 0003 Consequences with host-or-own-document read, create validated against request.time and memberUids, update: if false, and delete for host or requester. Cover with emulator tests: non-host collection read denied; requester reads own document; host reads all; wrong UID create denied.
  - File: firestore.rules -- no requests subcollection block anywhere in the file.

- **SEC-002 UNCHANGED: No server-side PIN validation rule; joinWithPin accepts any PIN** -- join_request_datasource.dart lines 77-81 still claims Firestore rules verify request.resource.data.pin == session.pin. The rules file contains no such check. JoinRequestRepositoryImpl.joinWithPin lines 85-91 writes the raw PIN field and calls approveRequest directly after. Once SEC-001 is fixed without a PIN comparison predicate, any KMUTT user can join any private session with an arbitrary string. Required fix: add the PIN comparison predicate to the allow create rule and add an emulator integration test confirming wrong PIN returns permission-denied.
  - File: firestore.rules -- requests create rule missing PIN comparison predicate.
  - File: apps/mobile/lib/features/sessions/data/datasources/join_request_datasource.dart lines 77-81 -- misleading comment claiming server-side validation.

- **SEC-003 UNCHANGED: Non-host users subscribe to the full joinRequestsProvider collection stream** -- session_detail_screen.dart line 120 subscribes joinRequestsProvider(session.sessionId) unconditionally before the host check at line 123. At line 997 _JoinActionRow calls ref.watch(joinRequestsProvider) a second time for every non-host non-member. Both calls open a collection-level stream. Once SEC-001 is fixed, collection-level read must not be granted to non-hosts. Required fix: create myPendingRequestProvider(sessionId, uid) reading only sessions/{sessionId}/requests/{currentUserId}; use it in _JoinActionRow only; keep joinRequestsProvider gated behind if (isHost).
  - File: apps/mobile/lib/features/sessions/presentation/screens/session_detail_screen.dart lines 120 and 997.

### High (fix before release)

- **SEC-004 UNCHANGED: isViewerHost in MembersListScreen derived from racing async providers** -- members_list_screen.dart lines 23-26 derive isViewerHost from sessionAsync.valueOrNull?.hostUid and currentUser?.uid. If sessionAsync has not yet emitted, hostUid is null and isViewerHost is false for one or more frames. If currentUser resolves after sessionAsync, a non-host could briefly see isViewerHost == true. Recommended fix: compute isViewerHost only when both providers are in the data state and both values are non-null.
  - File: apps/mobile/lib/features/sessions/presentation/screens/members_list_screen.dart lines 23-26.

- **SEC-005 UNCHANGED: watchMembers maps full user documents including email and fullName** -- session_repository_impl.dart lines 191-205 map email, fullName, and bio into every UserEntity returned by watchMembers. The presentation layer renders only displayName, photoUrl, and faculty. The extra PII fields are held in Riverpod in-memory state. Recommended fix: project only uid, displayName, photoUrl, faculty, academicLevel, studentYear in _userFromMap, or introduce a MemberSummaryEntity excluding email and fullName.
  - File: apps/mobile/lib/features/sessions/data/repositories/session_repository_impl.dart lines 191-205.

- **SEC-006 UNCHANGED: ADR 0003 Status field still reads Proposed** -- docs/decisions/0003-sessions-architecture.md line 4 shows Status: Proposed. The Team Approval section records Eve as approver on 2026-05-18 but the Status field was not updated. CLAUDE.md planning workflow step 2 requires Status to be set to Accepted before implementation begins. Required fix: update Status: Proposed to Status: Accepted in the ADR header table.
  - File: docs/decisions/0003-sessions-architecture.md line 4.

### Medium (unchanged, carry forward)

- **SEC-007 UNCHANGED: PIN stored in plaintext in sessions/{sessionId}.pin** -- session_repository_impl.dart line 93 writes plainTextPin directly to the session document. The sessions read rule permits any KMUTT member who can read the session document to see the pin field. Recommended fix (follow-up ADR): hash the PIN before storage or move it to a host-only subcollection.
  - File: apps/mobile/lib/features/sessions/data/repositories/session_repository_impl.dart line 93.

- **SEC-008 UNCHANGED: joinWithPin non-atomic; dangling PIN doc on crash** -- join_request_repository_impl.dart lines 91-94 call submitPinRequest and approveRequest as two unguarded sequential operations. A crash between them leaves a request document containing the raw pin field. Recommended fix: wrap both operations in a single WriteBatch or Firestore transaction.
  - File: apps/mobile/lib/features/sessions/data/repositories/join_request_repository_impl.dart lines 91-94.

- **SEC-009 UNCHANGED: Join buttons rendered when currentUserProvider has not yet resolved** -- session_detail_screen.dart lines 957-959 pass me: null to _NotJoinedActions which renders the join buttons. The write guard at line 1040 prevents submission but the button is tappable. Recommended fix: render a sign-in prompt when me == null.
  - File: apps/mobile/lib/features/sessions/presentation/screens/session_detail_screen.dart lines 957-959.

- **SEC-010 UNCHANGED: Leave action passes empty-string uid when me is null** -- member_session_detail_screen.dart line 228 passes me?.uid ?? empty-string to _showLeaveDialog. Triggers a no-op arrayRemove Firestore write. Recommended fix: hide the three-dot leave menu when me == null.
  - File: apps/mobile/lib/features/my_sessions/presentation/screens/member_session_detail_screen.dart line 228.

### Informational

- No print() calls found in any audited file. Compliant.
- No hardcoded API keys, Firebase config values, or secrets found. Compliant.
- No bare Image.network usages. All remote images use CachedNetworkImageProvider. Compliant.
- All Firestore path strings centralised in FirestorePaths. No path injection vector. Compliant.
- SessionModel and JoinRequestModel use Freezed + json_serializable. No hand-rolled deserialization. Compliant.
- All appLogger.extra maps contain only sessionId (opaque), error codes, aggregate counts. No PII in logs. Compliant.
- isKmuttUser() enforces both @mail.kmutt.ac.th and @kmutt.ac.th with email_verified == true. Correct.
- Sessions create rule enforces createdAt == request.time and updatedAt == request.time. Correct.
- Sessions update rule uses affectedKeys().hasOnly(...). Correct.
- users/{uid} isolated data: create and update both require request.auth.uid == uid. Correct.
- approveRequest in join_request_datasource.dart lines 113-121 uses a WriteBatch atomically deleting the request doc and adding UID to memberUids. Correct for the approve path.
- appLogger.debug(AnalyticsEvents.sessionDeleted) and similar log the event name string but do not fire Firebase Analytics. Functional gap, not a security risk.

---

### Prior Findings Status

| ID | Severity | Status | Notes |
|----|----------|--------|-------|
| SEC-001 | Critical | UNCHANGED | firestore.rules still has no match /requests/{uid} block. |
| SEC-002 | Critical | UNCHANGED | No PIN comparison predicate in any rule. Datasource comment line 79 still falsely claims server-side validation. |
| SEC-003 | Critical | UNCHANGED | session_detail_screen.dart lines 120 and 997 still call ref.watch(joinRequestsProvider) unconditionally. No myPendingRequestProvider introduced. |
| SEC-004 | High | UNCHANGED | members_list_screen.dart lines 23-26 still derive isViewerHost from two independently resolving async providers. |
| SEC-005 | High | UNCHANGED | session_repository_impl.dart _userFromMap lines 191-205 still maps email, fullName, bio into every UserEntity. |
| SEC-006 | High | UNCHANGED | docs/decisions/0003-sessions-architecture.md line 4 still reads Status: Proposed. |
| SEC-007 | Medium | UNCHANGED | session_repository_impl.dart line 93 still writes plainTextPin in plaintext. |
| SEC-008 | Medium | UNCHANGED | join_request_repository_impl.dart lines 91-94 still two unguarded sequential operations. |
| SEC-009 | Medium | UNCHANGED | session_detail_screen.dart lines 957-959 still render join buttons when me is null. |
| SEC-010 | Medium | UNCHANGED | member_session_detail_screen.dart line 228 still passes me?.uid ?? empty-string. |

### New Findings

None. No new print() calls, hardcoded secrets, bare Image.network usages, new unprotected Firestore paths, or new mutations without caller-identity checks were found in the current state of the branch.

---

### Checklist

| Category | Status | Notes |
|----------|--------|-------|
| Firestore rules -- auth gate | PASS | All session rules require isKmuttUser() enforcing request.auth != null and email_verified |
| Firestore rules -- host RBAC | PARTIAL | Sessions update/delete use isHost(sessionId) correctly; requests subcollection has no rule block |
| Firestore rules -- PIN isolation | FAIL | No rule validates PIN on write; pin field readable by any KMUTT member who can read the session |
| Firestore rules -- requests subcollection | FAIL | Block entirely absent from firestore.rules |
| Firestore rules -- field-level diff | PASS | Sessions update and users update both use affectedKeys().hasOnly(...) |
| Firestore rules -- request.time timestamps | PASS | createdAt == request.time and updatedAt == request.time enforced on session and user create/update |
| Firestore rules -- KMUTT domain | PASS | isKmuttUser() enforces @mail.kmutt.ac.th and @kmutt.ac.th with email_verified == true |
| PIN not in logs | PASS | No log statement emits the PIN value in any audited file |
| PIN not exposed to non-hosts (client) | PASS | fetchPin in repository checks hostUid != callerUid before datasource call |
| PIN not exposed to non-hosts (server) | FAIL | No requests rule block; pin field on session document readable by any KMUTT member who can read the session |
| No path injection | PASS | All Firestore paths via FirestorePaths constants; no user input interpolated into paths |
| Auth boundary client-side | PASS | All mutating operations check callerUid == hostUid in repository layer before Firestore write |
| No PII in logs | PASS | All appLogger.extra maps contain only sessionId, error codes, aggregate counts |
| No hardcoded secrets | PASS | No API keys or Firebase config values found in source |
| Images via CachedNetworkImageProvider | PASS | All remote images use CachedNetworkImageProvider; no bare Image.network |
| No print() calls | PASS | Zero print() calls in any audited file |
| Frozen models -- no hand-rolled JSON | PASS | SessionModel and JoinRequestModel use Freezed + json_serializable |
| Isolated data -- users own documents | PASS | users/{uid} create and update both require request.auth.uid == uid |
| Isolated data -- session member streams | PARTIAL | Public sessions scoped correctly; private session reads blocked by rules; requests subcollection unscoped |
| ADR 0003 Status field | FAIL | Status still reads Proposed despite Team Approval being recorded |
| Security path emulator tests | FAIL | No emulator integration tests for requests subcollection access control or PIN validation exist |

---

### JSON report

```json
{
  "agent": "security-reviewer",
  "date": "2026-05-19",
  "findings": [
    {"id": "SEC-001", "severity": "critical", "status": "UNCHANGED", "title": "sessions/requests subcollection has no Firestore rules block", "file": "firestore.rules", "line": null},
    {"id": "SEC-002", "severity": "critical", "status": "UNCHANGED", "title": "No server-side PIN validation rule; joinWithPin accepts any PIN once rules block is added", "file": "firestore.rules", "line": null},
    {"id": "SEC-003", "severity": "critical", "status": "UNCHANGED", "title": "Non-host users subscribe to full joinRequestsProvider collection stream", "file": "apps/mobile/lib/features/sessions/presentation/screens/session_detail_screen.dart", "line": 120},
    {"id": "SEC-004", "severity": "high", "status": "UNCHANGED", "title": "isViewerHost derived from racing async providers may briefly expose faculty PII", "file": "apps/mobile/lib/features/sessions/presentation/screens/members_list_screen.dart", "line": 23},
    {"id": "SEC-005", "severity": "high", "status": "UNCHANGED", "title": "watchMembers reads full user documents including email and fullName PII", "file": "apps/mobile/lib/features/sessions/data/repositories/session_repository_impl.dart", "line": 191},
    {"id": "SEC-006", "severity": "high", "status": "UNCHANGED", "title": "ADR 0003 Status field not updated to Accepted", "file": "docs/decisions/0003-sessions-architecture.md", "line": 4},
    {"id": "SEC-007", "severity": "medium", "status": "UNCHANGED", "title": "PIN stored in plaintext in sessions/{sessionId}.pin", "file": "apps/mobile/lib/features/sessions/data/repositories/session_repository_impl.dart", "line": 93},
    {"id": "SEC-008", "severity": "medium", "status": "UNCHANGED", "title": "joinWithPin non-atomic; dangling PIN document on crash between submit and approve", "file": "apps/mobile/lib/features/sessions/data/repositories/join_request_repository_impl.dart", "line": 91},
    {"id": "SEC-009", "severity": "medium", "status": "UNCHANGED", "title": "Join button rendered before currentUserProvider resolves", "file": "apps/mobile/lib/features/sessions/presentation/screens/session_detail_screen.dart", "line": 957},
    {"id": "SEC-010", "severity": "medium", "status": "UNCHANGED", "title": "Leave action passes empty-string uid when me is null", "file": "apps/mobile/lib/features/my_sessions/presentation/screens/member_session_detail_screen.dart", "line": 228}
  ],
  "severity_max": "critical",
  "verdict": "BLOCKED",
  "summary": "All ten prior findings remain UNCHANGED. No fixes were applied between the 2026-05-18 and 2026-05-19 audits. Three critical findings continue to block merge: (1) sessions/requests subcollection has no Firestore rules block; (2) no server-side PIN comparison rule exists; (3) non-host users open a collection-level stream against the requests subcollection. Each critical finding requires a corresponding emulator integration test before re-review."
}
```

### Verdict

- BLOCKED -- All three critical findings from the 2026-05-18 audit are UNCHANGED: the requests subcollection has no Firestore rules block, no PIN comparison predicate exists in any rule, and non-host users still subscribe to the full join-requests collection stream. No security fixes were applied between the two audits. The branch must not be merged until SEC-001, SEC-002, and SEC-003 are resolved and covered by emulator integration tests.
