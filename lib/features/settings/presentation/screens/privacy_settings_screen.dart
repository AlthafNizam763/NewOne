import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_chrome.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _appLockEnabled = true;
  bool _readReceipts = true;
  bool _onlineStatus = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _appLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
      _readReceipts = prefs.getBool('read_receipts') ?? true;
      _onlineStatus = prefs.getBool('online_status') ?? true;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Security')),
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
                  const SectionLabel('SECURITY'),
                  AppSurface(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('App Lock'),
                          subtitle: const Text(
                              'Require device authentication to open messages.'),
                          secondary: const Icon(Icons.lock_outline_rounded,
                              color: AppColors.primaryGlow),
                          value: _appLockEnabled,
                          onChanged: (value) {
                            setState(() => _appLockEnabled = value);
                            _saveBool('app_lock_enabled', value);
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.visibility_off_outlined,
                              color: AppColors.primaryGlow),
                          title: const Text('Hidden Chats'),
                          subtitle:
                              const Text('Chats hidden from the main list.'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const SectionLabel('PRIVACY'),
                  AppSurface(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Read Receipts'),
                          subtitle: const Text(
                              'Control whether message read status is shared.'),
                          secondary: const Icon(Icons.done_all_rounded,
                              color: AppColors.primaryGlow),
                          value: _readReceipts,
                          onChanged: (value) {
                            setState(() => _readReceipts = value);
                            _saveBool('read_receipts', value);
                          },
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Online Status'),
                          subtitle: const Text(
                              'Show when you are active in the app.'),
                          secondary: const Icon(
                              Icons.radio_button_checked_rounded,
                              color: AppColors.success),
                          value: _onlineStatus,
                          onChanged: (value) {
                            setState(() => _onlineStatus = value);
                            _saveBool('online_status', value);
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.block_rounded,
                              color: AppColors.error),
                          title: const Text('Blocked Users'),
                          subtitle:
                              const Text('Manage contacts you have blocked.'),
                          trailing: const Text('0',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w800)),
                          onTap: () {},
                        ),
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
}
