## [1.0.0] - 2026-06-01

**feat**
- Calendar: offline-first caching layer; sessions served from local cache when device has no connectivity
- Calendar: offline banner widget shown automatically when network is unavailable
- Calendar: connectivity provider (lib/core/connectivity/connectivity_provider.dart) wired into calendar data layer
- Calendar: monthly/weekly view of historical and upcoming sessions (ADR 0007)
- Calendar: day-detail screen with sessions sorted by start time
- Calendar: overflow pill for days with more than 3 sessions
- Calendar: GCal sync settings screen (feature-flagged off in production)
- Auth: KMUTT email domain gate (@mail.kmutt.ac.th, @kmutt.ac.th) with email verification required
- Sessions: create, edit, delete, end sessions; public (host-approved join requests) and private (PIN/invite) visibility
- Friends: send, accept, decline friend requests; bidirectional friendship model
- Chat: DM one-to-one messaging between confirmed friends (ADR 0011)
- Chat: session group messaging for session members (ADR 0012)
- Chat: Groups tab in Messages screen with unread badges
- Search: filter sessions by name, hashtag, academic level, and student year
- Rating: thumbs-up rating between session members after session ends; profile score as percentage
- Note-Sharing: images, documents, and archives up to 10 MB per file; 50 notes per session; host or owner delete
- Notification settings

**fix**
- Android: build configuration corrected (b627903)
- Minor UI polish (da2f69d, 4d5ee10)
- Removed debug test crash button from production build (f9026bf)
- SEC-0012-02: senderDisplayName sourced from auth token, not Firestore
- CHAT-H1: message create rule uses keys().hasOnly
- CHAT-M1 through CHAT-M4: Firestore rules hardening for chat

**chore**
- Version bumped from 0.2.0+2 to 1.0.0+1 for first public release
- Firestore rules: dms/{dmId} block (ADR 0011)
- Firestore rules: sessions/messages and users/{uid}/groupChats blocks (ADR 0012)
- Firestore Index 11 deployed (dms participantUids + lastMessageAt)

## [0.2.0] - 2026-05-31

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