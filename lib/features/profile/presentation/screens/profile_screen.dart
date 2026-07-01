import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../config/theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/avatar_util.dart';
import '../../../../core/widgets/app_chrome.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final _profileDocProvider =
    StreamProvider<DocumentSnapshot<Map<String, dynamic>>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots();
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploading = false;

  // ── Edit display username ─────────────────────────────────────────────────

  Future<void> _editNickname(String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Username'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Enter new display name',
                border: OutlineInputBorder(),
              ),
              maxLength: 30,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 4),
            const Text(
              'This changes only your display name. Your login username remains the same.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                final trimmed = ctrl.text.trim();
                if (trimmed.isNotEmpty) Navigator.pop(ctx, trimmed);
              },
              child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || !mounted) return;
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'username': result});
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Nickname updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Edit bio ───────────────────────────────────────────────────────────────

  Future<void> _editBio(String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Bio'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Write a short bio…',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || !mounted) return;
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'bio': result});
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Bio updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Change avatar ──────────────────────────────────────────────────────────

  Future<void> _changeAvatar() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ref = FirebaseStorage.instance
          .ref()
          .child('avatars/$uid/profile.jpg');

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        await ref.putData(bytes);
      } else {
        await ref.putFile(File(picked.path));
      }

      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'avatarUrl': url});

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile picture updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(_profileDocProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: AppBackground(
        child: profileAsync.when(
          data: (doc) {
            final data = doc.data() ?? {};
            final username = data['username'] as String? ??
                FirebaseAuth.instance.currentUser?.email?.split('@')[0] ??
                'User';
            final bio = data['bio'] as String? ?? '';
            final avatarUrl = data['avatarUrl'] as String?;
            final email =
                FirebaseAuth.instance.currentUser?.email ?? '';

            return ListView(
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
                            if (_isUploading)
                              const SizedBox(
                                  height: 100,
                                  child: Center(
                                      child: CircularProgressIndicator()))
                            else
                              GestureDetector(
                                onTap: _changeAvatar,
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: AppColors.primaryGradient,
                                        boxShadow: AppGlass.softShadow(
                                            color: AppColors.primaryDark
                                                .withValues(alpha: 0.4)),
                                      ),
                                      padding: const EdgeInsets.all(3),
                                      child: CircleAvatar(
                                        radius: 50,
                                        backgroundColor: AppColors.primaryDark,
                                        backgroundImage: avatarUrl != null
                                            ? NetworkImage(avatarUrl)
                                            : AvatarUtil.getAvatarProvider(
                                                email),
                                      ),
                                    ),
                                    Container(
                                      width: 30,
                                      height: 30,
                                      margin: const EdgeInsets.only(
                                          right: 2, bottom: 2),
                                      decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: AppColors.surfaceDark,
                                            width: 2),
                                      ),
                                      child: Icon(
                                          Icons.camera_alt_rounded,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                          size: 16),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),
                            Text(username,
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            if (bio.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(bio,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontStyle: FontStyle.italic),
                                  textAlign: TextAlign.center),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildSettingsTile(
                        icon: Icons.person_outline,
                        title: 'Change Username',
                        subtitle: username,
                        onTap: () => _editNickname(username),
                      ),
                      _buildSettingsTile(
                        icon: Icons.info_outline,
                        title: 'Change About',
                        subtitle: bio.isNotEmpty ? bio : 'Write a short bio',
                        onTap: () => _editBio(bio),
                      ),
                      _buildSettingsTile(
                        icon: Icons.camera_alt_outlined,
                        title: 'Change Profile Picture',
                        subtitle: 'Tap avatar or use this option',
                        onTap: _changeAvatar,
                      ),
                      _buildSettingsTile(
                        icon: Icons.storage_outlined,
                        title: 'Storage & Data',
                        subtitle: 'Cache, auto-download and media quality',
                        onTap: () => context.push('/storage_data'),
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
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
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
            decoration: const BoxDecoration(
              color: AppColors.elevatedDark,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryGlow),
          ),
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}
