abstract final class AnalyticsEvents {
  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String authSignUpStarted = 'auth_sign_up_started';
  static const String authSignUpCompleted = 'auth_sign_up_completed';
  static const String authSignInCompleted = 'auth_sign_in_completed';
  static const String authSignOut = 'auth_sign_out';
  static const String authVerifyEmailResend = 'auth_verify_email_resend';
  static const String authProfileSetupCompleted =
      'auth_profile_setup_completed';

  // No email value may appear in this event's payload — KMUTT domain only.
  static const String authKmuttDomainRejected = 'auth_kmutt_domain_rejected';
}
