import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/appearance_provider.dart';
import '../../config/theme.dart';
import '../constants/app_colors.dart';

// ── AppBackground ─────────────────────────────────────────────────────────────

/// Full-screen gradient canvas with very subtle monochrome depth blobs.
/// Near-pure-black (dark) / off-white (light) base makes glass panels float.
class AppBackground extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const AppBackground({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wallpaper = HisokaTheme.of(context).wallpaperKey;
    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? AppColors.darkBackgroundGradient
            : AppColors.lightBackgroundGradient,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -80,
            child: _blob(isDark ? const Color(0x07FFFFFF) : const Color(0x05000000)),
          ),
          Positioned(
            bottom: -120,
            left: -100,
            child: _blob(isDark ? const Color(0x05FFFFFF) : const Color(0x04000000)),
          ),
          if (wallpaper == kWallpaperBlobs) ...[
            Positioned(
              top: 200,
              left: -60,
              child: _blob(isDark ? const Color(0x05FFFFFF) : const Color(0x04000000)),
            ),
            Positioned(
              bottom: 200,
              right: -60,
              child: _blob(isDark ? const Color(0x04FFFFFF) : const Color(0x03000000)),
            ),
          ],
          if (wallpaper == kWallpaperDots)
            Positioned.fill(
              child: CustomPaint(
                painter: _DotsPainter(isDark: isDark),
              ),
            ),
          if (wallpaper == kWallpaperGrid)
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPainter(isDark: isDark),
              ),
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

  Widget _blob(Color color) {
    return AppGlass.blur(
      radius: 200,
      sigma: 80,
      child: Container(
        width: 280,
        height: 280,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  final bool isDark;
  const _DotsPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.045)
      ..style = PaintingStyle.fill;
    const spacing = 22.0;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.isDark != isDark;
}

class _GridPainter extends CustomPainter {
  final bool isDark;
  const _GridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04)
      ..strokeWidth = 0.8;
    const spacing = 32.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.isDark != isDark;
}

// ── AppSurface ────────────────────────────────────────────────────────────────

/// Frosted-glass card: BackdropFilter blur + translucent tint + luminous
/// border + deep shadow. Primary building block reused across every screen.
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
    // Dark: near-black at 60% → just enough tint to read as a separate layer
    // Light: near-opaque white → crisp glass card on off-white background
    final tint = color ?? (isDark
        ? AppColors.surfaceDark.withValues(alpha: 0.62)
        : AppColors.surfaceLight.withValues(alpha: 0.82));
    final border = isDark ? AppColors.borderStrong : AppColors.borderLight;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppGlass.softShadow(color: shadowColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: AppGlass.blurSigma, sigmaY: AppGlass.blurSigma),
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

// ── SectionLabel ──────────────────────────────────────────────────────────────

/// Small all-caps eyebrow label above grouped content.
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
          fontSize: 11,
          color: isDark ? AppColors.secondaryDark : AppColors.secondaryLight,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── AppLogoMark ───────────────────────────────────────────────────────────────

/// Logo container with a premium monochrome gradient and luminous edge.
class AppLogoMark extends StatelessWidget {
  final double size;
  const AppLogoMark({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF2A2A2A), Color(0xFF0A0A0A)]
              : const [Color(0xFF111111), Color(0xFF000000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(
          color: isDark ? AppColors.borderStrong : const Color(0x22000000),
          width: 1,
        ),
        boxShadow: AppGlass.softShadow(
          color: AppColors.hardShadow.withValues(alpha: 0.55),
          blur: 24,
          offset: const Offset(0, 10),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.32),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.chat_bubble_rounded,
            color: Colors.white,
            size: size * 0.46,
          ),
        ),
      ),
    );
  }
}

// ── ResponsiveContent ─────────────────────────────────────────────────────────

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
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

// ── AppButton ─────────────────────────────────────────────────────────────────

/// Primary CTA with context-aware B&W gradient and press-scale animation.
///   Dark  mode → white-to-light-gray gradient, black label.
///   Light mode → near-black-to-black gradient, white label.
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

  void _setPressed(bool v) {
    if (widget.onPressed == null) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final disabled = widget.onPressed == null;

    final gradient = widget.gradient ?? (isDark
        ? const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFDDDDDD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF1A1A1A), Color(0xFF080808)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ));

    // Content must contrast with the button fill
    final contentColor = disabled
        ? AppColors.textSecondary
        : (isDark ? Colors.black : Colors.white);

    return GestureDetector(
      onTapDown:   (_) => _setPressed(true),
      onTapUp:     (_) => _setPressed(false),
      onTapCancel: ()  => _setPressed(false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale:    _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve:    Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width:    widget.expand ? double.infinity : null,
          padding:  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            gradient: disabled ? null : gradient,
            color: disabled
                ? (isDark ? AppColors.outlineDark : AppColors.outlineLight)
                : null,
            borderRadius: BorderRadius.circular(AppGlass.radiusPill),
            boxShadow: disabled
                ? const []
                : AppGlass.softShadow(
                    color: AppColors.hardShadow
                        .withValues(alpha: isDark ? 0.30 : 0.18),
                    blur: 20,
                    offset: const Offset(0, 8),
                  ),
          ),
          child: Row(
            mainAxisSize:      widget.expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.loading) ...[
                SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: contentColor),
                ),
                const SizedBox(width: 10),
              ] else if (widget.icon != null) ...[
                Icon(widget.icon, color: contentColor),
                const SizedBox(width: 10),
              ],
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: contentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
