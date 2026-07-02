import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_colors.dart';
import 'appearance_provider.dart';

/// Shared glassmorphism design tokens used by screens that build their own
/// decorations instead of relying purely on the component themes below.
class AppGlass {
  static const double radius = 20.0;
  static const double radiusSmall = 14.0;
  static const double radiusPill = 999.0;
  static const double blurSigma = 24.0;
  static const double borderWidth = 1.0;

  static List<BoxShadow> softShadow({
    Color? color,
    double blur = 28,
    Offset offset = const Offset(0, 12),
  }) =>
      [
        BoxShadow(color: color ?? AppColors.hardShadow, blurRadius: blur, offset: offset),
      ];

  /// Wraps [child] in a frosted blur clipped to a rounded rect.
  static Widget blur({
    required Widget child,
    double radius = AppGlass.radius,
    double sigma = AppGlass.blurSigma,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: child,
      ),
    );
  }
}

class AppTheme {
  // Backward-compat getters (default appearance).
  static ThemeData get darkTheme  => forAppearance(Brightness.dark,  const AppearanceState());
  static ThemeData get lightTheme => forAppearance(Brightness.light, const AppearanceState());

  static ThemeData forAppearance(Brightness brightness, AppearanceState a) =>
      _build(brightness, a);

  static TextTheme _buildTextTheme(
      String fontKey, ThemeData base, Color onSurface, Color muted) {
    final raw = switch (fontKey) {
      kFontSpiderman => GoogleFonts.bangersTextTheme(base.textTheme),
      kFontDracula   => GoogleFonts.cinzelDecorativeTextTheme(base.textTheme),
      kFontCyberpunk => GoogleFonts.orbitronTextTheme(base.textTheme),
      kFontNeon      => GoogleFonts.exo2TextTheme(base.textTheme),
      kFontMinimal   => GoogleFonts.dmSansTextTheme(base.textTheme),
      _              => GoogleFonts.interTextTheme(base.textTheme),
    };
    final colored = raw.apply(bodyColor: onSurface, displayColor: onSurface);
    return colored.copyWith(
      headlineLarge:  colored.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
      headlineMedium: colored.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      headlineSmall:  colored.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge:     colored.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium:    colored.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall:     colored.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium:     colored.bodyMedium?.copyWith(color: onSurface),
      bodySmall:      colored.bodySmall?.copyWith(color: muted),
    );
  }

  static ThemeData _build(Brightness brightness, AppearanceState a) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(brightness: brightness, useMaterial3: true);

    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final elevated = isDark ? AppColors.elevatedDark : AppColors.elevatedLight;
    final onSurface = isDark ? AppColors.textPrimary : AppColors.textOnLight;
    final onSurfaceMuted =
        isDark ? AppColors.textSecondary : AppColors.textMutedLight;
    final outline = isDark ? AppColors.outlineDark : AppColors.outlineLight;
    final glassBorder = isDark ? AppColors.borderStrong : AppColors.borderLight;
    final primary   = a.accentColor;
    final secondary = isDark ? AppColors.secondaryDark : AppColors.secondaryLight;
    final onPrimary = a.accentColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    final textTheme = _buildTextTheme(a.fontTheme, base, onSurface, onSurfaceMuted);

    final pillShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppGlass.radiusPill),
    );
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppGlass.radius),
      side: BorderSide(color: glassBorder, width: AppGlass.borderWidth),
    );

    return base.copyWith(
      extensions: [
        HisokaTheme(
          accentColor:  a.accentColor,
          bubbleRadius: a.bubbleRadius,
          wallpaperKey: a.wallpaperKey,
          fontTheme:    a.fontTheme,
        ),
      ],
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: onPrimary,
        secondary: secondary,
        onSecondary: onPrimary,
        tertiary: AppColors.accent,
        onTertiary: onPrimary,
        surface: surface,
        onSurface: onSurface,
        surfaceContainerHighest: elevated,
        error: AppColors.error,
        onError: Colors.white,
        outline: outline,
      ),
      textTheme: textTheme,
      iconTheme: IconThemeData(color: onSurface, size: 24),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: bg,
        foregroundColor: onSurface,
        titleTextStyle:
            textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: outline,
          disabledForegroundColor: onSurfaceMuted,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: pillShape,
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: glassBorder),
          minimumSize: const Size.fromHeight(52),
          shape: pillShape,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: pillShape,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: elevated,
        hintStyle: TextStyle(color: onSurfaceMuted),
        prefixIconColor: onSurfaceMuted,
        suffixIconColor: onSurfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppGlass.radiusSmall),
          borderSide: BorderSide(color: glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppGlass.radiusSmall),
          borderSide: BorderSide(color: glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppGlass.radiusSmall),
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppGlass.radiusSmall),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppGlass.radiusSmall),
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: onSurfaceMuted,
        textColor: onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppGlass.radiusSmall),
        ),
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? primary : onSurfaceMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary.withValues(alpha: 0.4)
              : outline,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppGlass.radiusPill),
        ),
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected) ? onPrimary : onSurfaceMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? onPrimary : onSurfaceMuted,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: cardShape,
        titleTextStyle: textTheme.titleLarge,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppGlass.radiusSmall),
          side: BorderSide(color: glassBorder),
        ),
        textStyle: TextStyle(color: onSurface),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 4,
        shape: const CircleBorder(),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        circularTrackColor: outline,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        showDragHandle: true,
        dragHandleColor: glassBorder,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppGlass.radius)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: elevated,
        contentTextStyle: textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppGlass.radiusSmall),
          side: BorderSide(color: glassBorder),
        ),
      ),
    );
  }
}
