import 'package:flutter/material.dart';

/// Colour palette exclusively for the onboarding carousel.
/// Kept separate from [AppColors] so the main app theme is untouched.
class OnboardingColors {
  OnboardingColors._();

  // ── Backgrounds ──────────────────────────────────────────────────────
  /// Deep plum / dark maroon — the dominant background.
  static const Color background = Color(0xFF1A0A14);

  /// Slightly lighter plum — used for input fields & cards.
  static const Color surface = Color(0xFF2A1A22);

  /// Subtle radial-glow tint layered over the background.
  static const Color glowCenter = Color(0xFF3A1828);

  // ── Typography ───────────────────────────────────────────────────────
  /// Warm off-white for serif headlines.
  static const Color headline = Color(0xFFF5EDE8);

  /// Muted lavender-gray for body / helper text.
  static const Color body = Color(0xFF9B8A94);

  /// Very muted for "Skip" / "I'll do this later".
  static const Color skip = Color(0xFF8A7078);

  // ── Accent ───────────────────────────────────────────────────────────
  /// Coral / salmon — CTA buttons, active dots, accent outlines.
  static const Color coral = Color(0xFFE8836B);

  /// Dark tone for text rendered *on top of* the coral button.
  static const Color coralText = Color(0xFF2A1210);

  // ── Inputs & Cards ───────────────────────────────────────────────────
  static const Color inputBorder = Color(0xFF4A3040);
  static const Color contactCard = Color(0xFF2A1A22);

  // ── Indicators ───────────────────────────────────────────────────────
  static const Color dotInactive = Color(0xFF4A3A42);

  // ── Tags ─────────────────────────────────────────────────────────────
  static const Color tagBorder = Color(0xFFE8836B);
}
