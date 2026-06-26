import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme_mode_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_chrome.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);
    final isDarkMode = themeMode == ThemeMode.dark;

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
                  const SectionLabel('APPEARANCE'),
                  AppSurface(
                    padding: EdgeInsets.zero,
                    child: SwitchListTile(
                      title: const Text('Dark Mode'),
                      subtitle:
                          const Text('Switch between the dark and light interface.'),
                      secondary: Icon(
                          isDarkMode
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          color: AppColors.primaryGlow),
                      value: isDarkMode,
                      onChanged: (value) {
                        ref
                            .read(themeModeControllerProvider.notifier)
                            .setDarkMode(value);
                      },
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
}
