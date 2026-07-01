import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_lock_service.dart';
import '../../../../core/widgets/app_chrome.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with SingleTickerProviderStateMixin {
  String _entry = '';
  bool _loading = false;
  bool _biometricAvailable = false;
  bool _isPassword = false;
  bool _obscure = true;

  late final AnimationController _shakeCtrl;
  final _passwordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _init();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final type = await AppLockService.getType();
    final bio = LocalAuthentication();
    final canBio = await bio.canCheckBiometrics;
    if (!mounted) return;
    setState(() {
      _isPassword = type == AppLockType.password;
      _biometricAvailable = canBio;
    });
    if (canBio) _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    try {
      final bio = LocalAuthentication();
      final ok = await bio.authenticate(
        localizedReason: 'Unlock Hisoka to view your messages',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );
      if (ok && mounted) context.go('/home');
    } on PlatformException catch (e) {
      debugPrint('[AppLock] Biometric: $e');
    }
  }

  void _onDigit(String d) {
    if (_entry.length >= 6) return;
    setState(() => _entry += d);
    if (_entry.length >= 4) _maybeAutoSubmit();
  }

  void _onBackspace() {
    if (_entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  Future<void> _maybeAutoSubmit() async {
    await Future.delayed(const Duration(milliseconds: 120));
    await _submit();
  }

  Future<void> _submit() async {
    if (_loading || _entry.isEmpty) return;
    setState(() => _loading = true);
    try {
      final ok = await AppLockService.verify(_entry);
      if (ok && mounted) {
        context.go('/home');
      } else {
        _shake();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _shake() {
    HapticFeedback.heavyImpact();
    setState(() => _entry = '');
    _passwordCtrl.clear();
    _shakeCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline_rounded,
                          size: 72, color: AppColors.primaryGlow)
                      .animate()
                      .scale(duration: 400.ms),
                  const SizedBox(height: 24),
                  Text(
                    'App Locked',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ).animate().fade().slideY(),
                  const SizedBox(height: 8),
                  Text(
                    _isPassword
                        ? 'Enter your password to unlock'
                        : 'Enter your PIN to unlock',
                    style: const TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  AnimatedBuilder(
                    animation: _shakeCtrl,
                    builder: (context, child) {
                      final t = _shakeCtrl.value;
                      final shake = t < 0.5 ? t * 2 : (1 - t) * 2;
                      return Transform.translate(
                        offset: Offset(shake * 14 * (shake > 0.5 ? -1 : 1), 0),
                        child: child,
                      );
                    },
                    child: _isPassword
                        ? _buildPasswordField()
                        : _buildPinDots(),
                  ),

                  const SizedBox(height: 32),

                  if (!_isPassword) _buildNumpad(),
                  if (_isPassword)
                    AppButton(
                      label: 'Unlock',
                      icon: Icons.lock_open_rounded,
                      onPressed: _entry.isNotEmpty ? _submit : null,
                      loading: _loading,
                    ).animate().fade(delay: 300.ms),

                  if (_biometricAvailable && !_loading) ...[
                    const SizedBox(height: 20),
                    TextButton.icon(
                      onPressed: _tryBiometric,
                      icon: const Icon(Icons.fingerprint_rounded,
                          color: AppColors.primaryGlow),
                      label: const Text('Use Biometrics',
                          style: TextStyle(color: AppColors.primaryGlow)),
                    ).animate().fade(delay: 400.ms),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        final filled = i < _entry.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? AppColors.primaryGlow : Colors.transparent,
            border: Border.all(
              color: filled ? AppColors.primaryGlow : AppColors.textSecondary,
              width: 2,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPasswordField() {
    return AppSurface(
      padding: EdgeInsets.zero,
      child: TextField(
        controller: _passwordCtrl,
        obscureText: _obscure,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Enter password',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          suffixIcon: IconButton(
            icon: Icon(
                _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: AppColors.textSecondary),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        onChanged: (v) => setState(() => _entry = v),
        onSubmitted: (_) => _submit(),
      ),
    );
  }

  Widget _buildNumpad() {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      children: keys.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((k) {
            if (k.isEmpty) return const SizedBox(width: 88, height: 72);
            return _numKey(k);
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _numKey(String label) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (label == '⌫') {
          _onBackspace();
        } else {
          _onDigit(label);
        }
      },
      child: Container(
        width: 88,
        height: 72,
        alignment: Alignment.center,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.elevatedDark,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.outlineDark),
          ),
          alignment: Alignment.center,
          child: label == '⌫'
              ? const Icon(Icons.backspace_outlined,
                  color: AppColors.primaryGlow, size: 22)
              : Text(label,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
        ),
      ),
    );
  }
}
