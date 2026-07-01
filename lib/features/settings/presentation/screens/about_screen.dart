import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_chrome.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About Hisoka')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
          children: [
            ResponsiveContent(
              padding: EdgeInsets.zero,
              maxWidth: 760,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Logo + version card
                  AppSurface(
                    child: Column(
                      children: [
                        const AppLogoMark(size: 80)
                            .animate()
                            .scale(duration: 400.ms, curve: Curves.easeOutBack),
                        const SizedBox(height: 16),
                        Text('Hisoka',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        const Text('Version 1.0.0 (Build 1)',
                            style: TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        const Text(
                          'Private messaging, calmly organized.',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ).animate().fade(duration: 300.ms).slideY(begin: 0.1),

                  const SizedBox(height: 22),
                  const SectionLabel('ABOUT'),
                  AppSurface(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _InfoTile(
                          icon: Icons.code_rounded,
                          title: 'Built with',
                          value: 'Flutter',
                        ),
                        const Divider(height: 1),
                        _InfoTile(
                          icon: Icons.architecture_rounded,
                          title: 'Architecture',
                          value: 'Clean Architecture + Riverpod',
                        ),
                        const Divider(height: 1),
                        _InfoTile(
                          icon: Icons.security_rounded,
                          title: 'End-to-end',
                          value: 'Encrypted',
                        ),
                      ],
                    ),
                  ).animate().fade(delay: 100.ms),

                  const SizedBox(height: 22),
                  const SectionLabel('LEGAL'),
                  AppSurface(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _NavTile(
                          icon: Icons.policy_outlined,
                          title: 'Privacy Policy',
                          onTap: () => _showDialog(context, 'Privacy Policy',
                              'Your messages are end-to-end secured. We do not sell or share your personal data with third parties. All data is stored securely on Firebase infrastructure.'),
                        ),
                        const Divider(height: 1),
                        _NavTile(
                          icon: Icons.gavel_rounded,
                          title: 'Terms of Service',
                          onTap: () => _showDialog(context, 'Terms of Service',
                              'By using Hisoka you agree to use the app only for lawful, personal communication. You may not use this app to harass, threaten, or harm others. We reserve the right to terminate accounts that violate these terms.'),
                        ),
                        const Divider(height: 1),
                        _NavTile(
                          icon: Icons.library_books_rounded,
                          title: 'Open Source Licenses',
                          onTap: () => showLicensePage(context: context),
                        ),
                      ],
                    ),
                  ).animate().fade(delay: 200.ms),

                  const SizedBox(height: 32),
                  const Text(
                    'Made with ♥ for private communication',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                    textAlign: TextAlign.center,
                  ).animate().fade(delay: 300.ms),
                  const SizedBox(height: 8),
                  const Text(
                    '© 2026 Hisoka. All rights reserved.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                    textAlign: TextAlign.center,
                  ).animate().fade(delay: 350.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDialog(BuildContext context, String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _InfoTile({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryGlow),
      title: Text(title),
      trailing: Text(value,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _NavTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryGlow),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
