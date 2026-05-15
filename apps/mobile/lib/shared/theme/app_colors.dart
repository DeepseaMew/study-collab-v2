import 'package:flutter/material.dart';


abstract final class AppColors {
  // ── Background ────────────────────────────────────────────────────────────
  /// Main screen background
  static const Color background = Color(0xFF000000); 

  /// Card and surface background (slightly elevated from background)
  static const Color surface = Color(0xFF000000); 

  /// Secondary surface (chips, tags, avatar backgrounds)
  static const Color secondary = Color(0xFF000000); 

  // ── Brand ─────────────────────────────────────────────────────────────────
  /// Primary accent — buttons, links, active states, badges
  static const Color accent = Color(0xFF000000); 

  // ── Text ──────────────────────────────────────────────────────────────────
  /// Primary text — headings and body
  static const Color text = Color(0xFF000000); 

  /// Secondary text — subtitles, placeholders, captions
  static const Color hint = Color(0xFF000000); 

  // ── Semantic ──────────────────────────────────────────────────────────────
  /// Error states — validation messages, error banners
  static const Color error = Color(0xFF000000); 

  /// Success states — snackbars, verified badges
  static const Color success = Color(0xFF000000); 

  // ── Border ────────────────────────────────────────────────────────────────
  /// Default border — input fields, cards, dividers
  static const Color border = Color(0xFF000000); 
}