import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Font theme keys ───────────────────────────────────────────────────────────
const kFontDefault   = 'default';
const kFontMinimal   = 'minimal';
const kFontSpiderman = 'spiderman';
const kFontDracula   = 'dracula';
const kFontCyberpunk = 'cyberpunk';
const kFontNeon      = 'neon';

// ── Bubble style keys ─────────────────────────────────────────────────────────
const kBubbleDefault = 'default';
const kBubbleRounded = 'rounded';
const kBubbleSharp   = 'sharp';
const kBubbleMinimal = 'minimal';

// ── Wallpaper keys ────────────────────────────────────────────────────────────
const kWallpaperNone  = 'none';
const kWallpaperDots  = 'dots';
const kWallpaperGrid  = 'grid';
const kWallpaperBlobs = 'blobs';

// ── Accent color presets ──────────────────────────────────────────────────────
class AccentPreset {
  final String label;
  final Color color;
  final String hex;
  const AccentPreset(this.label, this.color, this.hex);
}

const kAccentPresets = <AccentPreset>[
  AccentPreset('Default',  Color(0xFFCCCCCC), 'CCCCCC'),
  AccentPreset('Rose',     Color(0xFFE05C7A), 'E05C7A'),
  AccentPreset('Sky',      Color(0xFF4EAADC), '4EAADC'),
  AccentPreset('Amber',    Color(0xFFFFAA33), 'FFAA33'),
  AccentPreset('Sage',     Color(0xFF55BB6A), '55BB6A'),
  AccentPreset('Lavender', Color(0xFFAA88DD), 'AA88DD'),
];

// ── Font theme metadata ───────────────────────────────────────────────────────
class FontThemeInfo {
  final String key;
  final String label;
  final String description;
  final IconData icon;
  const FontThemeInfo(this.key, this.label, this.description, this.icon);
}

const kFontThemes = <FontThemeInfo>[
  FontThemeInfo(kFontDefault,   'Inter',      'Clean and modern',       Icons.text_fields),
  FontThemeInfo(kFontMinimal,   'Minimal',    'Ultra-clean DM Sans',    Icons.notes_rounded),
  FontThemeInfo(kFontSpiderman, 'Spider-Man', 'Bold comic style',       Icons.flash_on),
  FontThemeInfo(kFontDracula,   'Dracula',    'Gothic elegance',        Icons.nights_stay),
  FontThemeInfo(kFontCyberpunk, 'Cyberpunk',  'Futuristic display',     Icons.memory_rounded),
  FontThemeInfo(kFontNeon,      'Neon',       'Sleek and electric',     Icons.bolt),
];

// ── Bubble style metadata ─────────────────────────────────────────────────────
class BubbleStyleInfo {
  final String key;
  final String label;
  final String description;
  const BubbleStyleInfo(this.key, this.label, this.description);
}

const kBubbleStyles = <BubbleStyleInfo>[
  BubbleStyleInfo(kBubbleDefault, 'Default',  'Balanced rounded corners'),
  BubbleStyleInfo(kBubbleRounded, 'Rounded',  'Pill-style soft bubbles'),
  BubbleStyleInfo(kBubbleSharp,   'Sharp',    'Minimal square edges'),
  BubbleStyleInfo(kBubbleMinimal, 'Minimal',  'Subtle thin-border style'),
];

// ── Wallpaper metadata ────────────────────────────────────────────────────────
class WallpaperInfo {
  final String key;
  final String label;
  const WallpaperInfo(this.key, this.label);
}

const kWallpapers = <WallpaperInfo>[
  WallpaperInfo(kWallpaperNone,  'None'),
  WallpaperInfo(kWallpaperDots,  'Dots'),
  WallpaperInfo(kWallpaperGrid,  'Grid'),
  WallpaperInfo(kWallpaperBlobs, 'Blobs'),
];

// ── ThemeExtension ────────────────────────────────────────────────────────────

class HisokaTheme extends ThemeExtension<HisokaTheme> {
  final Color accentColor;
  final double bubbleRadius;
  final String wallpaperKey;
  final String fontTheme;

  const HisokaTheme({
    required this.accentColor,
    required this.bubbleRadius,
    required this.wallpaperKey,
    required this.fontTheme,
  });

  @override
  HisokaTheme copyWith({
    Color? accentColor,
    double? bubbleRadius,
    String? wallpaperKey,
    String? fontTheme,
  }) =>
      HisokaTheme(
        accentColor:  accentColor  ?? this.accentColor,
        bubbleRadius: bubbleRadius ?? this.bubbleRadius,
        wallpaperKey: wallpaperKey ?? this.wallpaperKey,
        fontTheme:    fontTheme    ?? this.fontTheme,
      );

  @override
  HisokaTheme lerp(ThemeExtension<HisokaTheme>? other, double t) {
    if (other is! HisokaTheme) return this;
    return HisokaTheme(
      accentColor:  Color.lerp(accentColor, other.accentColor, t)!,
      bubbleRadius: lerpDouble(bubbleRadius, other.bubbleRadius, t)!,
      wallpaperKey: other.wallpaperKey,
      fontTheme:    other.fontTheme,
    );
  }

  static HisokaTheme of(BuildContext context) =>
      Theme.of(context).extension<HisokaTheme>() ??
      const HisokaTheme(
        accentColor:  Color(0xFFCCCCCC),
        bubbleRadius: 18.0,
        wallpaperKey: kWallpaperNone,
        fontTheme:    kFontDefault,
      );
}

// ── State ─────────────────────────────────────────────────────────────────────

class AppearanceState {
  final ThemeMode themeMode;
  final String fontTheme;
  final double fontScale;
  final String accentHex;
  final String bubbleStyle;
  final String wallpaperKey;

  const AppearanceState({
    this.themeMode    = ThemeMode.dark,
    this.fontTheme    = kFontDefault,
    this.fontScale    = 1.0,
    this.accentHex    = 'CCCCCC',
    this.bubbleStyle  = kBubbleDefault,
    this.wallpaperKey = kWallpaperNone,
  });

  Color get accentColor {
    try {
      return Color(int.parse('FF$accentHex', radix: 16));
    } catch (_) {
      return const Color(0xFFCCCCCC);
    }
  }

  double get bubbleRadius {
    switch (bubbleStyle) {
      case kBubbleRounded: return 24.0;
      case kBubbleSharp:   return 6.0;
      case kBubbleMinimal: return 12.0;
      default:             return 18.0;
    }
  }

  AppearanceState copyWith({
    ThemeMode? themeMode,
    String? fontTheme,
    double? fontScale,
    String? accentHex,
    String? bubbleStyle,
    String? wallpaperKey,
  }) =>
      AppearanceState(
        themeMode:    themeMode    ?? this.themeMode,
        fontTheme:    fontTheme    ?? this.fontTheme,
        fontScale:    fontScale    ?? this.fontScale,
        accentHex:    accentHex    ?? this.accentHex,
        bubbleStyle:  bubbleStyle  ?? this.bubbleStyle,
        wallpaperKey: wallpaperKey ?? this.wallpaperKey,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AppearanceNotifier extends StateNotifier<AppearanceState> {
  AppearanceNotifier() : super(const AppearanceState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    int? modeIndex = prefs.getInt('appearance_theme_mode');
    if (modeIndex == null) {
      final legacyDark = prefs.getBool('dark_mode') ?? true;
      modeIndex = legacyDark ? 0 : 1;
    }
    state = AppearanceState(
      themeMode:    ThemeMode.values[modeIndex.clamp(0, 2)],
      fontTheme:    prefs.getString('appearance_font')       ?? kFontDefault,
      fontScale:    prefs.getDouble('appearance_font_scale') ?? 1.0,
      accentHex:    prefs.getString('appearance_accent')     ?? 'CCCCCC',
      bubbleStyle:  prefs.getString('appearance_bubble')     ?? kBubbleDefault,
      wallpaperKey: prefs.getString('appearance_wallpaper')  ?? kWallpaperNone,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('appearance_theme_mode', mode.index);
    await prefs.setBool('dark_mode', mode == ThemeMode.dark);
  }

  Future<void> setFontTheme(String font) async {
    state = state.copyWith(fontTheme: font);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appearance_font', font);
  }

  Future<void> setFontScale(double scale) async {
    state = state.copyWith(fontScale: scale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('appearance_font_scale', scale);
  }

  Future<void> setAccentColor(String hex) async {
    state = state.copyWith(accentHex: hex);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appearance_accent', hex);
  }

  Future<void> setBubbleStyle(String style) async {
    state = state.copyWith(bubbleStyle: style);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appearance_bubble', style);
  }

  Future<void> setWallpaper(String key) async {
    state = state.copyWith(wallpaperKey: key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appearance_wallpaper', key);
  }
}

final appearanceProvider =
    StateNotifierProvider<AppearanceNotifier, AppearanceState>(
        (ref) => AppearanceNotifier());
