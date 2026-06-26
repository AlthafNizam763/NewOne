import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_colors.dart';

/// Neo-brutalist design tokens shared across screens that build their own
/// decorations instead of relying purely on component themes below.
class AppBrutal {
  static const double border = 2.0;
  static const double borderThick = 2.5;
  static const double radius = 4.0;
  static const Offset shadowOffset = Offset(6, 6);
  static const Offset shadowOffsetSmall = Offset(3, 3);

  static List<BoxShadow> hardShadow([Color? color, Offset? offset]) => [
        BoxShadow(
          color: color ?? AppColors.hardShadow,
          offset: offset ?? shadowOffset,
          blurRadius: 0,
        ),
      ];
}

class AppTheme {
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final bodyTextTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );
    final textTheme = bodyTextTheme.copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(
          textStyle: bodyTextTheme.displayLarge, fontWeight: FontWeight.w800),
      displayMedium: GoogleFonts.spaceGrotesk(
          textStyle: bodyTextTheme.displayMedium,
          fontWeight: FontWeight.w800),
      displaySmall: GoogleFonts.spaceGrotesk(
          textStyle: bodyTextTheme.displaySmall, fontWeight: FontWeight.w800),
      headlineLarge: GoogleFonts.spaceGrotesk(
          textStyle: bodyTextTheme.headlineLarge,
          fontWeight: FontWeight.w800),
      headlineMedium: GoogleFonts.spaceGrotesk(
          textStyle: bodyTextTheme.headlineMedium,
          fontWeight: FontWeight.w800),
      headlineSmall: GoogleFonts.spaceGrotesk(
          textStyle: bodyTextTheme.headlineSmall, fontWeight: FontWeight.w800),
      titleLarge: GoogleFonts.spaceGrotesk(
          textStyle: bodyTextTheme.titleLarge, fontWeight: FontWeight.w700),
      titleMedium: GoogleFonts.spaceGrotesk(
          textStyle: bodyTextTheme.titleMedium, fontWeight: FontWeight.w700),
      titleSmall: GoogleFonts.spaceGrotesk(
          textStyle: bodyTextTheme.titleSmall, fontWeight: FontWeight.w700),
    );

    const brutalBorder = BorderSide(
      color: AppColors.borderStrong,
      width: AppBrutal.border,
    );
    final brutalShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppBrutal.radius),
      side: brutalBorder,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryDark,
        secondary: AppColors.secondaryDark,
        tertiary: AppColors.accent,
        surface: AppColors.surfaceDark,
        error: AppColors.error,
        onPrimary: AppColors.textDark,
        onSecondary: AppColors.textDark,
        onSurface: AppColors.textPrimary,
        outline: AppColors.borderStrong,
      ),
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 24),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surfaceDark,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBrutal.radius),
          side: const BorderSide(color: AppColors.outlineDark, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: AppColors.textDark,
          disabledBackgroundColor: AppColors.outlineDark,
          disabledForegroundColor: AppColors.textSecondary,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: brutalShape,
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: brutalBorder,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBrutal.radius)),
          textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryGlow,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBrutal.radius)),
          textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.elevatedDark,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBrutal.radius),
          borderSide: const BorderSide(color: AppColors.outlineDark, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBrutal.radius),
          borderSide: const BorderSide(color: AppColors.outlineDark, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBrutal.radius),
          borderSide:
              const BorderSide(color: AppColors.primaryDark, width: 2.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBrutal.radius),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBrutal.radius),
          borderSide: const BorderSide(color: AppColors.error, width: 2.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outlineDark,
        thickness: 1.5,
        space: 1.5,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primaryDark
              : AppColors.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primaryDark.withValues(alpha: 0.32)
              : AppColors.outlineDark,
        ),
        trackOutlineColor: WidgetStateProperty.all(AppColors.borderStrong),
        trackOutlineWidth: WidgetStateProperty.all(1.5),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primaryDark,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBrutal.radius),
          side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
        ),
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: states.contains(WidgetState.selected)
                ? AppColors.textDark
                : AppColors.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.textDark
                : AppColors.textSecondary,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: brutalShape,
        titleTextStyle: textTheme.titleLarge,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBrutal.radius),
          side: const BorderSide(color: AppColors.outlineDark, width: 1.5),
        ),
        textStyle: const TextStyle(color: AppColors.textPrimary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        shape: brutalShape,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryDark,
        circularTrackColor: AppColors.outlineDark,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDark,
        modalBackgroundColor: AppColors.surfaceDark,
        showDragHandle: true,
        dragHandleColor: AppColors.borderStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBrutal.radius),
          side: const BorderSide(color: AppColors.outlineDark, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.elevatedDark,
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBrutal.radius),
          side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
        ),
      ),
    );
  }
}
