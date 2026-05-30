# Security Review — ADR 0012: Session Group Chat

**Agent:** security-reviewer
**Date:** 2026-05-31
**Feature:** Session Group Chat
**Branch:** feat/sessions-chat

## Scope

Files reviewed:

- `firestore.rules` (full file, 384 lines)
- `apps/mobile/lib/features/chat/data/datasources/session_chat_remote_datasource.dart`
- `apps/mobile/lib/features/chat/data/repositories/session_chat_repository_impl.dart`
- `apps/mobile/lib/features/chat/domain/entities/session_message.dart`
- `apps/mobile/lib/features/chat/domain/entities/group_chat_summary.dart`
- `apps/mobile/lib/features/chat/domain/repositories/session_chat_repository.dart`
- `apps/mobile/lib/features/chat/domain/usecases/send_session_message.dart`
- `apps/mobile/lib/features/chat/domain/usecases/mark_session_read.dart`
- `apps/mobile/lib/features/chat/domain/usecases/stream_session_messages.dart`
- `apps/mobile/lib/features/chat/domain/usecases/stream_group_chat_summaries.dart`
- `apps/mobile/lib/features/chat/presentation/providers/session_chat_providers.dart`
- `apps/mobile/lib/features/chat/presentation/screens/session_chat_screen.dart`
- `apps/mobile/lib/features/note_sharing/data/datasources/note_datasource.dart`
- `apps/mobile/lib/features/note_sharing/data/repositories/note_repository_impl.dart`
- `apps/mobile/lib/core/analytics_events.dart`
- `apps/mobile/lib/core/firestore_paths.dart`

---

## Findings

### Critical (block merge)

None.

---

### High (fix before release)

- **`groupChats` write rule allows any session member to zero any other member's `unreadCount`, suppressing unread badges.**
  - File: `firestore.rules`, lines 88–96.
  - Risk: A malicious or buggy member can write `unreadCount: 0` to every other member's `users/{uid}/groupChats/{sessionId}` doc, silently suppressing unread-message indicators across the entire session. No data loss; no confidentiality breach. The write still requires `isMember(sessionId)`, so it cannot be exploited by non-members.
  - ADR 0012 documents this as "Option C – accepted risk: badge suppression only, no data loss." The risk is acceptable at MVP, but at scale a determined member could permanently suppress badges for all participants in large sessions.
  - Recommended fix before a post-MVP release: split the write rule into two cases — (a) the document owner may write all 5 fields; (b) non-owner members may only write `sessionId`, `sessionTitle`, `lastMessageText`, `lastMessageAt` (preview/timestamp fields) and may only increment `unreadCount` (`request.resource.data.unreadCount == resource.data.unreadCount + 1`), never decrement it. The `unreadCount: 0` path (mark-read) should require `request.auth.uid == uid`. This transforms the accepted risk from "any member can suppress any badge" to "any member can increment your badge by exactly 1 per send," which is the intended invariant.
  - Because this risk is explicitly documented in ADR 0012 and classified "no data loss," it does **not** block the current merge.

- **`senderDisplayName` in `NoteRepositoryImpl` is sourced from a Firestore read (`users/{uploaderUid}.displayName`) rather than from the Firebase Auth token — TOCTOU window and stale denormalization risk.**
  - Files: `apps/mobile/lib/features/note_sharing/data/repositories/note_repository_impl.dart`, lines 57–58 and 196–204; `apps/mobile/lib/features/note_sharing/data/datasources/note_datasource.dart`, lines 131–132.
  - Risk: A user can update `users/{uid}.displayName` between the `_fetchDisplayName` Firestore read and the `writeNoteBatch` commit. The displayed name in the `file_shared` message may then differ from what the user's profile shows at that moment. The message document is immutable after write (`allow update: if false`), so any discrepancy is permanent for that message. This is an integrity issue (stale denormalization), not a confidentiality issue.
  - Contrast: `SessionChatScreen._send()` sources `senderDisplayName` directly from `me.displayName` on the Firebase Auth `User` object (line 77), which is the correct pattern and is not subject to this issue.
  - Required fix before release: in `NoteRepositoryImpl.uploadNote`, replace the `_fetchDisplayName` Firestore get with `_auth.currentUser?.displayName ?? ''`. This eliminates the extra Firestore read, the TOCTOU window, and the architecture smell flagged by the flutter-engineer. The `users/{uid}` Firestore document's `displayName` field is user-editable (`firestore.rules` line 60), so it is no more authoritative than the Auth token value; the Auth token value is preferable.

---

### Informational

- **KMUTT domain gate correctly enforced.** `isKmuttUser()` at `firestore.rules` lines 8–12 validates `email_verified == true` and an email regex matching `@mail.kmutt.ac.th` or `@kmutt.ac.th`. All new `sessions/messages` and `users/{uid}/groupChats` paths require `isMember(sessionId)` which transitively calls `isKmuttUser()`. Domain gate is correctly inherited.

- **`sentAt == request.time` correctly absent.** `firestore.rules` line 218 documents the removal with a comment citing the ADR 0011 web constraint. `sentAt` is present in `hasAll`/`hasOnly` field lists (lines 235, 239, 245, 249) so the field is required to exist but its value is not server-time-pinned. Correct trade-off per ADR 0011.

- **`readBy` correctly absent.** Lines 219 (rules) and entity definitions confirm `readBy` was removed from session messages. Unread state lives exclusively in `users/{uid}/groupChats/{sessionId}.unreadCount`. No tautology or stale-read risk from `readBy` array manipulation.

- **`allow update: if false` and `allow delete: if false` on session messages.** `firestore.rules` lines 253–254 confirm messages are fully immutable after creation. `senderDisplayName` written at send time cannot be altered by any subsequent request.

- **`diff().affectedKeys().hasOnly(...)` pattern used correctly on all write rules in scope.** The messages `create` rule uses `keys().hasOnly(...)` on the full document (correct for a create path where there is no prior document to diff). The `groupChats` `create, update` rule also uses `keys().hasOnly(...)` on the full document, correct for both operations given the `SetOptions(merge: true)` client pattern.

- **No `diff(self)` tautology found.** All `diff()` calls in the file are of the form `request.resource.data.diff(resource.data)`, which is the correct pattern.

- **No secrets or API keys found in any reviewed file.** Grep for `AIza`, `Bearer`, `api_key`, `secret`, `password`, `AUTH_TOKEN`, and `FIREBASE_KEY` returned no results across all 16 reviewed files.

- **No `print()` calls found.** All logging routes through `appLogger` from `lib/core/logger.dart`. No violations found in any reviewed file.

- **No PII in log statements.** All `appLogger` calls in `session_chat_remote_datasource.dart`, `session_chat_repository_impl.dart`, `note_datasource.dart`, and `note_repository_impl.dart` log only structural identifiers (`sessionId`, `messageId`, `noteId`, `errorCode`). No message text, display names, email addresses, file content, or UIDs beyond opaque identifiers appear in log strings.

- **Crashlytics `kIsWeb` guards present on all recording sites.** Every `FirebaseCrashlytics.instance.recordError(...)` call in the reviewed files is guarded with `if (!kIsWeb)`. Lines 77, 146, 174, 246 in `session_chat_remote_datasource.dart`; lines 33, 62, 97, 117, 140 in `session_chat_repository_impl.dart`; lines 79, 199 in `note_datasource.dart`; line 123 in `note_repository_impl.dart`. All correct.

- **No Crashlytics `setCustomKey` calls present.** No custom key calls were found in any reviewed file. No PII exposure risk from custom keys.

- **`downloadUrl` in `file_shared` messages is sourced from Firebase Storage SDK.** `note_datasource.dart` line 68 calls `task.ref.getDownloadURL()` — the URL is obtained from the Firebase Storage SDK response after a successful upload, not from user-supplied input. It is written to the Firestore batch at line 136. The Firestore rules do not validate the URL format (no regex), but the field is immutable after creation and the source is the SDK, so there is no injection risk.

- **Extra `sessions/{sessionId}` get in `NoteRepositoryImpl` to fetch `memberUids` and `sessionTitle`.** `note_repository_impl.dart` lines 90–98. This is an architecture smell (the repository reads a document outside its domain boundary) and introduces a small TOCTOU window: if a member is removed from the session between this read and the `writeNoteBatch` commit, the fan-out will attempt to write a `groupChats` summary for a user who is no longer a member. The Firestore rule for `groupChats` write requires `isMember(sessionId)` at commit time, so the orphaned summary write will simply fail for the removed member — no data is leaked. The stale `memberUids` list causes a partial batch failure but not a security issue. Addressed by the High finding above (replace with Auth token source, eliminating the extra read).

- **`senderDisplayName` fallback to empty string.** `session_chat_screen.dart` line 77: `me.displayName ?? ''`. An empty `senderDisplayName` does not cause any security issue. The field is present in `keys().hasAll(...)` but no minimum-length constraint is enforced on it in the Firestore rule; this is consistent with the DM message rule (same field, no length constraint). An empty display name produces a cosmetically degraded UI (no name shown on message bubble) but no authorization bypass.

- **`unreadCount` field in `groupChats` create/update uses `keys().hasOnly(...)` on the full document, not `diff().affectedKeys().hasOnly(...)`.** This is correct for a merged-set pattern: the client uses `SetOptions(merge: true)`, meaning `resource.data` may not exist on create. Using `diff()` on a non-existent prior document would throw in Firestore rules. The chosen approach is intentional and correct.

- **Analytics events declared before use.** `AnalyticsEvents.sessionChatOpened`, `sessionChatMessageSent`, and `sessionChatFileMessageTapped` are all declared in `apps/mobile/lib/core/analytics_events.dart` lines 148–155 before their use in `session_chat_screen.dart`. No PII in any event name or documented payload. Compliant with house rules.

- **Accepted risk from ADR 0012 (Option C) on fan-out writes confirmed.** Any `isMember` can write any other member's `groupChats` summary. This is required for the fan-out architecture and is documented as an accepted risk. The `keys().hasOnly(...)` constraint limits writable fields to 5 innocuous preview/counter fields. Risk is badge suppression only; no data loss; no unauthorized reads. The `allow delete` rule (`firestore.rules` lines 98–99) correctly restricts deletion to `request.auth.uid == uid` only, so a member cannot delete another member's summary document.

- **`markSessionRead` writes only `unreadCount: 0`.** `session_chat_remote_datasource.dart` line 157: `ref.update({'unreadCount': 0})`. The Firestore `create, update` rule for `groupChats` allows any `isMember` to write `unreadCount` to any value (including 0). The behavioral control preventing cross-user badge suppression is purely at the application layer (callers only pass their own `uid`). This is the documented accepted risk per ADR 0012.

---

## JSON Report

```json
{
  "agent": "security-reviewer",
  "date": "2026-05-31",
  "findings": [
    {
      "id": "SEC-0012-01",
      "severity": "high",
      "title": "groupChats write rule allows any member to zero any other member's unreadCount",
      "file": "firestore.rules",
      "lines": "88-96",
      "status": "accepted_risk_adr0012",
      "blocks_merge": false
    },
    {
      "id": "SEC-0012-02",
      "severity": "high",
      "title": "senderDisplayName in file_shared messages sourced from Firestore read, not Auth token — TOCTOU window and stale denormalization risk",
      "file": "apps/mobile/lib/features/note_sharing/data/repositories/note_repository_impl.dart",
      "lines": "57-58, 196-204",
      "status": "fix_before_release",
      "blocks_merge": false
    }
  ],
  "severity_max": "high",
  "verdict": "APPROVED",
  "summary": "No critical findings. Two high findings: groupChats fan-out badge-suppression risk (accepted per ADR 0012) and senderDisplayName TOCTOU in NoteRepositoryImpl (fix before release by sourcing from Auth token). All Firestore rules for sessions/messages and groupChats are structurally correct: isMember gate, keys().hasOnly, update/delete locked, no readBy, sentAt not time-pinned per ADR 0011. No secrets, no PII in logs, no print() calls."
}
```

---

## Verdict

**APPROVED** — no critical findings block merge. Two high findings tracked above: badge-suppression risk is explicitly accepted in ADR 0012; `senderDisplayName` TOCTOU in `NoteRepositoryImpl` must be resolved (swap `_fetchDisplayName` Firestore read for `_auth.currentUser?.displayName ?? ''`) before the next production release.
