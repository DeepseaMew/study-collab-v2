# Security Review — ADR 0011: DM Chat

| Field | Value |
|---|---|
| Agent | security-reviewer |
| Date | 2026-05-31 |
| Session ID | feat/sessions-chat |
| Triggered by | Branch feat/sessions-chat — DM Chat implementation (ADR 0011) |
| Reviewed scope | `firestore.rules` (dms/{dmId} and dms/{dmId}/messages blocks); `apps/mobile/lib/features/chat/data/datasources/chat_remote_datasource.dart` |

---

## Security Reviewer section

### Scope

Files reviewed:
- `firestore.rules` — `dms/{dmId}` block (lines 316–381) and `dms/{dmId}/messages` sub-block (lines 354–380)
- `apps/mobile/lib/features/chat/data/datasources/chat_remote_datasource.dart` (all 327 lines)

### Critical (block merge)

None.

### High (fix before release)

- **CHAT-H1** [RESOLVED] — `dms/{dmId}/messages` create rule previously used `diff(self).affectedKeys()`, which always produces an empty diff on a new document, causing the field allowlist check to pass vacuously for any set of fields a client chose to write. Risk: a malicious client could inject arbitrary fields (e.g., `isAdmin`, poisoned display name variants) into message documents. Fix applied: replaced with `request.resource.data.keys().hasOnly([...])` (firestore.rules lines 368–370) and `request.resource.data.keys().hasAll([...])` (lines 365–367). `diff(self)` is absent from the entire `dms` block. Verification: CONFIRMED — lines 365–370 of firestore.rules contain both `keys().hasAll(...)` and `keys().hasOnly(...)` with no `diff(self)` present.

### Medium (fix before release)

- **CHAT-M1** [RESOLVED] — `readBy` was not append-only in the update rule: a participant could remove other participants' UIDs from the array, allowing them to manufacture false "unread" state for the other user. Risk: integrity violation of read receipts; a sender could erase the receiver's receipt. Fix applied: `request.resource.data.readBy.hasAll(resource.data.readBy)` added to the `dms/{dmId}/messages` update rule (firestore.rules line 377). Verification: CONFIRMED — line 377 of firestore.rules reads `&& request.resource.data.readBy.hasAll(resource.data.readBy);`.

- **CHAT-M2** [RESOLVED] — Any participant could zero or manipulate the other participant's `unreadCounts` entry on the `dms/{dmId}` document, allowing one user to suppress another's unread badge. Risk: notification integrity; a sender could hide their own messages from the recipient's badge counter. Fix applied: the `dms/{dmId}` update rule now contains two branches — a mark-read branch (line 348) that only permits `affectedKeys().hasOnly(['unreadCounts'])` when `unreadCounts[request.auth.uid] == 0`, and a send branch (line 344) that permits the caller's own counter to remain unchanged. Only the requesting user's own key may be zeroed (firestore.rules lines 339–350). Verification: CONFIRMED — lines 344–350 of firestore.rules implement the per-user restriction.

- **CHAT-M3** [RESOLVED] — `markRead` previously called `_dmDoc(dmId).update(...)` unconditionally; if the DM document did not yet exist (e.g., called before the first message is sent), Firestore returns `not-found`, which was swallowed silently, hiding a logic error. Risk: silent failure masking application state bugs; the unread count is never cleared for the user. Fix applied: an existence guard (`snap.exists` check) was added before the update call (chat_remote_datasource.dart lines 196–203); `appLogger.warning(...)` is emitted if the document is missing (lines 198–201); `FirebaseCrashlytics.instance.recordError(e, st, reason: 'chat_mark_read failed')` is called in the catch block guarded by `if (!kIsWeb)` (lines 213–219). Verification: CONFIRMED — lines 196–203 contain the existence guard and warning log; lines 213–219 contain the Crashlytics call with web guard.

- **CHAT-M4** [RESOLVED] — No server-side text length limit existed on `dms/{dmId}/messages` create, meaning a client could write arbitrarily large message payloads, potentially exhausting Firestore document size quotas (max 1 MiB per document) or causing denial-of-service for participants loading message history. Risk: storage abuse, excessive client read bandwidth, potential DoS. Fix applied: `request.resource.data.text.size() > 0 && request.resource.data.text.size() <= 4000` added to the create rule (firestore.rules lines 363–364). Verification: CONFIRMED — lines 363–364 of firestore.rules contain the constraint.

### Informational

- `senderDisplayName` is write-once: it is required in the `keys().hasAll(...)` list on create (firestore.rules line 366) but the update rule for `dms/{dmId}/messages` permits only `readBy` via `affectedKeys().hasOnly(['readBy'])` (line 375), so `senderDisplayName` cannot be mutated after creation. Classification: benign — correct by design.

- All Crashlytics calls in `chat_remote_datasource.dart` are guarded with `if (!kIsWeb)` — confirmed at lines 115, 160, 182, 213, and 241. This is correct per project convention (Crashlytics package is not supported on web). Classification: benign.

- No `print()` calls are present in `chat_remote_datasource.dart`. All logging routes through `appLogger` (lines 99, 103, 109, 152, 155, 174, 177, 198, 205, 208, 235, 291, 312). Classification: benign — compliant with project logging convention.

- No secrets or API keys are hardcoded in `chat_remote_datasource.dart`. The only external dependencies are `FirebaseFirestore.instance` and `FirebaseCrashlytics.instance`, both injected at runtime by the Firebase SDK. Classification: benign.

- No PII is present in any log string in `chat_remote_datasource.dart`. Log `extra` maps contain only `dmId` (an opaque compound UID string), `code` (Firestore error code), and `docId` (document ID). No message text, display names, or email addresses appear in any log call. Classification: benign — compliant with project no-PII logging policy.

- The `areFriends()` friendship gate is enforced client-side in `ChatRemoteDatasource.areFriends()` (lines 227–243) rather than in Firestore rules. This is a documented architectural trade-off (ADR 0011 — the `areFriends()` helper would cost 2 `get()` calls on a path that already consumes calls to read `participantUids`, exceeding the 10-call budget). Risk accepted by ADR. The comment at firestore.rules lines 317–319 documents this decision. Classification: benign — trade-off is recorded and understood.

### JSON report

```json
{
  "agent": "security-reviewer",
  "date": "2026-05-31",
  "findings": [
    {
      "id": "CHAT-H1",
      "severity": "high",
      "status": "resolved",
      "title": "dms/messages create rule used diff(self).affectedKeys() — always-empty diff bypasses field allowlist",
      "file": "firestore.rules",
      "lines": "365-370",
      "fix": "Replaced with keys().hasOnly(...) and keys().hasAll(...)"
    },
    {
      "id": "CHAT-M1",
      "severity": "medium",
      "status": "resolved",
      "title": "readBy array was not append-only — entries could be removed on update",
      "file": "firestore.rules",
      "lines": "372-378",
      "fix": "Added request.resource.data.readBy.hasAll(resource.data.readBy) to update rule"
    },
    {
      "id": "CHAT-M2",
      "severity": "medium",
      "status": "resolved",
      "title": "Any participant could zero another participant's unreadCounts entry",
      "file": "firestore.rules",
      "lines": "339-350",
      "fix": "Restricted unreadCounts update to caller's own key only"
    },
    {
      "id": "CHAT-M3",
      "severity": "medium",
      "status": "resolved",
      "title": "markRead fired on missing DM doc — not-found error swallowed silently",
      "file": "apps/mobile/lib/features/chat/data/datasources/chat_remote_datasource.dart",
      "lines": "194-222",
      "fix": "Added existence guard, warning log, and Crashlytics recordError with !kIsWeb guard"
    },
    {
      "id": "CHAT-M4",
      "severity": "medium",
      "status": "resolved",
      "title": "No server-side text length limit on dms/messages create",
      "file": "firestore.rules",
      "lines": "363-364",
      "fix": "Added text.size() > 0 && text.size() <= 4000 to create rule"
    }
  ],
  "severity_max": "high",
  "verdict": "APPROVED",
  "summary": "All 5 findings (1 High, 4 Medium) identified during the ADR 0011 DM Chat review are confirmed resolved in firestore.rules and chat_remote_datasource.dart. No new issues were found. No secrets, PII in logs, or print() calls detected."
}
```

### Verdict

APPROVED — all 5 previously identified findings (CHAT-H1 through CHAT-M4) are confirmed resolved with specific line-level verification; no new issues found in the reviewed files.
