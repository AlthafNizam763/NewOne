import 'package:flutter/material.dart';

/// Neo-brutalist palette: near-black surfaces, a punchy acid-lime primary,
/// a hot coral secondary, and high-contrast "paper" borders/shadows.
class AppColors {
  static const Color backgroundDark = Color(0xFF0A0C0B);
  static const Color surfaceDark = Color(0xFF15181A);
  static const Color elevatedDark = Color(0xFF1F2326);
  static const Color backgroundLight = Color(0xFFF3F1E7);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color elevatedLight = Color(0xFFECEADD);

  static const Color primaryDark = Color(0xFFC8FF3D);
  static const Color primaryLight = Color(0xFF8FCC00);
  static const Color primaryGlow = Color(0xFFE3FF8C);
  static const Color secondaryDark = Color(0xFFFF5C39);
  static const Color secondaryLight = Color(0xFFD6431F);
  static const Color accent = Color(0xFF4D7CFF);

  static const Color textPrimary = Color(0xFFF7F6EF);
  static const Color textSecondary = Color(0xFF9AA39B);
  static const Color textDark = Color(0xFF0E1110);
  static const Color textMutedLight = Color(0xFF5C6660);
  static const Color outlineDark = Color(0xFF2E3633);
  static const Color outlineLight = Color(0xFFDCE4DE);
  static const Color error = Color(0xFFFF5E5E);
  static const Color success = Color(0xFF4DE3A0);
  static const Color warning = Color(0xFFFFC93D);

  /// High-contrast "paper" border used on brutalist cards/buttons against dark surfaces.
  static const Color borderStrong = Color(0xFFF2F0E6);

  /// Signature flat, unblurred drop-shadow color for brutalist surfaces.
  static const Color hardShadow = primaryDark;

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryDark, secondaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    colors: [backgroundDark, Color(0xFF101312), Color(0xFF0C0E0D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
