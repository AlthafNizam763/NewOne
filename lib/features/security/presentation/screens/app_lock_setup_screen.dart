import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_lock_service.dart';
import '../../../../core/widgets/app_chrome.dart';

enum AppLockSetupMode { setup, change, disable }

class AppLockSetupScreen extends StatefulWidget {
  final AppLockSetupMode mode;
  const AppLockSetupScreen({super.key, this.mode = AppLockSetupMode.setup});

  @override
  State<AppLockSetupScreen> createState() => _AppLockSetupScreenState();
}

class _AppLockSetupScreenState extends State<AppLockSetupScreen>
    with SingleTickerProviderStateMixin {
  // 0=verify old (change/disable), 1=enter new, 2=confirm new
  int _step = 0;
  String _entry = '';
  String _newPin = '';
  bool _isPassword = false;
  bool _obscure = true;
  bool _loading = false;

  late final AnimationController _shakeCtrl;
  final _passwordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _step = widget.mode == AppLockSetupMode.setup ? 1 : 0;
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String get _title {
    if (_isPassword) {
      if (widget.mode == AppLockSetupMode.disable) return 'Enter current password';
      if (_step == 0) return 'Verify current password';
      if (_step == 1) return 'Create a password';
      return 'Confirm password';
    }
    if (widget.mode == AppLockSetupMode.disable) return 'Enter current PIN';
    if (_step == 0) return 'Verify current PIN';
    if (_step == 1) return 'Create a PIN';
    return 'Confirm PIN';
  }

  String get _subtitle {
    if (widget.mode == AppLockSetupMode.disable) return 'Enter your credentials to disable App Lock';
    if (_step == 0) return 'Enter your current credentials to continue';
    if (_step == 1) return 'Choose a ${_isPassword ? 'strong password' : '4–6 digit PIN'}';
    return 'Re-enter to confirm';
  }

  void _onDigit(String d) {
    if (_entry.length >= 6) return;
    setState(() => _entry += d);
    if (_entry.length >= 4) _maybeAutoSubmitPin();
  }

  void _onBackspace() {
    if (_entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  Future<void> _maybeAutoSubmitPin() async {
    if (_entry.length < 4) return;
    await Future.delayed(const Duration(milliseconds: 120));
    await _submit();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (widget.mode == AppLockSetupMode.disable) {
        final ok = await AppLockService.verify(_entry);
        if (!ok) { _shake(); return; }
        await AppLockService.clearCredential();
        if (mounted) Navigator.pop(context, true);
        return;
      }
      if (_step == 0) {
        final ok = await AppLockService.verify(_entry);
        if (!ok) { _shake(); return; }
        setState(() { _step = 1; _entry = ''; _passwordCtrl.clear(); });
        return;
      }
      if (_step == 1) {
        if (_entry.length < 4) { _shake(); return; }
        setState(() { _newPin = _entry; _step = 2; _entry = ''; _passwordCtrl.clear(); });
        return;
      }
      // step == 2: confirm
      if (_entry != _newPin) { _shake(); return; }
      await AppLockService.setCredential(_entry, _isPassword ? AppLockType.password : AppLockType.pin);
      if (mounted) Navigator.pop(context, true);
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
      appBar: AppBar(
        title: Text(widget.mode == AppLockSetupMode.disable
            ? 'Disable App Lock'
            : widget.mode == AppLockSetupMode.change
                ? 'Change PIN / Password'
                : 'Set Up App Lock'),
      ),
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
                          size: 64, color: AppColors.primaryGlow)
                      .animate()
                      .scale(duration: 300.ms),
                  const SizedBox(height: 20),
                  Text(_title,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(_subtitle,
                      style: const TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 28),

                  // PIN / Password toggle (only during setup)
                  if (widget.mode == AppLockSetupMode.setup && _step == 1) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _modeChip('PIN', !_isPassword, () => setState(() {
                          _isPassword = false;
                          _entry = '';
                          _passwordCtrl.clear();
                        })),
                        const SizedBox(width: 12),
                        _modeChip('Password', _isPassword, () => setState(() {
                          _isPassword = true;
                          _entry = '';
                          _passwordCtrl.clear();
                        })),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // PIN dots or password field
                  AnimatedBuilder(
                    animation: _shakeCtrl,
                    builder: (context, child) {
                      final shake = _shakeCtrl.value < 0.5
                          ? _shakeCtrl.value * 2
                          : (1 - _shakeCtrl.value) * 2;
                      return Transform.translate(
                        offset: Offset(shake * 12 * (shake > 0.5 ? -1 : 1), 0),
                        child: child,
                      );
                    },
                    child: _isPassword
                        ? _buildPasswordField()
                        : _buildPinDots(),
                  ),

                  const SizedBox(height: 32),

                  if (!_isPassword) _buildNumpad(),
                  if (_isPassword) _buildPasswordSubmitButton(),

                  if (_loading) ...[
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryGlow : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primaryGlow : AppColors.textSecondary,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
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
        final active = i < 6;
        if (!active) return const SizedBox.shrink();
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? AppColors.primaryGlow
                : Colors.transparent,
            border: Border.all(
              color: filled
                  ? AppColors.primaryGlow
                  : AppColors.textSecondary,
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

  Widget _buildPasswordSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: AppButton(
        label: _step == 0 ? 'Verify' : _step == 1 ? 'Continue' : 'Confirm',
        icon: Icons.arrow_forward_rounded,
        onPressed: _entry.length >= 4 ? _submit : null,
        loading: _loading,
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
