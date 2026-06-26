import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/avatar_util.dart';
import '../../../../core/widgets/app_chrome.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  String? _roomId;
  String? _partnerUid;
  bool _isPartnerOnline = false;
  bool _isLoadingRoom = true;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _partnerOnlineSub;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && mounted) {
        _fetchRoomData(user.uid);
      } else if (mounted) {
        setState(() => _isLoadingRoom = false);
      }
    });
  }

  Future<void> _fetchRoomData(String uid) async {
    setState(() => _isLoadingRoom = true);
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted) return;

      final partnerUid = doc.data()?['partnerUid'] as String?;
      if (partnerUid == null || partnerUid.isEmpty) {
        setState(() {
          _partnerUid = null;
          _roomId = null;
          _isLoadingRoom = false;
        });
        return;
      }

      await _partnerOnlineSub?.cancel();
      _partnerOnlineSub = FirebaseFirestore.instance
          .collection('users')
          .doc(partnerUid)
          .snapshots()
          .listen((snap) {
        if (!mounted || !snap.exists) return;
        setState(() => _isPartnerOnline = snap.data()?['isOnline'] == true);
      });

      setState(() {
        _partnerUid = partnerUid;
        _roomId = uid.compareTo(partnerUid) < 0
            ? '${uid}_$partnerUid'
            : '${partnerUid}_$uid';
        _isLoadingRoom = false;
      });
    } catch (error) {
      debugPrint('Error fetching room data: $error');
      if (mounted) setState(() => _isLoadingRoom = false);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _partnerOnlineSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      body: AppBackground(
        child: Row(
          children: [
            if (isDesktop) _buildSidebar(),
            Expanded(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: _selectedIndex == 4
                        ? _buildSettings()
                        : _buildDashboard(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isDesktop ? null : _buildBottomNav(),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedIndex == 4 ? 'Settings' : 'Dashboard',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedIndex == 4
                      ? 'Manage your private app preferences.'
                      : 'Your private space at a glance.',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => context.push('/notification_settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 268,
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(
            right: BorderSide(color: AppColors.borderStrong, width: 2)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AppLogoMark(size: 42),
                  const SizedBox(width: 12),
                  Text('HISOKA',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2)),
                ],
              ),
              const SizedBox(height: 36),
              _buildSidebarItem(Icons.space_dashboard_rounded, 'Dashboard', 0),
              _buildSidebarItem(Icons.chat_bubble_rounded, 'Chat', 1,
                  onTap: () => context.push('/chat')),
              _buildSidebarItem(Icons.settings_rounded, 'Settings', 4),
              const Spacer(),
              _buildProfileSidebarTile(),
              const SizedBox(height: 8),
              _buildSidebarItem(
                Icons.logout_rounded,
                'Log Out',
                9,
                color: AppColors.error,
                onTap: () {
                  ref.read(authControllerProvider.notifier).logout();
                  context.go('/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, int index,
      {Color? color, VoidCallback? onTap}) {
    final isSelected = _selectedIndex == index;
    final itemColor = color ??
        (isSelected ? AppColors.textDark : AppColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: itemColor),
        title: Text(
          title,
          style: TextStyle(
              color: color ??
                  (isSelected ? AppColors.textDark : AppColors.textSecondary),
              fontWeight: FontWeight.w800),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBrutal.radius),
          side: isSelected
              ? const BorderSide(color: AppColors.borderStrong, width: 2)
              : BorderSide.none,
        ),
        tileColor: isSelected ? AppColors.primaryDark : Colors.transparent,
        onTap: onTap ?? () => setState(() => _selectedIndex = index),
      ),
    );
  }

  Widget _buildProfileSidebarTile() {
    final email = FirebaseAuth.instance.currentUser?.email;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.primaryDark,
          backgroundImage: AvatarUtil.getAvatarProvider(email),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBrutal.radius)),
        onTap: () => context.push('/profile'),
      ),
    );
  }

  Widget _buildBottomNav() {
    final email = FirebaseAuth.instance.currentUser?.email;
    return NavigationBar(
      backgroundColor: AppColors.surfaceDark,
      indicatorColor: AppColors.primaryDark.withValues(alpha: 0.2),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      selectedIndex: _selectedIndex == 4 ? 2 : 0,
      onDestinationSelected: (index) {
        if (index == 0) setState(() => _selectedIndex = 0);
        if (index == 1) context.push('/chat');
        if (index == 2) setState(() => _selectedIndex = 4);
        if (index == 3) context.push('/profile');
      },
      destinations: [
        const NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Dashboard'),
        const NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat'),
        const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings'),
        NavigationDestination(
          icon: CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primaryDark,
            backgroundImage: AvatarUtil.getAvatarProvider(email),
          ),
          selectedIcon: CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primaryGlow,
            backgroundImage: AvatarUtil.getAvatarProvider(email),
          ),
          label: 'Profile',
        ),
      ],
    );
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      color: AppColors.primaryDark,
      onRefresh: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) await _fetchRoomData(user.uid);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
        children: [
          ResponsiveContent(
            padding: EdgeInsets.zero,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 720;
                return Column(
                  children: [
                    _buildWelcomeCard(),
                    const SizedBox(height: 18),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildStatsCard()),
                          const SizedBox(width: 18),
                          Expanded(child: _buildPartnerCard()),
                        ],
                      )
                    else ...[
                      _buildStatsCard(),
                      const SizedBox(height: 18),
                      _buildPartnerCard(),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ).animate().fadeIn(duration: 360.ms),
    );
  }

  Widget _buildWelcomeCard() {
    return AppSurface(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('PRIVATE SPACE'),
                Text(
                  'Hello, there.',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Chat, settings, and privacy controls are ready.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 18),
                BrutalButton(
                  label: 'OPEN CHAT',
                  icon: Icons.chat_bubble_rounded,
                  expand: false,
                  onPressed: () => context.push('/chat'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: AppColors.secondaryDark,
              borderRadius: BorderRadius.circular(AppBrutal.radius),
              border: Border.all(
                  color: AppColors.borderStrong, width: AppBrutal.border),
              boxShadow: AppBrutal.hardShadow(AppColors.primaryDark),
            ),
            child: const Icon(Icons.favorite_rounded,
                color: AppColors.textDark, size: 42),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    if (_isLoadingRoom) {
      return const AppSurface(
        child: SizedBox(
          height: 112,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_roomId == null) {
      return const AppSurface(
        child: _MetricContent(
          icon: Icons.link_off_rounded,
          label: 'Messages',
          value: 'No room',
          subtitle: 'Pairing has not been completed yet.',
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(_roomId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final msgCount = data?['totalMessages']?.toString() ?? '0';
        return AppSurface(
          child: _MetricContent(
            icon: Icons.forum_rounded,
            label: 'Messages',
            value: msgCount,
            subtitle: 'Total messages in this room.',
          ),
        );
      },
    );
  }

  Widget _buildPartnerCard() {
    final email = FirebaseAuth.instance.currentUser?.email;
    return AppSurface(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primaryDark,
              backgroundImage: AvatarUtil.getPartnerAvatarProvider(email),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _isPartnerOnline
                      ? AppColors.success
                      : AppColors.textSecondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surfaceDark, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          _partnerUid == null
              ? 'No partner linked'
              : (_isPartnerOnline ? 'Partner is online' : 'Partner is offline'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          _partnerUid == null
              ? 'Complete account pairing to start chatting.'
              : 'Tap to continue the conversation.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: _partnerUid == null ? null : () => context.push('/chat'),
      ),
    );
  }

  Widget _buildSettings() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
      children: [
        ResponsiveContent(
          padding: EdgeInsets.zero,
          maxWidth: 760,
          child: Column(
            children: [
              _buildSettingsGroup(
                'ACCOUNT',
                [
                  _buildSettingsTile(
                      Icons.person_outline_rounded,
                      'Profile',
                      'Nickname, avatar, and profile details',
                      () => context.push('/profile')),
                  _buildSettingsTile(
                      Icons.security_rounded,
                      'Privacy & Security',
                      'Locking, read receipts, and visibility',
                      () => context.push('/privacy_settings')),
                ],
              ),
              const SizedBox(height: 18),
              _buildSettingsGroup(
                'PREFERENCES',
                [
                  _buildSettingsTile(
                      Icons.notifications_none_rounded,
                      'Notifications',
                      'Push alerts and tones',
                      () => context.push('/notification_settings')),
                  _buildSettingsTile(
                      Icons.palette_outlined,
                      'Theme & Appearance',
                      'Color and display preferences',
                      () => context.push('/theme_settings')),
                  _buildSettingsTile(Icons.language_rounded, 'App Language',
                      'Language preferences', () {}),
                ],
              ),
              const SizedBox(height: 18),
              _buildSettingsGroup(
                'ABOUT',
                [
                  _buildSettingsTile(Icons.info_outline_rounded, 'About Hisoka',
                      'Version and app information', () {}),
                  _buildSettingsTile(
                      Icons.help_outline_rounded,
                      'Help & Support',
                      'Troubleshooting and contact options',
                      () {}),
                ],
              ),
              const SizedBox(height: 18),
              _buildSettingsGroup(
                'SESSION',
                [
                  _buildSettingsTile(
                    Icons.logout_rounded,
                    'Log Out',
                    'Sign out of this account',
                    () {
                      ref.read(authControllerProvider.notifier).logout();
                      context.go('/login');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 320.ms);
  }

  Widget _buildSettingsGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(title),
        AppSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(
      IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryGlow),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _MetricContent extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;

  const _MetricContent({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primaryGlow, size: 22),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 12),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}
