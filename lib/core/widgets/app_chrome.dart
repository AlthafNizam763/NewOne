import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../constants/app_colors.dart';

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
    return Container(
      decoration:
          const BoxDecoration(gradient: AppColors.darkBackgroundGradient),
      child: SafeArea(
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}

/// A hard-edged, high-contrast card: thick "paper" border plus a flat,
/// unblurred offset shadow — the core neo-brutalist surface used everywhere.
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
    this.radius = AppBrutal.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(radius),
        border:
            Border.all(color: AppColors.borderStrong, width: AppBrutal.border),
        boxShadow: AppBrutal.hardShadow(shadowColor),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Small uppercase eyebrow label with a lime "tick" marker, used above
/// grouped content (settings groups, dashboard sections, etc).
class SectionLabel extends StatelessWidget {
  final String text;

  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 8),
            color: AppColors.primaryDark,
          ),
          Text(
            text.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class AppLogoMark extends StatelessWidget {
  final double size;

  const AppLogoMark({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final innerRadius = (AppBrutal.radius - AppBrutal.border).clamp(0, 100);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppBrutal.radius),
        border:
            Border.all(color: AppColors.borderStrong, width: AppBrutal.border),
        boxShadow: AppBrutal.hardShadow(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(innerRadius.toDouble()),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.forum_rounded,
            color: AppColors.textDark,
            size: size * 0.5,
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

/// Primary brutalist call-to-action: thick border, flat offset shadow that
/// compresses on press to mimic the button physically stamping down.
class BrutalButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final bool expand;
  final bool loading;

  const BrutalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.background = AppColors.primaryDark,
    this.foreground = AppColors.textDark,
    this.expand = true,
    this.loading = false,
  });

  @override
  State<BrutalButton> createState() => _BrutalButtonState();
}

class _BrutalButtonState extends State<BrutalButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onPressed == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final offset = _pressed ? const Offset(2, 2) : AppBrutal.shadowOffset;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        width: widget.expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        transform: Matrix4.translationValues(
          _pressed ? AppBrutal.shadowOffset.dx - 2 : 0,
          _pressed ? AppBrutal.shadowOffset.dy - 2 : 0,
          0,
        ),
        decoration: BoxDecoration(
          color: disabled ? AppColors.outlineDark : widget.background,
          borderRadius: BorderRadius.circular(AppBrutal.radius),
          border: Border.all(
              color: AppColors.borderStrong, width: AppBrutal.border),
          boxShadow: disabled
              ? const []
              : [
                  BoxShadow(
                    color: AppColors.borderStrong,
                    offset: offset,
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.loading) ...[
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: disabled ? AppColors.textSecondary : widget.foreground,
                ),
              ),
              const SizedBox(width: 10),
            ] else if (widget.icon != null) ...[
              Icon(widget.icon,
                  color:
                      disabled ? AppColors.textSecondary : widget.foreground),
              const SizedBox(width: 10),
            ],
            Text(
              widget.label,
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: disabled ? AppColors.textSecondary : widget.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
