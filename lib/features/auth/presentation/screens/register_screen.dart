import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_chrome.dart';
import '../providers/auth_provider.dart';

// ── Username validation rules ─────────────────────────────────────────────────
// 3-20 chars · letters, digits and underscore · must start with a letter
final _usernameRegex = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{2,19}$');

enum _FieldStatus { idle, checking, available, taken, invalid }

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  // ── Controllers ──────────────────────────────────────────────────────────
  final _emailCtrl = TextEditingController();
  final _user1Ctrl = TextEditingController();
  final _user2Ctrl = TextEditingController();

  final _emailFocus = FocusNode();
  final _user1Focus = FocusNode();
  final _user2Focus = FocusNode();

  // ── State ─────────────────────────────────────────────────────────────────
  Map<String, String>? _credentials;
  _FieldStatus _status1 = _FieldStatus.idle;
  _FieldStatus _status2 = _FieldStatus.idle;
  String _hint1 = '';
  String _hint2 = '';

  Timer? _debounce1;
  Timer? _debounce2;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _user1Ctrl.dispose();
    _user2Ctrl.dispose();
    _emailFocus.dispose();
    _user1Focus.dispose();
    _user2Focus.dispose();
    _debounce1?.cancel();
    _debounce2?.cancel();
    super.dispose();
  }

  // ── Username validation + availability check ──────────────────────────────

  String _normalize(String v) => v.trim().toLowerCase();

  bool _validFormat(String v) => _usernameRegex.hasMatch(v.trim());

  void _onUsername1Changed(String raw) {
    _debounce1?.cancel();
    final v = raw.trim();
    if (v.isEmpty) {
      setState(() {
        _status1 = _FieldStatus.idle;
        _hint1 = '';
      });
      return;
    }
    if (!_validFormat(v)) {
      setState(() {
        _status1 = _FieldStatus.invalid;
        _hint1 = '3-20 chars · letters, digits & _ · must start with a letter';
      });
      return;
    }
    setState(() {
      _status1 = _FieldStatus.checking;
      _hint1 = '';
    });
    _debounce1 = Timer(const Duration(milliseconds: 500), () => _checkAvailability(1, v));
  }

  void _onUsername2Changed(String raw) {
    _debounce2?.cancel();
    final v = raw.trim();
    if (v.isEmpty) {
      setState(() {
        _status2 = _FieldStatus.idle;
        _hint2 = '';
      });
      return;
    }
    if (!_validFormat(v)) {
      setState(() {
        _status2 = _FieldStatus.invalid;
        _hint2 = '3-20 chars · letters, digits & _ · must start with a letter';
      });
      return;
    }
    setState(() {
      _status2 = _FieldStatus.checking;
      _hint2 = '';
    });
    _debounce2 = Timer(const Duration(milliseconds: 500), () => _checkAvailability(2, v));
  }

  Future<void> _checkAvailability(int slot, String raw) async {
    if (!mounted) return;
    final normalized = _normalize(raw);

    // Local clash check first — no network round-trip needed
    if (slot == 1 && normalized == _normalize(_user2Ctrl.text)) {
      setState(() {
        _status1 = _FieldStatus.taken;
        _hint1 = 'Both users must have different usernames';
      });
      return;
    }
    if (slot == 2 && normalized == _normalize(_user1Ctrl.text)) {
      setState(() {
        _status2 = _FieldStatus.taken;
        _hint2 = 'Both users must have different usernames';
      });
      return;
    }

    try {
      final available =
          await ref.read(authRepositoryProvider).isUsernameAvailable(normalized);
      if (!mounted) return;
      if (slot == 1) {
        setState(() {
          _status1 = available ? _FieldStatus.available : _FieldStatus.taken;
          _hint1 = available ? '' : 'Username already taken, try another';
        });
      } else {
        setState(() {
          _status2 = available ? _FieldStatus.available : _FieldStatus.taken;
          _hint2 = available ? '' : 'Username already taken, try another';
        });
      }
    } catch (_) {
      if (!mounted) return;
      if (slot == 1) {
        setState(() {
          _status1 = _FieldStatus.idle;
          _hint1 = '';
        });
      } else {
        setState(() {
          _status2 = _FieldStatus.idle;
          _hint2 = '';
        });
      }
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  bool get _canSubmit =>
      _emailCtrl.text.contains('@') &&
      _status1 == _FieldStatus.available &&
      _status2 == _FieldStatus.available;

  void _handleRegister() {
    if (!_canSubmit) return;
    ref.read(authControllerProvider.notifier).registerPair(
          _emailCtrl.text.trim(),
          _user1Ctrl.text.trim(),
          _user2Ctrl.text.trim(),
        );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Map<String, String>?>>(
      authControllerProvider,
      (_, next) {
        if (!next.isLoading && next.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  next.error.toString().replaceAll('Exception: ', '')),
            ),
          );
        } else if (!next.isLoading && next.value != null) {
          setState(() => _credentials = next.value);
        }
      },
    );

    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AppSurface(
                padding: const EdgeInsets.all(28),
                child: _credentials == null
                    ? _buildForm(authState)
                    : _buildSuccess(),
              ),
            ).animate().slideY(begin: 0.08, end: 0, duration: 520.ms).fade(),
          ),
        ),
      ),
    );
  }

  // ── Registration form ─────────────────────────────────────────────────────

  Widget _buildForm(AsyncValue authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: AppLogoMark(size: 64)),
        const SizedBox(height: 22),
        Text(
          'Create Paired Accounts',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose a unique username for each user. Both share one password.',
          style: TextStyle(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),

        // ── Recovery email ──────────────────────────────────────────────────
        TextField(
          controller: _emailCtrl,
          focusNode: _emailFocus,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _user1Focus.requestFocus(),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Recovery Email',
            hintText: 'Used to recover access if credentials are lost',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 20),

        // ── User 1 username ─────────────────────────────────────────────────
        _buildUsernameField(
          ctrl: _user1Ctrl,
          focusNode: _user1Focus,
          nextFocus: _user2Focus,
          label: 'User 1 Username',
          status: _status1,
          hint: _hint1,
          onChanged: _onUsername1Changed,
        ),
        const SizedBox(height: 20),

        // ── User 2 username ─────────────────────────────────────────────────
        _buildUsernameField(
          ctrl: _user2Ctrl,
          focusNode: _user2Focus,
          nextFocus: null,
          label: 'User 2 Username',
          status: _status2,
          hint: _hint2,
          onChanged: _onUsername2Changed,
          onSubmitted: _handleRegister,
        ),
        const SizedBox(height: 8),

        // ── Rules hint ──────────────────────────────────────────────────────
        const Text(
          'Usernames are 3-20 characters and can contain letters, digits and underscores. They are case-insensitive.',
          style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 24),

        // ── Submit ──────────────────────────────────────────────────────────
        AnimatedBuilder(
          animation: Listenable.merge([_user1Ctrl, _user2Ctrl, _emailCtrl]),
          builder: (_, __) => AppButton(
            label: 'Create Accounts',
            icon: Icons.people_rounded,
            loading: authState.isLoading,
            onPressed:
                (!authState.isLoading && _canSubmit) ? _handleRegister : null,
          ),
        ),
      ],
    );
  }

  Widget _buildUsernameField({
    required TextEditingController ctrl,
    required FocusNode focusNode,
    required FocusNode? nextFocus,
    required String label,
    required _FieldStatus status,
    required String hint,
    required ValueChanged<String> onChanged,
    VoidCallback? onSubmitted,
  }) {
    Widget? suffixIcon;
    switch (status) {
      case _FieldStatus.available:
        suffixIcon =
            const Icon(Icons.check_circle_rounded, color: AppColors.success);
      case _FieldStatus.taken:
      case _FieldStatus.invalid:
        suffixIcon =
            const Icon(Icons.cancel_rounded, color: AppColors.error);
      case _FieldStatus.checking:
        suffixIcon = const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case _FieldStatus.idle:
        break;
    }

    final borderColor = switch (status) {
      _FieldStatus.available => AppColors.success,
      _FieldStatus.taken || _FieldStatus.invalid => AppColors.error,
      _ => null,
    };

    final borderSide =
        borderColor != null ? BorderSide(color: borderColor, width: 1.5) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: ctrl,
          focusNode: focusNode,
          textInputAction:
              nextFocus != null ? TextInputAction.next : TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
            LengthLimitingTextInputFormatter(20),
          ],
          onChanged: onChanged,
          onSubmitted: (_) {
            if (nextFocus != null) {
              nextFocus.requestFocus();
            } else {
              onSubmitted?.call();
            }
          },
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.person_outline),
            suffixIcon: suffixIcon != null
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: suffixIcon,
                  )
                : null,
            enabledBorder: borderSide != null
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppGlass.radiusSmall),
                    borderSide: borderSide,
                  )
                : null,
            focusedBorder: borderSide != null
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppGlass.radiusSmall),
                    borderSide:
                        BorderSide(color: borderColor!, width: 2),
                  )
                : null,
          ),
        ),
        if (hint.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 14),
            child: Text(
              hint,
              style: TextStyle(
                color: status == _FieldStatus.available
                    ? AppColors.success
                    : AppColors.error,
                fontSize: 12,
              ),
            ),
          )
        else if (status == _FieldStatus.available)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 14),
            child: Text(
              '${ctrl.text.trim().toLowerCase()} is available',
              style: const TextStyle(color: AppColors.success, fontSize: 12),
            ),
          ),
      ],
    );
  }

  // ── Credentials success screen ────────────────────────────────────────────

  Widget _buildSuccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 64)
            .animate()
            .scale(),
        const SizedBox(height: 16),
        Text(
          'Accounts Created!',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Save these credentials — they cannot be recovered if lost.',
          style: TextStyle(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        _buildCredBox('User 1', _credentials!['user1_name']!,
            _credentials!['password']!),
        const SizedBox(height: 14),
        _buildCredBox('User 2', _credentials!['user2_name']!,
            _credentials!['password']!),
        const SizedBox(height: 32),
        AppButton(
          label: 'Go to Login',
          onPressed: () => context.go('/login'),
        ),
      ],
    );
  }

  Widget _buildCredBox(String title, String username, String password) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.elevatedDark,
        borderRadius: BorderRadius.circular(AppGlass.radiusSmall),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                    color: AppColors.primaryGlow,
                    fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              // Copy button
              IconButton(
                tooltip: 'Copy credentials',
                icon: const Icon(Icons.copy_rounded,
                    size: 18, color: AppColors.textSecondary),
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                      text: 'Username: $username\nPassword: $password'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('$title credentials copied'),
                        duration: const Duration(seconds: 2)),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            'Username: $username',
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 2),
          SelectableText(
            'Password: $password',
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Log in with this username and password. Your display name can be changed from the profile screen.',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
