import 'package:flutter/material.dart';

/// App color palette for Study Collab.
/// Source: Figma Design System — Color System panel.
/// Do not change values without updating Figma first.
abstract final class AppColors {
  // ── Background ────────────────────────────────────────────────────────────
  /// White — filled input backgrounds, overlays
  static const Color white = Color(0xFFFFFFFF);

  /// Main screen background
  static const Color background = Color(0xFFFFFFFF);

  /// Card and surface background
  static const Color secondary = Color(0xFFEDE9FE);

  /// Secondary hover state
  static const Color secondaryHover = Color(0xFFE3DCFF);

  // ── Brand ─────────────────────────────────────────────────────────────────
  /// Primary accent — buttons, links, active states
  static const Color accent = Color(0xFF894DEF);

  /// Accent hover state
  static const Color accentHover = Color(0xFF6F3EC2);

  // ── Neutrals ──────────────────────────────────────────────────────────────
  /// Border — input fields, cards, dividers
  static const Color border = Color(0xFFD4D4D4);

  /// Hint — placeholder text, secondary icons
  static const Color hint = Color(0xFF888888);

  /// Disabled — disabled inputs, inactive elements
  static const Color disabled = Color(0xFFDED8F7);

  // ── Text ──────────────────────────────────────────────────────────────────
  /// Primary text — headings and body
  static const Color text = Color(0xFF1A1A2E);

  // ── Semantic ──────────────────────────────────────────────────────────────
  /// Error states — validation messages, error banners
  static const Color error = Color(0xFFE53E3E);

  /// Success states — snackbars, verified badges
  static const Color success = Color(0xFF38A169);

  /// Warning states
  static const Color warning = Color(0xFFD69E2E);
}
