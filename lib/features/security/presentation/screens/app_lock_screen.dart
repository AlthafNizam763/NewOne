import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_chrome.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      setState(() => _isAuthenticating = true);
      authenticated = await auth.authenticate(
        localizedReason: 'Unlock Anata no tame ni to view your messages',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint(e.toString());
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
      if (authenticated && mounted) {
        // Successful biometric unlock
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AppSurface(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded,
                            size: 72, color: AppColors.primaryGlow)
                        .animate()
                        .scale(duration: 400.ms),
                    const SizedBox(height: 24),
                    Text(
                      'App Locked',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ).animate().fade().slideY(),
                    const SizedBox(height: 8),
                    const Text(
                      'Unlock to view your private messages.',
                      style: TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (_isAuthenticating)
                      const CircularProgressIndicator()
                    else
                      ElevatedButton.icon(
                        onPressed: _authenticate,
                        icon: const Icon(Icons.fingerprint_rounded),
                        label: const Text('Unlock'),
                      ).animate().fade(delay: 300.ms).scale(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
