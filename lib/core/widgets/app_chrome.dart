import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../constants/app_colors.dart';

/// Soft gradient backdrop with a couple of blurred colour "blobs" — the
/// premium glass look reads best when there's something diffuse behind the
/// frosted panels, not a flat fill.
class AppBackground extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const AppBackground({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? AppColors.darkBackgroundGradient
            : AppColors.lightBackgroundGradient,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _glowBlob(AppColors.primaryDark.withValues(alpha: isDark ? 0.28 : 0.18)),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: _glowBlob(AppColors.secondaryDark.withValues(alpha: isDark ? 0.22 : 0.14)),
          ),
          SafeArea(
            child: Padding(
              padding: padding ?? EdgeInsets.zero,
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowBlob(Color color) {
    return AppGlass.blur(
      radius: 200,
      sigma: 80,
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

/// Frosted-glass card: blurred backdrop, translucent tint, thin soft edge,
/// and a diffuse drop shadow. The core building block reused everywhere.
class AppSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? shadowColor;
  final double radius;

  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.shadowColor,
    this.radius = AppGlass.radius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = color ??
        (isDark ? AppColors.backgroundDarkAlt.withValues(alpha: 0.55) : AppColors.surfaceLight.withValues(alpha: 0.72));
    final border = isDark ? AppColors.borderStrong : AppColors.borderLight;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppGlass.softShadow(color: shadowColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: AppGlass.blurSigma, sigmaY: AppGlass.blurSigma),
          child: Container(
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: border, width: AppGlass.borderWidth),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Small uppercase eyebrow label used above grouped content.
class SectionLabel extends StatelessWidget {
  final String text;

  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          color: isDark ? AppColors.primaryGlow : AppColors.primaryLight,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class AppLogoMark extends StatelessWidget {
  final double size;

  const AppLogoMark({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: AppGlass.softShadow(
          color: AppColors.primaryDark.withValues(alpha: 0.45),
          blur: 24,
          offset: const Offset(0, 10),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.32),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.chat_bubble_rounded,
            color: Colors.white,
            size: size * 0.46,
          ),
        ),
      ),
    );
  }
}

class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 1120,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Primary gradient call-to-action with a gentle press-scale animation.
class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient? gradient;
  final bool expand;
  final bool loading;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradient,
    this.expand = true,
    this.loading = false,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onPressed == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: widget.expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            gradient: disabled ? null : (widget.gradient ?? AppColors.primaryGradient),
            color: disabled ? AppColors.outlineDark : null,
            borderRadius: BorderRadius.circular(AppGlass.radiusPill),
            boxShadow: disabled
                ? const []
                : AppGlass.softShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.35),
                    blur: 22,
                    offset: const Offset(0, 8),
                  ),
          ),
          child: Row(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.loading) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 10),
              ] else if (widget.icon != null) ...[
                Icon(widget.icon,
                    color: disabled ? AppColors.textSecondary : Colors.white),
                const SizedBox(width: 10),
              ],
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: disabled ? AppColors.textSecondary : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
