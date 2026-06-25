import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_chrome.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  String _selectedTone = 'Default';
  bool _notificationsEnabled = true;

  final List<String> _tones = [
    'Default',
    'Chime',
    'Crystal',
    'Neon Ping',
    'Soft Marimba',
    'Digital Pulse'
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
      _selectedTone = prefs.getString('notification_tone') ?? 'Default';
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  Future<void> _saveTone(String tone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notification_tone', tone);
    if (!mounted) return;
    setState(() => _selectedTone = tone);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tone set to $tone')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
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
                  AppSurface(
                    padding: EdgeInsets.zero,
                    child: SwitchListTile(
                      title: const Text('Enable Notifications'),
                      subtitle: const Text(
                          'Receive push notifications for messages.'),
                      secondary: const Icon(Icons.notifications_none_rounded,
                          color: AppColors.primaryGlow),
                      value: _notificationsEnabled,
                      onChanged: (value) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('notifications_enabled', value);
                        if (mounted)
                          setState(() => _notificationsEnabled = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 22),
                  const SectionLabel('NOTIFICATION TONE'),
                  AppSurface(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < _tones.length; i++) ...[
                          _buildToneTile(_tones[i]),
                          if (i != _tones.length - 1) const Divider(height: 1),
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

  Widget _buildToneTile(String tone) {
    final isSelected = tone == _selectedTone;
    return ListTile(
      enabled: _notificationsEnabled,
      leading: Icon(
        isSelected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        color: isSelected ? AppColors.primaryGlow : AppColors.textSecondary,
      ),
      title: Text(tone,
          style: TextStyle(
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500)),
      trailing: isSelected
          ? const Icon(Icons.check_rounded, color: AppColors.primaryGlow)
          : null,
      onTap: _notificationsEnabled ? () => _saveTone(tone) : null,
    );
  }
}
