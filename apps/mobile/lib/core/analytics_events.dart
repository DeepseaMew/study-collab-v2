/// All analytics event name constants for Study Collab.
///
/// Every event MUST be declared here before use. No event string may be
/// inlined anywhere else in the codebase.
///
/// No PII (email, UID, display name) may appear in event names or payloads.
abstract final class AnalyticsEvents {
  // ── Auth ───────────────────────────────────────────────────────────────────
  /// User tapped "Sign Up" to begin registration.
  static const String authSignUpStarted = 'auth_sign_up_started';

  /// User completed registration and verified email.
  static const String authSignUpCompleted = 'auth_sign_up_completed';

  /// User successfully signed in.
  static const String authSignInCompleted = 'auth_sign_in_completed';

  /// User signed out.
  static const String authSignOut = 'auth_sign_out';

  /// User requested another verification email.
  static const String authVerifyEmailResend = 'auth_verify_email_resend';

  /// User completed the profile-setup screen.
  static const String authProfileSetupCompleted =
      'auth_profile_setup_completed';

  /// Client-side KMUTT domain regex rejected a non-KMUTT email.
  /// Payload must carry NO email value.
  static const String authKmuttDomainRejected = 'auth_kmutt_domain_rejected';

  // ── Sessions ───────────────────────────────────────────────────────────────
  /// Host created a new session.
  static const String sessionCreated = 'session_created';

  /// Host edited an existing session.
  static const String sessionEdited = 'session_edited';

  /// Host deleted a session. Payload: session_id.
  static const String sessionDeleted = 'session_deleted';

  /// Host ended a session. Payload: session_id.
  static const String sessionEnded = 'session_ended';

  /// Member submitted a join request. Payload: session_id.
  static const String sessionJoinRequested = 'session_join_requested';

  /// Member was approved and joined. Payload: session_id.
  static const String sessionJoined = 'session_joined';

  /// Member left a session. Payload: session_id.
  static const String sessionLeft = 'session_left';

  /// Host approved a join request. Payload: session_id.
  static const String sessionRequestApproved = 'session_request_approved';

  /// Host declined a join request. Payload: session_id.
  static const String sessionRequestDeclined = 'session_request_declined';

  /// User switched tab in My Sessions. Payload: tab_name (upcoming|completed|hosted).
  static const String mySessionsTabSwitched = 'my_sessions_tab_switched';

  /// User submitted a search query in My Sessions (non-empty only).
  /// No PII — no query value in payload.
  static const String mySessionsSearched = 'my_sessions_searched';

  /// User submitted ratings after a session ended. Payload: thumbs_up_count (int).
  static const String sessionRatingSubmitted = 'session_rating_submitted';

  // ── Friends ────────────────────────────────────────────────────────────────
  /// Current user sent a friend request. No payload; no PII.
  static const String friendRequestSent = 'friend_request_sent';

  /// Current user accepted an incoming friend request. No payload; no PII.
  static const String friendRequestAccepted = 'friend_request_accepted';

  /// Current user declined an incoming friend request. No payload; no PII.
  static const String friendRequestDeclined = 'friend_request_declined';

  /// Current user withdrew their own outgoing friend request. No payload; no PII.
  static const String friendRequestWithdrawn = 'friend_request_withdrawn';

  /// Current user unfriended an existing friend. No payload; no PII.
  static const String friendUnfriended = 'friend_unfriended';

  // ── Profile ───────────────────────────────────────────────────────────────
  /// Current user viewed their own profile screen.
  static const String profileViewedOwn = 'profile_viewed_own';

  /// Current user viewed another user's profile screen. No PII.
  static const String profileViewedOther = 'profile_viewed_other';

  /// Current user saved changes from the edit-profile sheet.
  static const String profileEdited = 'profile_edited';

  /// Current user confirmed image selection; fired before compression begins.
  /// No payload; no PII.
  static const String avatarUploadStarted = 'avatar_upload_started';

  /// Firestore photoUrl write succeeded after avatar upload.
  /// Payload: file_size_bytes (int). No PII.
  static const String avatarUploadSucceeded = 'avatar_upload_succeeded';

  /// Avatar upload failed at any step (compression, storage, or Firestore).
  /// Payload: reason (String — 'compression_error' | 'storage_error' | 'firestore_error').
  /// No PII.
  static const String avatarUploadFailed = 'avatar_upload_failed';
}
