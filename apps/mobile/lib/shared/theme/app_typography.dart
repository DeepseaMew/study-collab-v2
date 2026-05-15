import 'package:flutter/material.dart';

/// App typography for Study Collab.
/// Font: Poppins (Regular 400, Medium 500, SemiBold 600, Bold 700)
/// Font files must exist in assets/fonts/ and be declared in pubspec.yaml.
///
/// Usage: Theme.of(context).textTheme.displaySmall etc.
/// Never hardcode fontSize or fontWeight outside this file.
abstract final class AppTypography {
  static const String _family = 'Poppins';

  static const TextTheme textTheme = TextTheme(
    // ── Display ─────────────────────────────────────────────────────────────
    /// Large screen titles
    displayLarge: TextStyle(
      fontFamily: _family,
      fontSize: 32,
      fontWeight: FontWeight.w700, // Bold
      letterSpacing: -0.5,
    ),

    /// Section headings
    displayMedium: TextStyle(
      fontFamily: _family,
      fontSize: 26,
      fontWeight: FontWeight.w700, // Bold
      letterSpacing: -0.3,
    ),

    /// Card titles, greeting text
    displaySmall: TextStyle(
      fontFamily: _family,
      fontSize: 22,
      fontWeight: FontWeight.w600, // SemiBold
    ),

    // ── Headline ─────────────────────────────────────────────────────────────
    headlineMedium: TextStyle(
      fontFamily: _family,
      fontSize: 18,
      fontWeight: FontWeight.w600, // SemiBold
    ),

    headlineSmall: TextStyle(
      fontFamily: _family,
      fontSize: 16,
      fontWeight: FontWeight.w600, // SemiBold
    ),

    // ── Title ────────────────────────────────────────────────────────────────
    /// AppBar title, dialog title
    titleLarge: TextStyle(
      fontFamily: _family,
      fontSize: 16,
      fontWeight: FontWeight.w600, // SemiBold
    ),

    /// List item title, form labels
    titleMedium: TextStyle(
      fontFamily: _family,
      fontSize: 14,
      fontWeight: FontWeight.w500, // Medium
    ),

    titleSmall: TextStyle(
      fontFamily: _family,
      fontSize: 13,
      fontWeight: FontWeight.w500, // Medium
    ),

    // ── Body ─────────────────────────────────────────────────────────────────
    /// Default body text
    bodyLarge: TextStyle(
      fontFamily: _family,
      fontSize: 16,
      fontWeight: FontWeight.w400, // Regular
    ),

    /// Secondary body, subtitles, hints
    bodyMedium: TextStyle(
      fontFamily: _family,
      fontSize: 14,
      fontWeight: FontWeight.w400, // Regular
    ),

    /// Captions, timestamps, small labels
    bodySmall: TextStyle(
      fontFamily: _family,
      fontSize: 12,
      fontWeight: FontWeight.w400, // Regular
    ),

    // ── Label ────────────────────────────────────────────────────────────────
    /// Buttons
    labelLarge: TextStyle(
      fontFamily: _family,
      fontSize: 15,
      fontWeight: FontWeight.w600, // SemiBold
    ),

    labelMedium: TextStyle(
      fontFamily: _family,
      fontSize: 13,
      fontWeight: FontWeight.w500, // Medium
    ),

    labelSmall: TextStyle(
      fontFamily: _family,
      fontSize: 11,
      fontWeight: FontWeight.w500, // Medium
      letterSpacing: 0.5,
    ),
  );
}