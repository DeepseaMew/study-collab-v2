## v0.2.0 — 2026-05-31

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
