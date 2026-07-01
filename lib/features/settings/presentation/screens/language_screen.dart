import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_chrome.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selected = 'en';
  String _search   = '';
  final _searchCtrl = TextEditingController();

  static const _languages = [
    (code: 'en', name: 'English',    native: 'English'),
    (code: 'es', name: 'Spanish',    native: 'Español'),
    (code: 'fr', name: 'French',     native: 'Français'),
    (code: 'de', name: 'German',     native: 'Deutsch'),
    (code: 'pt', name: 'Portuguese', native: 'Português'),
    (code: 'it', name: 'Italian',    native: 'Italiano'),
    (code: 'ru', name: 'Russian',    native: 'Русский'),
    (code: 'ja', name: 'Japanese',   native: '日本語'),
    (code: 'ko', name: 'Korean',     native: '한국어'),
    (code: 'zh', name: 'Chinese',    native: '中文'),
    (code: 'ar', name: 'Arabic',     native: 'العربية'),
    (code: 'hi', name: 'Hindi',      native: 'हिंदी'),
    (code: 'tr', name: 'Turkish',    native: 'Türkçe'),
    (code: 'nl', name: 'Dutch',      native: 'Nederlands'),
    (code: 'pl', name: 'Polish',     native: 'Polski'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _selected = prefs.getString('app_language') ?? 'en');
  }

  Future<void> _select(String code) async {
    setState(() => _selected = code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Language saved. Restart the app to apply.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _languages
        .where((l) =>
            _search.isEmpty ||
            l.name.toLowerCase().contains(_search.toLowerCase()) ||
            l.native.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('App Language')),
      body: AppBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: AppSurface(
                padding: EdgeInsets.zero,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Search language…',
                    prefixIcon: Icon(Icons.search_rounded),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
                itemCount: filtered.length + 1, // +1 for header
                separatorBuilder: (_, __) => const SizedBox.shrink(),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppSurface(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 18, color: AppColors.textSecondary),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Hisoka currently supports English. More languages coming soon. Your selection will be applied on next restart.',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fade(duration: 300.ms),
                    );
                  }
                  final lang = filtered[i - 1];
                  final isSelected = _selected == lang.code;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppSurface(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        onTap: () => _select(lang.code),
                        title: Text(lang.native,
                            style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500)),
                        subtitle: Text(lang.name,
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded,
                                color: AppColors.success)
                            : const Icon(
                                Icons.radio_button_unchecked_rounded,
                                color: AppColors.textSecondary),
                      ),
                    ).animate().fade(
                        delay: Duration(milliseconds: 20 * (i - 1))),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
