import 'package:flutter/material.dart';

/// Colors pulled directly from the Guclyft Stitch design system.
class AppColors {
  AppColors._();

  // Primary - Yellow
  static const Color primary = Color(0xFFFACC15);
  static const Color primaryDark = Color(0xFF3D2E00);

  // Secondary - Red
  static const Color secondary = Color(0xFFEF4444);
  static const Color secondaryDark = Color(0xFF450A0A);

  // Tertiary - Cyan (accent, used sparingly)
  static const Color tertiary = Color(0xFF31E4FF);
  static const Color tertiaryDark = Color(0xFF003641);

  // Neutrals
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);

  static const Color background = Color(0xFFF5F5F7); // app background (light gray)
  static const Color surface = Color(0xFFFFFFFF);     // cards
  static const Color surfaceMuted = Color(0xFFEDEDED); // pill/input backgrounds

  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color border = Color(0xFFE2E2E2);

  // Status colors seen in Admin Dashboard
  static const Color success = Color(0xFF16A34A); // "Verified" badge
  static const Color warning = Color(0xFFF59E0B); // "Pending" badge
  static const Color danger = secondary;           // "Review" badge / destructive
}
