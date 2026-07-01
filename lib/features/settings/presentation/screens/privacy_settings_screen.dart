import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_lock_service.dart';
import '../../../../core/widgets/app_chrome.dart';
import '../../../security/presentation/screens/app_lock_setup_screen.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _appLockEnabled = false;
  bool _hasCredential  = false;
  bool _readReceipts   = true;
  bool _onlineStatus   = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCred = await AppLockService.hasCredential();
    if (!mounted) return;
    setState(() {
      _appLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
      _hasCredential  = hasCred;
      _readReceipts   = prefs.getBool('read_receipts') ?? true;
      _onlineStatus   = prefs.getBool('online_status') ?? true;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _toggleAppLock(bool value) async {
    if (value) {
      // Enable — navigate to setup; reload state on return
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const AppLockSetupScreen(mode: AppLockSetupMode.setup),
        ),
      );
      if (result == true) await _loadSettings();
    } else {
      if (_hasCredential) {
        // Require PIN/password before disabling
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const AppLockSetupScreen(mode: AppLockSetupMode.disable),
          ),
        );
        if (result == true) await _loadSettings();
      } else {
        await _saveBool('app_lock_enabled', false);
        await _loadSettings();
      }
    }
  }

  Future<void> _changePinOrPassword() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const AppLockSetupScreen(mode: AppLockSetupMode.change),
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App Lock credentials updated')),
      );
    }
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
                          subtitle: Text(
                            _hasCredential
                                ? 'PIN or password required to open the app'
                                : 'Protect the app with a PIN or password',
                          ),
                          secondary: const Icon(Icons.lock_outline_rounded,
                              color: AppColors.primaryGlow),
                          value: _appLockEnabled,
                          onChanged: _toggleAppLock,
                        ),
                        if (_appLockEnabled && _hasCredential) ...[
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.password_rounded,
                                color: AppColors.primaryGlow),
                            title: const Text('Change PIN / Password'),
                            subtitle: const Text(
                                'Update your App Lock credentials'),
                            trailing:
                                const Icon(Icons.chevron_right_rounded),
                            onTap: _changePinOrPassword,
                          ),
                        ],
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
                          onChanged: (v) {
                            setState(() => _readReceipts = v);
                            _saveBool('read_receipts', v);
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
                          onChanged: (v) {
                            setState(() => _onlineStatus = v);
                            _saveBool('online_status', v);
                          },
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
