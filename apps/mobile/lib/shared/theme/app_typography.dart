import 'package:flutter/material.dart';

/// App typography for Study Collab.
/// Source: Figma Design System — Typography panel (Poppins).
/// Do not change values without updating Figma first.
///
/// Usage: Theme.of(context).textTheme.displayLarge etc.
/// Never hardcode fontSize or fontWeight outside this file.
abstract final class AppTypography {
  static const String _family = 'Poppins';

  static const TextTheme textTheme = TextTheme(
    // ── Headline 1 — 40px · 700 · lh 1.2 · hero / splash ───────────────────
    displayLarge: TextStyle(
      fontFamily: _family,
      fontSize: 40,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),

    // ── Headline 2 — 24px · 600 · lh 1.35 · screen titles ──────────────────
    displayMedium: TextStyle(
      fontFamily: _family,
      fontSize: 24,
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),

    // ── Headline Small — 18px · 500 · lh 1.4 · section headers ─────────────
    displaySmall: TextStyle(
      fontFamily: _family,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      height: 1.4,
    ),

    // ── Title Large — 16px · 600 · lh 1.5 · card titles ────────────────────
    titleLarge: TextStyle(
      fontFamily: _family,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.5,
    ),

    // ── Body Large — 16px · 400 · lh 1.6 · paragraphs ──────────────────────
    bodyLarge: TextStyle(
      fontFamily: _family,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.6,
    ),

    // ── Body Medium — 14px · 400 · lh 1.6 · descriptions ───────────────────
    bodyMedium: TextStyle(
      fontFamily: _family,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.6,
    ),

    // ── Label Large — 14px · 500 · lh 1.4 · buttons / tags ─────────────────
    labelLarge: TextStyle(
      fontFamily: _family,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.4,
    ),

    // ── Label Small — 10px · 500 · lh 1.4 · captions / badges ──────────────
    labelSmall: TextStyle(
      fontFamily: _family,
      fontSize: 10,
      fontWeight: FontWeight.w500,
      height: 1.4,
    ),
  );
}
