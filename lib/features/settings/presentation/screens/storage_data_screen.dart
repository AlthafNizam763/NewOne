import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_chrome.dart';

class StorageDataScreen extends StatefulWidget {
  const StorageDataScreen({super.key});

  @override
  State<StorageDataScreen> createState() => _StorageDataScreenState();
}

class _StorageDataScreenState extends State<StorageDataScreen> {
  bool _loading = true;
  bool _clearingCache = false;
  double _cacheMb = 0;
  bool _autoDownloadWifi = true;
  bool _autoDownloadMobile = false;
  String _mediaQuality = 'high';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final size = await _getCacheSize();
      if (mounted) {
        setState(() {
          _cacheMb = size;
          _autoDownloadWifi = prefs.getBool('auto_dl_wifi') ?? true;
          _autoDownloadMobile = prefs.getBool('auto_dl_mobile') ?? false;
          _mediaQuality = prefs.getString('media_quality') ?? 'high';
        });
      }
    } catch (e) {
      debugPrint('[StorageData] load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Fully async — uses dir.list() stream to avoid blocking the UI thread.
  Future<double> _getCacheSize() async {
    try {
      final dir = await getTemporaryDirectory();
      double total = 0;
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
      return total / (1024 * 1024);
    } catch (_) {
      return 0;
    }
  }

  Future<void> _clearCache() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _clearingCache = true);
    try {
      final dir = await getTemporaryDirectory();
      await for (final entity in dir.list(followLinks: false)) {
        try {
          await entity.delete(recursive: true);
        } catch (_) {}
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _cacheMb = 0;
      _clearingCache = false;
    });
    messenger.showSnackBar(const SnackBar(content: Text('Cache cleared')));
  }

  Future<void> _saveBool(String key, bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, v);
  }

  Future<void> _saveQuality(String q) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('media_quality', q);
    if (!mounted) return;
    setState(() => _mediaQuality = q);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Storage & Data')),
      body: AppBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
                children: [
                  ResponsiveContent(
                    padding: EdgeInsets.zero,
                    maxWidth: 760,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Storage stats card
                        AppSurface(
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                  color: AppColors.elevatedDark,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.storage_rounded,
                                    color: AppColors.primaryGlow, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_cacheMb.toStringAsFixed(1)} MB',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall,
                                    ),
                                    const Text('Cache used',
                                        style: TextStyle(
                                            color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              _clearingCache
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : OutlinedButton(
                                      onPressed: _clearCache,
                                      child: const Text('Clear'),
                                    ),
                            ],
                          ),
                        ).animate().fade(duration: 300.ms),

                        const SizedBox(height: 22),
                        const SectionLabel('AUTO-DOWNLOAD'),
                        AppSurface(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: const Text('On Wi-Fi'),
                                subtitle: const Text(
                                    'Automatically download media on Wi-Fi'),
                                secondary: const Icon(Icons.wifi_rounded,
                                    color: AppColors.primaryGlow),
                                value: _autoDownloadWifi,
                                onChanged: (v) {
                                  setState(() => _autoDownloadWifi = v);
                                  _saveBool('auto_dl_wifi', v);
                                },
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                title: const Text('On Mobile Data'),
                                subtitle: const Text(
                                    'Download media using cellular data'),
                                secondary: const Icon(
                                    Icons.signal_cellular_alt_rounded,
                                    color: AppColors.primaryGlow),
                                value: _autoDownloadMobile,
                                onChanged: (v) {
                                  setState(() => _autoDownloadMobile = v);
                                  _saveBool('auto_dl_mobile', v);
                                },
                              ),
                            ],
                          ),
                        ).animate().fade(delay: 100.ms),

                        const SizedBox(height: 22),
                        const SectionLabel('MEDIA UPLOAD QUALITY'),
                        AppSurface(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _qualityTile('high',   'High Quality',
                                  'Best quality, larger file size'),
                              const Divider(height: 1),
                              _qualityTile('medium', 'Medium',
                                  'Balanced quality and size'),
                              const Divider(height: 1),
                              _qualityTile('low',    'Low',
                                  'Smallest size, reduced quality'),
                            ],
                          ),
                        ).animate().fade(delay: 200.ms),

                        const SizedBox(height: 22),
                        const SectionLabel('DATA USAGE'),
                        AppSurface(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _infoTile(Icons.image_outlined,
                                  'Images downloaded', '—'),
                              const Divider(height: 1),
                              _infoTile(Icons.mic_none_rounded,
                                  'Voice messages downloaded', '—'),
                              const Divider(height: 1),
                              _infoTile(Icons.videocam_outlined,
                                  'Videos downloaded', '—'),
                            ],
                          ),
                        ).animate().fade(delay: 300.ms),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _qualityTile(String key, String title, String subtitle) {
    final selected = _mediaQuality == key;
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle,
          style: const TextStyle(color: AppColors.textSecondary)),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
          : const Icon(Icons.radio_button_unchecked_rounded,
              color: AppColors.textSecondary),
      onTap: () => _saveQuality(key),
    );
  }

  Widget _infoTile(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryGlow),
      title: Text(title),
      trailing: Text(value,
          style: const TextStyle(color: AppColors.textSecondary)),
    );
  }
}
