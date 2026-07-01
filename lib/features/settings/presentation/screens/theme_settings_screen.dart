import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/appearance_provider.dart';
import '../../../../config/theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_chrome.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final notifier   = ref.read(appearanceProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Theme & Appearance')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
          children: [
            ResponsiveContent(
              padding: EdgeInsets.zero,
              maxWidth: 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Theme Mode ──────────────────────────────────────────────
                  const SectionLabel('THEME'),
                  AppSurface(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _modeCard(context, Icons.dark_mode_rounded,
                                'Dark', ThemeMode.dark,
                                appearance.themeMode,
                                () => notifier.setThemeMode(ThemeMode.dark)),
                            const SizedBox(width: 12),
                            _modeCard(context, Icons.light_mode_rounded,
                                'Light', ThemeMode.light,
                                appearance.themeMode,
                                () => notifier.setThemeMode(ThemeMode.light)),
                            const SizedBox(width: 12),
                            _modeCard(context, Icons.brightness_auto_rounded,
                                'System', ThemeMode.system,
                                appearance.themeMode,
                                () => notifier.setThemeMode(ThemeMode.system)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Accent Color ────────────────────────────────────────────
                  const SectionLabel('ACCENT COLOR'),
                  AppSurface(
                    padding: const EdgeInsets.all(20),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: kAccentPresets.map((p) {
                        final selected = appearance.accentHex == p.hex;
                        return GestureDetector(
                          onTap: () => notifier.setAccentColor(p.hex),
                          child: Tooltip(
                            message: p.label,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: p.color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: p.color.withValues(alpha: 0.5),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        )
                                      ]
                                    : [],
                              ),
                              child: selected
                                  ? const Icon(Icons.check_rounded,
                                      color: Colors.white, size: 20)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Font Themes ─────────────────────────────────────────────
                  const SectionLabel('FONT THEME'),
                  ...kFontThemes.map((info) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _FontThemeTile(
                          info: info,
                          selected: appearance.fontTheme == info.key,
                          onTap: () => notifier.setFontTheme(info.key),
                        ),
                      )),
                  const SizedBox(height: 12),

                  // ── Font Size ───────────────────────────────────────────────
                  const SectionLabel('FONT SIZE'),
                  AppSurface(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('A', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            Expanded(
                              child: Slider(
                                value: appearance.fontScale,
                                min: 0.8,
                                max: 1.4,
                                divisions: 6,
                                onChanged: notifier.setFontScale,
                              ),
                            ),
                            const Text('A', style: TextStyle(fontSize: 20, color: AppColors.textSecondary)),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '${(appearance.fontScale * 100).round()}% — Preview text at this size',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13 * appearance.fontScale,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Bubble Style ────────────────────────────────────────────
                  const SectionLabel('CHAT BUBBLE STYLE'),
                  AppSurface(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (int i = 0; i < kBubbleStyles.length; i++) ...[
                          _BubbleStyleTile(
                            info: kBubbleStyles[i],
                            selected: appearance.bubbleStyle ==
                                kBubbleStyles[i].key,
                            onTap: () =>
                                notifier.setBubbleStyle(kBubbleStyles[i].key),
                          ),
                          if (i < kBubbleStyles.length - 1)
                            const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Chat Wallpaper ──────────────────────────────────────────
                  const SectionLabel('CHAT WALLPAPER'),
                  AppSurface(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (int i = 0; i < kWallpapers.length; i++) ...[
                          ListTile(
                            leading: _WallpaperPreview(wallpaperKey: kWallpapers[i].key),
                            title: Text(kWallpapers[i].label),
                            trailing: appearance.wallpaperKey ==
                                    kWallpapers[i].key
                                ? const Icon(Icons.check_circle_rounded,
                                    color: AppColors.success)
                                : const Icon(
                                    Icons.radio_button_unchecked_rounded,
                                    color: AppColors.textSecondary),
                            onTap: () =>
                                notifier.setWallpaper(kWallpapers[i].key),
                          ),
                          if (i < kWallpapers.length - 1)
                            const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeCard(
    BuildContext context,
    IconData icon,
    String label,
    ThemeMode mode,
    ThemeMode current,
    VoidCallback onTap,
  ) {
    final selected = current == mode;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryGlow.withValues(alpha: 0.15)
                : AppColors.elevatedDark,
            borderRadius: BorderRadius.circular(AppGlass.radiusSmall),
            border: Border.all(
              color: selected
                  ? AppColors.primaryGlow
                  : AppColors.outlineDark,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected
                      ? AppColors.primaryGlow
                      : AppColors.textSecondary),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.primaryGlow
                        : AppColors.textSecondary,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Font Theme Tile ───────────────────────────────────────────────────────────

class _FontThemeTile extends StatelessWidget {
  final FontThemeInfo info;
  final bool selected;
  final VoidCallback onTap;

  const _FontThemeTile({
    required this.info,
    required this.selected,
    required this.onTap,
  });

  TextStyle _sampleStyle() {
    return switch (info.key) {
      kFontSpiderman => GoogleFonts.bangers(fontSize: 22, fontWeight: FontWeight.w400),
      kFontDracula   => GoogleFonts.cinzelDecorative(fontSize: 18, fontWeight: FontWeight.w600),
      kFontCyberpunk => GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.w600),
      kFontNeon      => GoogleFonts.exo2(fontSize: 18, fontWeight: FontWeight.w600),
      kFontMinimal   => GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w500),
      _              => GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
    };
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryGlow.withValues(alpha: 0.08)
              : AppColors.elevatedDark,
          borderRadius: BorderRadius.circular(AppGlass.radiusSmall),
          border: Border.all(
            color: selected ? AppColors.primaryGlow : AppColors.outlineDark,
          ),
        ),
        child: Row(
          children: [
            Icon(info.icon,
                color: selected
                    ? AppColors.primaryGlow
                    : AppColors.textSecondary,
                size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.label,
                      style: _sampleStyle().copyWith(
                        color: selected
                            ? AppColors.primaryGlow
                            : AppColors.textPrimary,
                      )),
                  const SizedBox(height: 2),
                  Text(info.description,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Bubble Style Tile ─────────────────────────────────────────────────────────

class _BubbleStyleTile extends StatelessWidget {
  final BubbleStyleInfo info;
  final bool selected;
  final VoidCallback onTap;

  const _BubbleStyleTile({
    required this.info,
    required this.selected,
    required this.onTap,
  });

  double get _radius {
    switch (info.key) {
      case kBubbleRounded: return 24;
      case kBubbleSharp:   return 6;
      case kBubbleMinimal: return 12;
      default:             return 18;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.elevatedDark,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(
            color: selected ? AppColors.primaryGlow : AppColors.outlineDark,
            width: info.key == kBubbleMinimal ? 1.5 : 0,
          ),
        ),
      ),
      title: Text(info.label),
      subtitle: Text(info.description,
          style: const TextStyle(color: AppColors.textSecondary)),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
          : const Icon(Icons.radio_button_unchecked_rounded,
              color: AppColors.textSecondary),
    );
  }
}

// ── Wallpaper Preview ─────────────────────────────────────────────────────────

class _WallpaperPreview extends StatelessWidget {
  final String wallpaperKey;
  const _WallpaperPreview({required this.wallpaperKey});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.elevatedDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineDark),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: wallpaperKey == kWallpaperDots
            ? CustomPaint(painter: _MiniDotsPainter())
            : wallpaperKey == kWallpaperGrid
                ? CustomPaint(painter: _MiniGridPainter())
                : wallpaperKey == kWallpaperBlobs
                    ? const _MiniBlobs()
                    : const Center(
                        child: Icon(Icons.block_rounded,
                            size: 16, color: AppColors.textSecondary)),
      ),
    );
  }
}

class _MiniDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    const s = 8.0;
    for (double x = s / 2; x < size.width; x += s) {
      for (double y = s / 2; y < size.height; y += s) {
        canvas.drawCircle(Offset(x, y), 1.0, p);
      }
    }
  }
  @override bool shouldRepaint(_) => false;
}

class _MiniGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 0.5;
    const s = 10.0;
    for (double x = 0; x < size.width; x += s) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += s) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }
  @override bool shouldRepaint(_) => false;
}

class _MiniBlobs extends StatelessWidget {
  const _MiniBlobs();
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -8, right: -8,
          child: Container(
            width: 30, height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x0DFFFFFF),
            ),
          ),
        ),
        Positioned(
          bottom: -8, left: -8,
          child: Container(
            width: 24, height: 24,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x08FFFFFF),
            ),
          ),
        ),
      ],
    );
  }
}
