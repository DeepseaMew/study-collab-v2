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

  // ── Note-Sharing ──────────────────────────────────────────────────────────

  /// A note file was successfully uploaded.
  /// Payload: mime_type (String, no PII), size_bytes (int).
  static const String noteUploaded = 'note_uploaded';

  /// A note file was successfully deleted. No payload.
  static const String noteDeleted = 'note_deleted';

  /// A note file was opened (url_launcher). No payload.
  static const String noteFileOpened = 'note_file_opened';

  /// A note upload failed at any step.
  /// Payload: error_type (String, no PII —
  ///   'file_too_large' | 'unsupported_mime' | 'upload_failed' | 'cap_reached').
  static const String noteUploadFailed = 'note_upload_failed';

  /// The "See All" button was tapped to open AllFilesScreen. No payload.
  static const String noteSeeAllOpened = 'note_see_all_opened';

  // ── Rating ────────────────────────────────────────────────────────────────

  /// User successfully submitted ratings after a session ended.
  /// Payload: ratee_count (int). No PII.
  static const String ratingSubmitted = 'rating_submitted';

  /// User dismissed the rating sheet without submitting. No payload.
  static const String ratingSkipped = 'rating_skipped';

  /// User tapped the rating banner card to open the rating sheet. No payload.
  static const String ratingBannerTapped = 'rating_banner_tapped';

  /// Rating submission failed.
  /// Payload: error_type (String, no PII).
  static const String ratingSubmitFailed = 'rating_submit_failed';

  // ── Search ────────────────────────────────────────────────────────────────

  /// User submitted a search query (keyword, hashtag, or filter chip).
  /// Payload: has_keyword (bool), has_hashtag (bool), has_level_filter (bool),
  ///          has_year_filter (bool), result_count (int). No PII.
  static const String searchPerformed = 'search_performed';

  /// User applied a filter chip (subject, quick-filter, academic level, etc.).
  /// Payload: filter_type (String — 'academic_level' | 'student_year' |
  ///          'hashtag' | 'today' | 'this_week' | 'my_level' | 'subject').
  /// No PII.
  static const String searchFilterApplied = 'search_filter_applied';

  /// User cleared all active search filters. No payload.
  static const String searchFilterCleared = 'search_filter_cleared';

  /// User tapped a session result card on the search screen. No payload.
  /// Session ID must not be logged.
  static const String searchResultTapped = 'search_result_tapped';

  /// User tapped the Retry button on the search error state. No payload.
  static const String searchRetryTapped = 'search_retry_tapped';

  // ── Calendar ───────────────────────────────────────────────────────────────

  /// User toggled the calendar view format (month ↔ week).
  static const String calendarViewFormatToggled =
      'calendar_view_format_toggled';

  /// User tapped a day cell on the calendar.
  static const String calendarDaySelected = 'calendar_day_selected';

  /// User tapped a session card on the calendar.
  static const String calendarSessionTapped = 'calendar_session_tapped';

  /// User successfully connected Google Calendar sync.
  static const String calendarSyncConnected = 'calendar_sync_connected';

  /// User disconnected Google Calendar sync.
  static const String calendarSyncDisconnected = 'calendar_sync_disconnected';

  /// A GCal sync operation completed successfully.
  static const String calendarSyncCompleted = 'calendar_sync_completed';

  /// A GCal sync operation failed.
  static const String calendarSyncFailed = 'calendar_sync_failed';
}
