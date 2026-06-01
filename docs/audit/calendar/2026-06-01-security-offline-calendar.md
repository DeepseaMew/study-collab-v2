# Audit report

| Field | Value |
|---|---|
| Agent | security-reviewer |
| Date | 2026-06-01 |
| Session ID | claude-sonnet-4-6-2026-06-01 |
| Triggered by | Commits a078363, b627903 — offline-first calendar feature |
| Reviewed scope | apps/mobile/lib/features/calendar/data/datasources/calendar_datasource.dart, apps/mobile/lib/features/calendar/presentation/screens/calendar_screen.dart, apps/mobile/lib/features/calendar/presentation/widgets/offline_banner.dart, apps/mobile/lib/core/connectivity/connectivity_provider.dart, apps/mobile/lib/core/logger.dart |

---

## Security Reviewer section

### Critical (block merge)
- none

### High (fix before release)
- none

### Informational

- **PII in logs — doc.id in error path (benign)**: `calendar_datasource.dart` lines 52 and 58 interpolate `doc.id` (the Firestore session document ID) into `appLogger.error` messages. Firestore auto-generated document IDs are opaque random strings and are not user-identifiable data (no UID, email, display name, or session title is logged). The `appLogger.error` path calls `_emit` → `debugPrint`; in release builds Flutter suppresses `debugPrint` output entirely, so no log reaches the device console or any remote sink. No action required, but teams should be aware that session IDs are visible in debug logs.

- **PII in logs — debug path (benign)**: `calendar_datasource.dart` lines 28-30 and 63-67 call `appLogger.debug`, which is guarded by `if (kDebugMode)` in `logger.dart` line 18. The messages contain only window timestamps and a session count integer — no UIDs, emails, or session titles. Compliant with the no-PII logging rule.

- **Cache trust — Firestore offline cache (benign)**: When the device is offline, `watchSessionsInRange` returns data from the Firestore local cache without re-validating against the server. This is the expected behaviour of the Firestore SDK's offline persistence. Security properties are preserved: the cached data was previously fetched under the authenticated user's token and enforced by server-side Firestore rules. The cache cannot be written to by a third party. The `OfflineBanner` widget correctly informs the user that data may be stale. No bypass of auth or Firestore rules occurs.

- **Connectivity detection — `isOnlineProvider` spoofing (benign)**: `connectivity_provider.dart` wraps `connectivity_plus`'s `onConnectivityChanged` stream. This provider controls only the visibility of the `OfflineBanner` UI element; it does not gate data access, auth tokens, or write operations. A malicious app cannot use manipulation of the connectivity signal to gain access to data it is not entitled to — Firestore rules and Firebase Auth enforce access server-side regardless of what the client-side connectivity flag reports. The risk is limited to the cosmetic outcome of hiding or showing the banner.

- **No new network calls or auth changes (benign)**: The diff introduces no new Firebase Auth calls, no new sign-in flows, no token handling, and no changes to Firestore rules. The existing `firebaseAuthStateProvider` auth gate on `calendar_screen.dart` line 47-50 is unmodified and continues to enforce that only authenticated users reach the calendar.

- **No new secrets or local storage (benign)**: No `flutter_secure_storage` calls, no new SharedPreferences keys, no hardcoded API keys or tokens were introduced. The offline feature relies entirely on the Firestore SDK's built-in cache, which is managed by the Firebase SDK and outside the app's storage scope.

- **`appLogger.error` constructs strings in release builds (informational)**: Because `appLogger.error` does not wrap its `_emit` call in a `kDebugMode` guard (unlike `appLogger.debug`), the error message string is allocated and passed to `debugPrint` even in release builds. `debugPrint` is a no-op in release, so there is no observable output, but string interpolation of `doc.id` does occur. This is negligible in practice but could be hardened by adding a `kDebugMode` guard around the entire catch block or using a conditional log level. Suggested improvement: wrap the `appLogger.error` calls in the catch block with `if (kDebugMode)` or promote them to a Crashlytics non-fatal recording path that is explicitly reviewed for PII.

- **Firestore rules unchanged (benign)**: The sessions collection rules (KMUTT domain validation, RBAC host/student checks, `diff().affectedKeys()` field-level guards, `request.time` on timestamp fields, per-user document isolation) were not modified by these commits. No review of rule changes required for this diff.

### JSON report
```json
{
  "agent": "security-reviewer",
  "date": "2026-06-01",
  "findings": [
    {
      "id": "SEC-CAL-001",
      "severity": "info",
      "classification": "benign",
      "title": "doc.id interpolated in appLogger.error messages",
      "file": "apps/mobile/lib/features/calendar/data/datasources/calendar_datasource.dart",
      "lines": "52, 58",
      "detail": "Firestore session document IDs are opaque random strings, not PII. debugPrint is a no-op in release builds. No action required."
    },
    {
      "id": "SEC-CAL-002",
      "severity": "info",
      "classification": "benign",
      "title": "Firestore offline cache served without server re-validation",
      "file": "apps/mobile/lib/features/calendar/data/datasources/calendar_datasource.dart",
      "lines": "63-67",
      "detail": "Expected Firestore SDK behaviour. Cache data was originally fetched under enforced Firestore rules. OfflineBanner notifies user of potential staleness."
    },
    {
      "id": "SEC-CAL-003",
      "severity": "info",
      "classification": "benign",
      "title": "isOnlineProvider is spoofable by malicious app",
      "file": "apps/mobile/lib/core/connectivity/connectivity_provider.dart",
      "lines": "14-19",
      "detail": "Controls only UI banner visibility. Data access enforced server-side by Firebase Auth and Firestore rules regardless of client connectivity signal."
    },
    {
      "id": "SEC-CAL-004",
      "severity": "info",
      "classification": "review-needed",
      "title": "appLogger.error string construction occurs in release builds",
      "file": "apps/mobile/lib/features/calendar/data/datasources/calendar_datasource.dart",
      "lines": "51-59",
      "detail": "No output in release (debugPrint is suppressed) but string is allocated. Recommend wrapping catch block with kDebugMode guard or routing to explicit Crashlytics non-fatal path reviewed for PII."
    }
  ],
  "severity_max": "info",
  "verdict": "APPROVED",
  "summary": "No Critical or High findings. All four changes are benign or informational. Logging is PII-free, offline cache trust is appropriate for the SDK model, connectivity detection gates only UI, and no auth or Firestore rules were modified."
}
```

### Verdict
- APPROVED — no Critical or High findings; all changes are benign UI additions with PII-free logging and no modifications to auth, Firestore rules, or local secret storage.
