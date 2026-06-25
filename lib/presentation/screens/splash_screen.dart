import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_chrome.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 1400));

    final user = await FirebaseAuth.instance.authStateChanges().first;
    if (!mounted) return;

    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final isAppLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
      context.go(isAppLockEnabled ? '/lock' : '/home');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLogoMark(size: 112)
                  .animate()
                  .fade(duration: 500.ms)
                  .scale(delay: 120.ms),
              const SizedBox(height: 24),
              Text(
                'Hisoka',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
              ).animate().fade(delay: 250.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 8),
              const Text(
                'Private messaging, calmly organized.',
                style: TextStyle(color: AppColors.textSecondary),
              ).animate().fade(delay: 350.ms),
            ],
          ),
        ),
      ),
    );
  }
}
