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
}
