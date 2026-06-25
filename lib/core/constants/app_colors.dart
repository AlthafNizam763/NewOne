import 'package:flutter/material.dart';

class AppColors {
  static const Color backgroundDark = Color(0xFF101413);
  static const Color surfaceDark = Color(0xFF181D1B);
  static const Color elevatedDark = Color(0xFF202724);
  static const Color backgroundLight = Color(0xFFF7F8F4);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color elevatedLight = Color(0xFFF0F3EE);

  static const Color primaryDark = Color(0xFF31C6B0);
  static const Color primaryLight = Color(0xFF0E8E7E);
  static const Color primaryGlow = Color(0xFF61D7C5);
  static const Color secondaryDark = Color(0xFFFF8A6A);
  static const Color secondaryLight = Color(0xFFD95F43);
  static const Color accent = Color(0xFFF8C15A);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9EA9A3);
  static const Color textDark = Color(0xFF17201D);
  static const Color textMutedLight = Color(0xFF64716B);
  static const Color outlineDark = Color(0xFF2B3531);
  static const Color outlineLight = Color(0xFFDCE4DE);
  static const Color error = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF42D392);
  static const Color warning = Color(0xFFF8C15A);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryDark, secondaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    colors: [backgroundDark, Color(0xFF151917), Color(0xFF111615)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
