# Audit report

| Field | Value |
|---|---|
| Agent | security-reviewer |
| Date | 2026-05-18 |
| Session ID | claude-sonnet-4-6 / 2026-05-18 |
| Triggered by | feat/sessions branch -- sessions feature implementation |
| Reviewed scope | lib/features/sessions/, lib/features/my_sessions/, shared/widgets/session_card.dart, core/firestore_paths.dart, core/errors/app_exception.dart, firestore.rules, ADR 0003 |

---

## Security Reviewer section

### Critical (block merge)

- **SEC-001: sessions/{sessionId}/requests subcollection has no Firestore rules block** -- firestore.rules covers sessions/{sessionId} and all other subcollections (messages, ratings, notes) but contains no match /requests/{uid} block. Every read/write to sessions/{sessionId}/requests/{uid} falls through to deny-all by accident of omission, not by explicit intent. ADR 0003 explicitly specifies this block. Once a rules block is added without the correct requester-reads-own constraint, all requesters display names and photo URLs become visible to any KMUTT member via the joinRequestsProvider stream. Required fix: add the match /requests/{uid} block from ADR 0003 with host-only collection read and requester-reads-own-document semantics. Cover with an emulator integration test: non-host collection read denied, requester reads own document only, host reads all documents.
  - File: firestore.rules -- no requests subcollection block exists.

- **SEC-002: joinWithPin bypasses PIN validation -- the claimed server-side check does not exist** -- join_request_repository_impl.dart line 89 writes the raw PIN into the Firestore request document. The datasource comment at join_request_datasource.dart line 79 claims Firestore rules verify request.resource.data.pin == session.pin but the rules file contains no such check. The permission-denied that submitPinRequest interprets as a wrong PIN is thrown because the requests subcollection has no rules block at all. Once the rules block is added without a PIN comparison predicate, any KMUTT user can join any private session by submitting any string. Required fix: (1) add PIN comparison to the allow create rule: request.resource.data.pin == get(...sessions/sessionId).data.pin; (2) add an emulator integration test proving wrong PIN returns permission-denied and correct PIN permits the write.
  - File: apps/mobile/lib/features/sessions/data/repositories/join_request_repository_impl.dart lines 85-91.
  - File: apps/mobile/lib/features/sessions/data/datasources/join_request_datasource.dart lines 79-82 (misleading comment).

- **SEC-003: Non-host users subscribe to the full joinRequestsProvider collection stream to check their pending status** -- session_detail_screen.dart line 121 subscribes to joinRequestsProvider(session.sessionId) for every user who opens the screen, then filters client-side at line 999 to find their own request. This opens a collection-level stream against sessions/{sessionId}/requests. With no rules block this returns permission-denied accidentally. When a rules block is added granting anything broader than single-document read to a requester, all requesters PII becomes visible. Required fix: create a myPendingRequestProvider(sessionId, uid) that reads only sessions/{sessionId}/requests/{currentUserId}; use it in _JoinActionRow only. Retain joinRequestsProvider for host-gated widgets only.
  - File: apps/mobile/lib/features/sessions/presentation/screens/session_detail_screen.dart lines 120-121 and 997-999.

### High (fix before release)

- **SEC-004: isViewerHost in MembersListScreen derived from racing async providers may briefly expose faculty PII** -- members_list_screen.dart lines 24-26 compute isViewerHost by comparing currentUser?.uid to hostUid from the session stream. If the two providers resolve in different frames isViewerHost may be false for one frame, briefly showing faculty info to a non-host. Recommended fix: derive isViewerHost only after both providers have emitted non-loading states, or remove the showFaculty toggle entirely.
  - File: apps/mobile/lib/features/sessions/presentation/screens/members_list_screen.dart lines 24-26 and 88.

- **SEC-005: watchMembers reads full user documents including email and fullName PII unnecessarily** -- session_repository_impl.dart lines 191-205 map all user document fields including email, fullName, and bio into UserEntity and propagate them to the presentation layer. Only displayName and photoUrl are rendered in member tiles. Recommended fix: project only uid, displayName, photoUrl, faculty, academicLevel, studentYear in _userFromMap, or introduce a MemberSummaryEntity excluding email and fullName.
  - File: apps/mobile/lib/features/sessions/data/repositories/session_repository_impl.dart lines 191-205.

- **SEC-006: ADR 0003 Status field not updated to Accepted** -- docs/decisions/0003-sessions-architecture.md line 4 shows Status: Proposed. CLAUDE.md planning workflow step 2 requires Status to be set to Accepted before implementation begins. The Team Approval section is filled by Eve on 2026-05-18 but the Status field was not updated. Required fix: update Status to Accepted.
  - File: docs/decisions/0003-sessions-architecture.md line 4.

### Medium (fix in follow-up)

- **SEC-007: PIN stored in plaintext in sessions/{sessionId}.pin** -- session_repository_impl.dart line 93 writes plainTextPin directly to the Firestore session document. Any KMUTT user who can read the session document can read the PIN field. Recommended fix in a follow-up ADR: hash the PIN before storage (e.g. SHA-256 with a per-session salt) or move it to a host-only subcollection path.
  - File: apps/mobile/lib/features/sessions/data/repositories/session_repository_impl.dart line 93.

- **SEC-008: joinWithPin is non-atomic; dangling PIN document on crash between steps** -- join_request_repository_impl.dart lines 91-94 call submitPinRequest then approveRequest as two separate Firestore operations. A crash between them leaves a dangling request document containing the raw PIN field. Recommended fix: wrap both calls in a single WriteBatch or Firestore transaction.
  - File: apps/mobile/lib/features/sessions/data/repositories/join_request_repository_impl.dart lines 91-94.

- **SEC-009: Join button rendered for unauthenticated users before currentUserProvider resolves** -- session_detail_screen.dart lines 957-959 pass me as null to _NotJoinedActions which renders the join button. The guard at line 1040 prevents the Firestore write but the button is briefly visible and tappable. Recommended fix: render a sign-in prompt when me is null.
  - File: apps/mobile/lib/features/sessions/presentation/screens/session_detail_screen.dart lines 957-959.

- **SEC-010: Leave action passes empty string uid when me is null** -- member_session_detail_screen.dart line 228 passes me?.uid ?? empty-string to _showLeaveDialog. Recommended fix: hide the 3-dot leave menu entirely when me is null.
  - File: apps/mobile/lib/features/my_sessions/presentation/screens/member_session_detail_screen.dart line 228.

### Informational

- appLogger.debug(AnalyticsEvents.sessionDeleted) and similar calls log the event name string but do not fire Firebase Analytics events. Functional gap, not a security risk.
- No hardcoded API keys, Firebase config values, or secrets found in any audited file.
- No print() calls found in any audited file.
- All remote images use CachedNetworkImageProvider. Compliant.
- All Firestore path strings centralised in FirestorePaths. No path injection vector found.
- SessionModel and JoinRequestModel use Freezed + json_serializable. No hand-rolled deserialization.
- All appLogger extra maps contain only sessionId (opaque), error codes, and aggregate counts. No PII in logs.
- firestore.rules isKmuttUser() enforces both @mail.kmutt.ac.th and @kmutt.ac.th with email_verified == true. Correct.
- sessions create rule enforces createdAt == request.time and updatedAt == request.time. Correct.
- sessions update rule uses affectedKeys().hasOnly(...). Correct.
- users/{uid} allow read: if isKmuttUser() permits all KMUTT users to read all user documents. By design at current stage; email and fullName are readable by any KMUTT peer via direct Firestore read, independent of SEC-005.

---

### JSON report

```json
{
  "agent": "security-reviewer",
  "date": "2026-05-18",
  "findings": [
    {"id": "SEC-001", "severity": "critical", "title": "Missing Firestore rules block for sessions/{sessionId}/requests subcollection", "file": "firestore.rules", "line": null},
    {"id": "SEC-002", "severity": "critical", "title": "No server-side PIN validation rule; joinWithPin will accept any PIN once rules block is added", "file": "apps/mobile/lib/features/sessions/data/repositories/join_request_repository_impl.dart", "line": 89},
    {"id": "SEC-003", "severity": "critical", "title": "Non-host users subscribe to full joinRequestsProvider collection stream for pending-status check", "file": "apps/mobile/lib/features/sessions/presentation/screens/session_detail_screen.dart", "line": 121},
    {"id": "SEC-004", "severity": "high", "title": "isViewerHost derived from racing async providers may briefly expose faculty PII", "file": "apps/mobile/lib/features/sessions/presentation/screens/members_list_screen.dart", "line": 24},
    {"id": "SEC-005", "severity": "high", "title": "watchMembers reads full user documents including email and fullName PII unnecessarily", "file": "apps/mobile/lib/features/sessions/data/repositories/session_repository_impl.dart", "line": 191},
    {"id": "SEC-006", "severity": "high", "title": "ADR 0003 Status field not updated to Accepted", "file": "docs/decisions/0003-sessions-architecture.md", "line": 4},
    {"id": "SEC-007", "severity": "medium", "title": "PIN stored in plaintext in sessions/{sessionId}.pin", "file": "apps/mobile/lib/features/sessions/data/repositories/session_repository_impl.dart", "line": 93},
    {"id": "SEC-008", "severity": "medium", "title": "joinWithPin is non-atomic; dangling PIN document on crash between steps", "file": "apps/mobile/lib/features/sessions/data/repositories/join_request_repository_impl.dart", "line": 91},
    {"id": "SEC-009", "severity": "medium", "title": "Join button rendered for unauthenticated users before currentUserProvider resolves", "file": "apps/mobile/lib/features/sessions/presentation/screens/session_detail_screen.dart", "line": 957},
    {"id": "SEC-010", "severity": "medium", "title": "Leave action passes empty string uid when me is null", "file": "apps/mobile/lib/features/my_sessions/presentation/screens/member_session_detail_screen.dart", "line": 228}
  ],
  "severity_max": "critical",
  "verdict": "BLOCKED",
  "summary": "Three critical findings block merge: the sessions/{sessionId}/requests subcollection has no Firestore rules block; the PIN validation rule is absent meaning joinWithPin will accept any PIN once the rules block is added; and non-host users subscribe to the full join-requests collection stream. Three high findings (racing PII exposure, unnecessary PII in watchMembers, ADR status not Accepted) must also be resolved before release. Each critical finding requires a corresponding emulator integration test before re-review."
}
```

### Verdict

- BLOCKED -- Three critical findings: (1) sessions/{sessionId}/requests subcollection has no Firestore rules block, leaving requester PII unprotected once any rule is added; (2) no server-side PIN comparison rule exists, meaning joinWithPin will silently accept any PIN once the rules block is present; (3) non-host users open a collection-level stream against the requests subcollection. All three require a corresponding emulator integration test covering the security path before this branch can be approved for merge.

---

## Checklist

| Category | Status | Notes |
|----------|--------|-------|
| Firestore rules -- auth gate | PASS | All session rules require isKmuttUser() which enforces request.auth != null and email_verified |
| Firestore rules -- host RBAC | PARTIAL | sessions update/delete use isHost(sessionId) correctly; requests subcollection has no rule block |
| Firestore rules -- PIN isolation | FAIL | No rule validates PIN on write; pin field readable by any KMUTT member who can read the session document |
| Firestore rules -- requests subcollection | FAIL | Block entirely absent from firestore.rules |
| Firestore rules -- field-level diff | PASS | sessions update and users update both use affectedKeys().hasOnly(...) |
| Firestore rules -- request.time timestamps | PASS | createdAt == request.time and updatedAt == request.time enforced on session and user create/update |
| Firestore rules -- KMUTT domain | PASS | isKmuttUser() enforces @mail.kmutt.ac.th and @kmutt.ac.th with email_verified == true |
| PIN not in logs | PASS | No log statement emits PIN value in any audited file |
| PIN not exposed to non-hosts (client) | PASS | fetchPin in repository checks hostUid != callerUid before datasource call |
| PIN not exposed to non-hosts (server) | FAIL | No rules block; PIN field on session document readable by any KMUTT member who can read the session |
| No path injection | PASS | All Firestore paths via FirestorePaths constants; no user input interpolated into paths |
| Auth boundary client-side | PASS | All mutating operations check callerUid == hostUid in repository layer before Firestore write |
| No PII in logs | PASS | All logger extra maps contain only sessionId, error codes, aggregate counts |
| No hardcoded secrets | PASS | No API keys or Firebase config values found in source |
| Images via CachedNetworkImageProvider | PASS | All remote images use CachedNetworkImageProvider; no bare Image.network |
| No print() calls | PASS | Zero print() calls in any audited file |
| Frozen models -- no hand-rolled JSON | PASS | SessionModel and JoinRequestModel use Freezed + json_serializable |
| Isolated data -- users own documents | PASS | users/{uid} create and update both require request.auth.uid == uid |
| Isolated data -- session member streams | PARTIAL | Public sessions scoped correctly; private session reads blocked by rules; requests subcollection unscoped |
