/// Compile-time feature flags for Study Collab.
///
/// Never hardcode feature availability inline — always gate behind a constant
/// from this file so flags can be audited and toggled in one place.
abstract final class FeatureFlags {
  /// Whether Google Calendar two-way sync is available to users.
  /// Set to [true] only after the GCal OAuth consent screen has been reviewed
  /// and approved for the production Firebase project.
  static const bool gcalSyncEnabled = true;

  /// Whether search enhancements (hashtag, academic level, student year filters)
  /// are available to users.
  static const bool searchEnhancementsEnabled = true;
}
