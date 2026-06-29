import 'package:flutter/material.dart';

/// Premium Black & White Glassmorphism palette.
///
/// Design principle: color is expressed through contrast, depth, and material
/// texture rather than hue. White is the primary accent on dark surfaces;
/// near-black on light surfaces. Error / success / warning retain saturation
/// for functional legibility.
class AppColors {
  // ── Dark mode surfaces ────────────────────────────────────────────────────
  /// Page canvas — near-pure black so glass panels appear to float.
  static const Color backgroundDark    = Color(0xFF080808);
  /// Slightly lifted variant used in alternating sections.
  static const Color backgroundDarkAlt = Color(0xFF0F0F0F);
  /// Frosted glass card base.
  static const Color surfaceDark       = Color(0xFF141414);
  /// Text-field fills, chips, and raised interactive surfaces.
  static const Color elevatedDark      = Color(0xFF1E1E1E);

  // ── Light mode surfaces ──────────────────────────────────────────────────
  static const Color backgroundLight  = Color(0xFFF7F7F7);
  static const Color surfaceLight     = Color(0xFFFFFFFF);
  static const Color elevatedLight    = Color(0xFFEFEFEF);

  // ── Primary accent ────────────────────────────────────────────────────────
  /// White — the CTA "color" on dark surfaces.
  static const Color primaryDark   = Color(0xFFFFFFFF);
  /// Near-black — the CTA "color" on light surfaces.
  static const Color primaryLight  = Color(0xFF0A0A0A);
  /// Light-gray accent — icon tint, secondary highlights, and badges.
  static const Color primaryGlow   = Color(0xFFCCCCCC);

  // ── Secondary / muted tones ──────────────────────────────────────────────
  static const Color secondaryDark  = Color(0xFFAAAAAA); // medium-light gray
  static const Color secondaryLight = Color(0xFF555555); // medium-dark gray
  static const Color accent         = Color(0xFFCCCCCC); // soft highlight gray

  // ── Chat bubbles (monochrome) ─────────────────────────────────────────────
  static const Color myBubbleDark       = Color(0xFF242424); // charcoal — sent
  static const Color partnerBubbleDark  = Color(0xFF181818); // darker — received
  static const Color myBubbleLight      = Color(0xFF0A0A0A); // black sent bubble
  static const Color partnerBubbleLight = Color(0xFFEAEAEA); // light-gray received
  /// Send-button accent. Chat screen overrides per brightness for icon contrast.
  static const Color waSendGreen        = Color(0xFFFFFFFF);

  // ── Text hierarchy ────────────────────────────────────────────────────────
  static const Color textPrimary    = Color(0xFFF2F2F2); // soft white
  static const Color textSecondary  = Color(0xFF888888); // mid gray
  static const Color textDark       = Color(0xFF0A0A0A); // near-black
  static const Color textOnLight    = Color(0xFF111111); // very dark
  static const Color textMutedLight = Color(0xFF888888); // mid gray

  // ── Outlines ─────────────────────────────────────────────────────────────
  static const Color outlineDark  = Color(0xFF2A2A2A);
  static const Color outlineLight = Color(0xFFE0E0E0);

  // ── Status (saturated for functional legibility) ─────────────────────────
  static const Color error   = Color(0xFFFF4444);
  static const Color success = Color(0xFF55BB6A);
  static const Color warning = Color(0xFFFFAA33);

  // ── Glassmorphism tokens ──────────────────────────────────────────────────
  /// Luminous edge on dark frosted panels — white @ 10 %.
  static const Color borderStrong   = Color(0x1AFFFFFF);
  /// Subtle edge on light frosted panels — black @ 8 %.
  static const Color borderLight    = Color(0x14000000);
  /// Frosted fill tint for dark glass — white @ 5 %.
  static const Color glassTintDark  = Color(0x0DFFFFFF);
  /// Frosted fill tint for light glass — white @ 80 %.
  static const Color glassTintLight = Color(0xCCFFFFFF);
  /// Deep pure-black drop shadow for depth cues.
  static const Color hardShadow     = Color(0x99000000);

  // ── Gradients ─────────────────────────────────────────────────────────────
  /// White-to-silver gradient — used for story rings, avatar borders, and
  /// any surface that needs a visible monochrome accent ring.
  /// Luminous on dark; still legible on light.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFF999999)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    colors: [Color(0xFF060606), Color(0xFF080808), Color(0xFF0E0E0E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lightBackgroundGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF7F7F7), Color(0xFFEEEEEE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
