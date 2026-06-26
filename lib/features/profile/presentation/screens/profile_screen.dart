import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/avatar_util.dart';
import '../../../../core/widgets/app_chrome.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    final username = userEmail?.split('@')[0] ?? 'User';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
          children: [
            ResponsiveContent(
              padding: EdgeInsets.zero,
              maxWidth: 720,
              child: Column(
                children: [
                  AppSurface(
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.borderStrong,
                                width: AppBrutal.border),
                            boxShadow: AppBrutal.hardShadow(),
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: AppColors.primaryDark,
                            backgroundImage:
                                AvatarUtil.getAvatarProvider(userEmail),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          username,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userEmail ?? '',
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildSettingsTile(
                    icon: Icons.person_outline,
                    title: 'Change Nickname',
                    subtitle: 'Update your display name',
                    onTap: () => _notifyComingSoon(context, 'Nickname editing'),
                  ),
                  _buildSettingsTile(
                    icon: Icons.info_outline,
                    title: 'Change About',
                    subtitle: 'Write a short bio',
                    onTap: () => _notifyComingSoon(context, 'Bio editing'),
                  ),
                  _buildSettingsTile(
                    icon: Icons.camera_alt_outlined,
                    title: 'Change Profile Picture',
                    subtitle: 'Upload a new avatar',
                    onTap: () => _notifyComingSoon(context, 'Avatar upload'),
                  ),
                  _buildSettingsTile(
                    icon: Icons.link,
                    title: 'Add Link',
                    subtitle: 'Share your social profiles',
                    onTap: () => _notifyComingSoon(context, 'Social links'),
                  ),
                  _buildSettingsTile(
                    icon: Icons.storage_outlined,
                    title: 'Storage & Data',
                    subtitle: 'Network usage and auto-download',
                    onTap: () => _notifyComingSoon(context, 'Storage & data'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(authControllerProvider.notifier).logout();
                      context.go('/login');
                    },
                    icon: const Icon(Icons.logout, color: AppColors.error),
                    label: const Text('Log Out',
                        style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _notifyComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$feature is coming soon')));
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSurface(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.elevatedDark,
              borderRadius: BorderRadius.circular(AppBrutal.radius),
              border: Border.all(color: AppColors.outlineDark, width: 1.5),
            ),
            child: Icon(icon, color: AppColors.primaryGlow),
          ),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle,
              style: const TextStyle(color: AppColors.textSecondary)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}
