import 'package:flutter/material.dart';

/// Telegram-inspired glassmorphism palette. Dark fields are the primary
/// (and most-used) palette; Light* fields back [AppTheme.lightTheme].
class AppColors {
  // ---- Dark surfaces ----
  static const Color backgroundDark = Color(0xFF0E1621);
  static const Color backgroundDarkAlt = Color(0xFF17212B);
  static const Color surfaceDark = Color(0xFF17212B);
  static const Color elevatedDark = Color(0xFF202B36);

  // ---- Light surfaces ----
  static const Color backgroundLight = Color(0xFFEFF3F6);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color elevatedLight = Color(0xFFF3F5F8);

  // ---- Brand ----
  static const Color primaryDark = Color(0xFF2AABEE);
  static const Color primaryLight = Color(0xFF229ED9);
  static const Color primaryGlow = Color(0xFF6FC8FF);
  static const Color secondaryDark = Color(0xFF7C5CFC);
  static const Color secondaryLight = Color(0xFF6A4CE0);
  static const Color accent = Color(0xFF34D1A0);

  // ---- Chat bubbles (Telegram-adjacent, not copied) ----
  static const Color myBubbleDark = Color(0xFF2B5278);
  static const Color partnerBubbleDark = Color(0xFF182533);
  static const Color myBubbleLight = Color(0xFFDCEEFF);
  static const Color partnerBubbleLight = Color(0xFFFFFFFF);

  // ---- Text ----
  static const Color textPrimary = Color(0xFFE9EEF3);
  static const Color textSecondary = Color(0xFF7C8C9A);
  static const Color textDark = Color(0xFF101418);
  static const Color textOnLight = Color(0xFF1C2733);
  static const Color textMutedLight = Color(0xFF6B7785);

  // ---- Outlines / status ----
  static const Color outlineDark = Color(0xFF263240);
  static const Color outlineLight = Color(0xFFE2E6EA);
  static const Color error = Color(0xFFFF5C5C);
  static const Color success = Color(0xFF4FD1A5);
  static const Color warning = Color(0xFFFFC857);

  // ---- Glass tokens ----
  /// Thin translucent edge for glass panels on dark surfaces.
  static const Color borderStrong = Color(0x29FFFFFF); // white @ 16%
  static const Color borderLight = Color(0x33000000); // black @ 20%
  static const Color glassTintDark = Color(0x0FFFFFFF); // white @ 6%
  static const Color glassTintLight = Color(0x8CFFFFFF); // white @ 55%

  /// Soft, blurred drop-shadow base color for elevated glass surfaces.
  static const Color hardShadow = Color(0x59000A14);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryDark, secondaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    colors: [Color(0xFF0B121B), backgroundDark, Color(0xFF101A26)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lightBackgroundGradient = LinearGradient(
    colors: [Color(0xFFF6F9FC), backgroundLight, Color(0xFFEDF1F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
