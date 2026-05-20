/// Academic level of a KMUTT student.
///
/// Pure Dart — zero Flutter or Firebase imports.
enum AcademicLevel {
  undergraduate,
  graduate;

  /// Human-readable label shown in the UI.
  String get displayName => switch (this) {
    AcademicLevel.undergraduate => 'Undergraduate',
    AcademicLevel.graduate => 'Graduate',
  };

  /// Maximum student year for this level.
  int get maxYear => switch (this) {
    AcademicLevel.undergraduate => 4,
    AcademicLevel.graduate => 2,
  };

  /// Parses a raw Firestore string to [AcademicLevel].
  /// Falls back to [undergraduate] for unknown values.
  static AcademicLevel fromString(String value) =>
      AcademicLevel.values.firstWhere(
        (e) => e.name == value,
        orElse: () => AcademicLevel.undergraduate,
      );
}
