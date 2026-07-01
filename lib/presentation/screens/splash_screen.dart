import 'dart:math' show sin, pi;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/widgets/app_chrome.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat();
    _initialize();
  }

  Future<void> _initialize() async {
    // Auth resolution and minimum display time run in parallel.
    // Total wait = max(authCheckTime, 800 ms) — no artificial serial delay.
    final destFuture = _resolveDestination();
    await Future.delayed(const Duration(milliseconds: 800));
    final dest = await destFuture;
    if (mounted) context.go(dest);
  }

  Future<String> _resolveDestination() async {
    final user = await FirebaseAuth.instance.authStateChanges().first;
    if (user == null) return '/login';

    final prefs = await SharedPreferences.getInstance();
    final isLocked = prefs.getBool('app_lock_enabled') ?? false;

    // If the app was launched by tapping a terminated-state notification,
    // navigate to the relevant screen instead of home (lock screen takes
    // precedence so the user still has to authenticate first).
    final notifData = ref
        .read(pushNotificationServiceProvider)
        .consumeInitialNotification();
    if (notifData != null && notifData['type'] == 'chat') {
      return isLocked ? '/lock' : '/chat';
    }

    return isLocked ? '/lock' : '/home';
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.darkBackgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),

              // ── Pulsing ring + logo ──────────────────────────────────────
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (context, child) {
                  final t = _pulseCtrl.value; // 0 → 1 linearly
                  // Outer ring breathes with a smooth sine curve
                  final sine = sin(t * 2 * pi) * 0.5 + 0.5;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outermost diffuse glow ring
                      Container(
                        width: 160 + 18 * sine,
                        height: 160 + 18 * sine,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white
                                .withValues(alpha: 0.03 + 0.03 * sine),
                            width: 1,
                          ),
                        ),
                      ),
                      // Inner accent ring
                      Container(
                        width: 132 + 8 * sine,
                        height: 132 + 8 * sine,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white
                                .withValues(alpha: 0.07 + 0.07 * sine),
                            width: 1,
                          ),
                        ),
                      ),
                      child!,
                    ],
                  );
                },
                child: const AppLogoMark(size: 96)
                    .animate()
                    .fade(duration: 500.ms)
                    .scale(
                      begin: const Offset(0.72, 0.72),
                      end: const Offset(1, 1),
                      duration: 600.ms,
                      curve: Curves.easeOutBack,
                    ),
              ),

              const SizedBox(height: 28),

              // ── App name ─────────────────────────────────────────────────
              Text(
                'Hisoka',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
              )
                  .animate()
                  .fade(delay: 180.ms, duration: 480.ms)
                  .slideY(begin: 0.18, end: 0, curve: Curves.easeOut),

              const SizedBox(height: 8),

              // ── Tagline ──────────────────────────────────────────────────
              const Text(
                'Private messaging, calmly organized.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ).animate().fade(delay: 320.ms, duration: 480.ms),

              const Spacer(flex: 2),

              // ── Loading dots ─────────────────────────────────────────────
              _WaveDots(controller: _pulseCtrl)
                  .animate()
                  .fade(delay: 500.ms, duration: 400.ms),

              const SizedBox(height: 52),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Wave loading dots ─────────────────────────────────────────────────────────

class _WaveDots extends StatelessWidget {
  final AnimationController controller;
  const _WaveDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot has a 1/3 cycle phase offset for a wave effect
            final phase = (controller.value + i / 3) % 1.0;
            final brightness = sin(phase * 2 * pi) * 0.5 + 0.5;
            final opacity = 0.18 + 0.72 * brightness;
            final scale = 0.7 + 0.3 * brightness;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: opacity),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
