import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/presence_service.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/utils/avatar_util.dart';
import '../../../../core/widgets/app_chrome.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../calls/presentation/providers/call_provider.dart';
import '../../../chat/presentation/providers/notify_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  String? _roomId;
  String? _partnerUid;
  bool _isPartnerOnline = false;
  bool _isLoadingRoom = true;

  StreamSubscription<User?>? _authSub;
  StreamSubscription? _partnerOnlineSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && mounted) {
        // Initialize presence for the current user
        ref.read(presenceServiceProvider).initialize(user.uid);
        _fetchRoomData(user.uid);
      } else if (mounted) {
        setState(() => _isLoadingRoom = false);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // PresenceService already has WidgetsBindingObserver wired to the same
    // lifecycle, so we do not need to duplicate calls here.
    super.didChangeAppLifecycleState(state);
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

      // Watch partner online status from Firebase Realtime Database for
      // accuracy (RTDB uses server-side onDisconnect, Firestore does not).
      await _partnerOnlineSub?.cancel();
      _partnerOnlineSub = ref
          .read(presenceServiceProvider)
          .watchPartnerOnline(partnerUid)
          .listen((isOnline) {
        if (!mounted) return;
        final wasOnline = _isPartnerOnline;
        setState(() => _isPartnerOnline = isOnline);

        // Fire the in-app + push notification if the notify flag is on
        if (!wasOnline && isOnline && ref.read(notifyWhenOnlineProvider)) {
          // Read partner name from Firestore for the notification
          FirebaseFirestore.instance
              .collection('users')
              .doc(partnerUid)
              .get()
              .then((snap) {
            if (!mounted) return;
            final username =
                snap.data()?['username'] as String? ?? 'Partner';
            ref
                .read(pushNotificationServiceProvider)
                .showOnlineNotification(username);
            // Auto-disable the flag after firing once
            ref.read(notifyWhenOnlineProvider.notifier).state = false;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$username is now online!')),
            );
          });
        }
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
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _partnerOnlineSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    // Detect incoming calls and navigate to the call screen
    ref.listen(incomingCallStreamProvider, (_, next) {
      next.whenData((callDoc) {
        if (callDoc == null) return;
        final data = callDoc.data();
        if (data == null) return;
        ref.read(callControllerProvider.notifier).setIncoming(
              callId: callDoc.id,
              callerId: data['callerId'] as String? ?? '',
              callerName: data['callerName'] as String? ?? 'Partner',
              type: data['type'] as String? ?? 'audio',
            );
        context.push('/call/${callDoc.id}');
      });
    });

    return Scaffold(
      extendBody: true,
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
      bottomNavigationBar: isDesktop
          ? null
          : SafeArea(
              minimum: const EdgeInsets.only(bottom: 12),
              child: _TelegramBottomNav(
                selectedIndex: _selectedIndex == 4 ? 2 : 0,
                avatarUid: FirebaseAuth.instance.currentUser?.uid,
                avatarEmail: FirebaseAuth.instance.currentUser?.email,
                notifyEnabled: ref.watch(notifyWhenOnlineProvider),
                onTap: (index) {
                  if (index == 0) setState(() => _selectedIndex = 0);
                  if (index == 1) context.push('/chat');
                  if (index == 2) setState(() => _selectedIndex = 4);
                  if (index == 3) context.push('/profile');
                },
                onNotifyTap: () => ref
                    .read(notifyWhenOnlineProvider.notifier)
                    .state = !ref.read(notifyWhenOnlineProvider),
              ),
            ),
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
                  style: Theme.of(context).textTheme.headlineSmall,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderStrong : AppColors.borderLight;
    return Container(
      width: 268,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.backgroundDarkAlt.withValues(alpha: 0.5)
            : AppColors.surfaceLight.withValues(alpha: 0.6),
        border: Border(right: BorderSide(color: borderColor)),
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
                  Text('Hisoka', style: Theme.of(context).textTheme.titleLarge),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Icon(icon,
            color: color ??
                (isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : AppColors.textSecondary)),
        title: Text(
          title,
          style: TextStyle(
              color: color ??
                  (isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : AppColors.textSecondary),
              fontWeight: FontWeight.w600),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppGlass.radiusPill),
        ),
        tileColor: isSelected ? AppColors.primaryDark : Colors.transparent,
        onTap: onTap ?? () => setState(() => _selectedIndex = index),
      ),
    );
  }

  Widget _buildProfileSidebarTile() {
    final currentUser = FirebaseAuth.instance.currentUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: UserAvatar(
          uid: currentUser?.uid,
          fallbackEmail: currentUser?.email,
          radius: 16,
        ),
        title:
            const Text('Profile', style: TextStyle(fontWeight: FontWeight.w600)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppGlass.radiusPill)),
        onTap: () => context.push('/profile'),
      ),
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
                Text('Hello, there.',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text(
                  'Chat, settings, and privacy controls are ready.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 18),
                AppButton(
                  label: 'Open Chat',
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
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppGlass.radius),
              boxShadow: AppGlass.softShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.4)),
            ),
            child:
                Icon(Icons.favorite_rounded,
                    color: Theme.of(context).colorScheme.onPrimary, size: 42),
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
    return AppSurface(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Stack(
          children: [
            UserAvatar(
              uid: _partnerUid,
              isPartner: true,
              radius: 28,
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
          style: const TextStyle(fontWeight: FontWeight.w700),
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
                      'Dark mode and display preferences',
                      () => context.push('/theme_settings')),
                  _buildSettingsTile(
                      Icons.storage_outlined,
                      'Storage & Data',
                      'Cache, auto-download and media quality',
                      () => context.push('/storage_data')),
                  _buildSettingsTile(Icons.language_rounded, 'App Language',
                      'Language preferences',
                      () => context.push('/language')),
                ],
              ),
              const SizedBox(height: 18),
              _buildSettingsGroup(
                'ABOUT',
                [
                  _buildSettingsTile(Icons.info_outline_rounded, 'About Hisoka',
                      'Version and app information',
                      () => context.push('/about')),
                  _buildSettingsTile(
                      Icons.help_outline_rounded,
                      'Help & Support',
                      'Troubleshooting and contact options',
                      () => context.push('/help_support')),
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
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

// ── Metric card content ───────────────────────────────────────────────────────

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
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 12),
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}

// ── Bottom navigation ─────────────────────────────────────────────────────────

/// Floating frosted-glass bottom navigation bar.
/// Contains icons-only nav pills (no text labels) plus a prominent
/// circular "notify when online" button between Chat and Settings.
class _TelegramBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final String? avatarUid;
  final String? avatarEmail;
  final bool notifyEnabled;
  final VoidCallback onNotifyTap;

  const _TelegramBottomNav({
    required this.selectedIndex,
    required this.onTap,
    this.avatarUid,
    required this.avatarEmail,
    required this.notifyEnabled,
    required this.onNotifyTap,
  });

  static const _items = [
    (icon: Icons.space_dashboard_rounded, label: 'Dashboard'),
    (icon: Icons.chat_bubble_rounded, label: 'Chat'),
    (icon: Icons.settings_rounded, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark
        ? AppColors.backgroundDarkAlt.withValues(alpha: 0.65)
        : AppColors.surfaceLight.withValues(alpha: 0.75);
    final border = isDark ? AppColors.borderStrong : AppColors.borderLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppGlass.radiusPill),
          boxShadow:
              AppGlass.softShadow(blur: 30, offset: const Offset(0, 14)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppGlass.radiusPill),
          child: BackdropFilter(
            filter: ImageFilter.blur(
                sigmaX: AppGlass.blurSigma, sigmaY: AppGlass.blurSigma),
            child: Container(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(AppGlass.radiusPill),
                border: Border.all(color: border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Dashboard
                  _NavPill(
                    icon: _items[0].icon,
                    label: _items[0].label,
                    selected: selectedIndex == 0,
                    onTap: () => onTap(0),
                  ),
                  // Chat
                  _NavPill(
                    icon: _items[1].icon,
                    label: _items[1].label,
                    selected: selectedIndex == 1,
                    onTap: () => onTap(1),
                  ),
                  // ── Notify button (centre) ─────────────────────────
                  _NotifyNavButton(
                    enabled: notifyEnabled,
                    onTap: onNotifyTap,
                  ),
                  // Settings
                  _NavPill(
                    icon: _items[2].icon,
                    label: _items[2].label,
                    selected: selectedIndex == 2,
                    onTap: () => onTap(2),
                  ),
                  // Profile avatar
                  _NavAvatarPill(
                    uid: avatarUid,
                    email: avatarEmail,
                    selected: selectedIndex == 3,
                    onTap: () => onTap(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon-only nav pill. Text labels have been removed for a cleaner look.
class _NavPill extends StatelessWidget {
  final IconData icon;
  final String label; // kept for tooltip/semantics only
  final bool selected;
  final VoidCallback onTap;

  const _NavPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.primaryGradient : null,
            borderRadius: BorderRadius.circular(AppGlass.radiusPill),
          ),
          child: Icon(
            icon,
            color: selected
                ? Theme.of(context).colorScheme.onPrimary
                : AppColors.textSecondary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// Circular "notify me when partner comes online" button.
/// Appears between Chat and Settings in the bottom nav.
class _NotifyNavButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _NotifyNavButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: enabled ? 'Disable online alert' : 'Notify when online',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: enabled ? AppColors.primaryGradient : null,
            color: enabled ? null : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: enabled
                  ? Colors.transparent
                  : AppColors.borderStrong,
              width: 1.5,
            ),
            boxShadow: enabled
                ? AppGlass.softShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.55),
                    blur: 14,
                    offset: const Offset(0, 5),
                  )
                : null,
          ),
          child: Icon(
            enabled
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            color: enabled
                ? Theme.of(context).colorScheme.onPrimary
                : AppColors.textSecondary,
            size: 21,
          ),
        ),
      ),
    );
  }
}

class _NavAvatarPill extends StatelessWidget {
  final String? uid;
  final String? email;
  final bool selected;
  final VoidCallback onTap;

  const _NavAvatarPill(
      {this.uid, required this.email, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: selected ? AppColors.primaryGradient : null,
          border: selected ? null : Border.all(color: AppColors.borderStrong),
        ),
        child: UserAvatar(
          uid: uid,
          fallbackEmail: email,
          radius: 15,
        ),
      ),
    );
  }
}
