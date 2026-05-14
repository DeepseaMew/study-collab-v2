# Feature Flags & Rollback Plans

All feature flags use Firebase Remote Config unless noted.
Each entry must include: flag name, what it gates, default value,
rollback plan, and owner.

---

## Auth

### `auth.allowGmailDev`
- **Type:** Client-side constant (not Remote Config — build-time only)
- **Location:** `apps/mobile/lib/core/constants/auth_constants.dart`
- **What it gates:** Allows `gmail.com` email addresses to sign up
  and sign in. Dev-only exception because `@kmutt.ac.th` email
  delivery is unreliable during development.
- **Default:** `true` (dev), must be `false` before launch
- **Rollback plan:** Remove `gmail.com` from `kAllowedEmailDomains`
  in `auth_constants.dart`. Update the matching Firestore rule in
  `firestore.rules` (`users/{uid}` create rule). Update the
  `SignUpUseCase` domain validator if it has a separate list.
  All three must be updated together — see ADR 0001.
- **Owner:** firebase-specialist
- **Launch checklist:** Remove before first external beta. Tracked in
  ADR 0001 consequences.

---

## Upcoming flags (register here before implementing)

| Flag | Feature | Status |
|------|---------|--------|
| `file_sharing_enabled` | Session file/note sharing | Not implemented |
| `rating_enabled` | Post-session ratings UI | Not implemented |
| `group_chat_enabled` | In-session group chat | Implemented, no flag yet |

---

## How to add a new flag

1. Add an entry to this file with all required fields.
2. Create the flag in Firebase Console → Remote Config.
3. Set a safe default value (usually `false` for new features).
4. Gate the feature in presentation layer:
   ```dart
   final enabled = ref.watch(remoteConfigProvider)
       .getBool('flag_name');
   if (!enabled) return const ComingSoonWidget();
   ```
5. Document the rollback plan — what happens if you set the flag
   to `false` after users have used the feature?