import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_chrome.dart';

class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  bool _isDarkMode = true;
  String _selectedStyle = 'Modern Calm';

  final List<String> _styles = [
    'Modern Calm',
    'Midnight Glass',
    'Sakura Blush',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isDarkMode = prefs.getBool('dark_mode') ?? true;
      _selectedStyle = prefs.getString('app_style') ?? 'Modern Calm';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _isDarkMode);
    await prefs.setString('app_style', _selectedStyle);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Theme preference saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      subtitle: const Text('Use the focused dark interface.'),
                      secondary: const Icon(Icons.dark_mode_outlined,
                          color: AppColors.primaryGlow),
                      value: _isDarkMode,
                      onChanged: (value) {
                        setState(() => _isDarkMode = value);
                        _saveSettings();
                      },
                    ),
                  ),
                  const SizedBox(height: 22),
                  const SectionLabel('APP STYLE'),
                  AppSurface(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < _styles.length; i++) ...[
                          _buildStyleTile(_styles[i]),
                          if (i != _styles.length - 1) const Divider(height: 1),
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

  Widget _buildStyleTile(String style) {
    final isSelected = style == _selectedStyle;
    return ListTile(
      leading: _StyleSwatch(style: style),
      title: Text(style,
          style: TextStyle(
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500)),
      subtitle: _getStyleDescription(style),
      trailing: isSelected
          ? const Icon(Icons.check_rounded, color: AppColors.primaryGlow)
          : null,
      onTap: () {
        setState(() => _selectedStyle = style);
        _saveSettings();
      },
    );
  }

  Widget _getStyleDescription(String style) {
    switch (style) {
      case 'Modern Calm':
        return const Text('Charcoal, teal, and coral accents.');
      case 'Midnight Glass':
        return const Text('Deep surfaces with subtle translucency.');
      case 'Sakura Blush':
        return const Text('Soft warm accents for a gentler look.');
      default:
        return const SizedBox.shrink();
    }
  }
}

class _StyleSwatch extends StatelessWidget {
  final String style;

  const _StyleSwatch({required this.style});

  @override
  Widget build(BuildContext context) {
    final colors = switch (style) {
      'Midnight Glass' => const [Color(0xFF121212), Color(0xFF4C8BF5)],
      'Sakura Blush' => const [Color(0xFFFFE5EA), Color(0xFFFF7A9A)],
      _ => const [AppColors.primaryDark, AppColors.secondaryDark],
    };

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(colors: colors),
        border: Border.all(color: AppColors.outlineDark),
      ),
    );
  }
}
