import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_chrome.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  Map<String, String>? _credentials;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  void _handleRegister() {
    if (!_emailCtrl.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid email')));
      return;
    }
    if (_usernameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a base username')));
      return;
    }

    ref
        .read(authControllerProvider.notifier)
        .registerPair(_emailCtrl.text.trim(), _usernameCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Map<String, String>?>>(
      authControllerProvider,
      (previous, next) {
        if (!next.isLoading && next.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(next.error.toString().replaceAll('Exception: ', ''))),
          );
        } else if (!next.isLoading && next.value != null) {
          setState(() {
            _credentials = next.value;
          });
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
                    ? _buildRegistrationForm(authState)
                    : _buildCredentialsSuccess(),
              ),
            ).animate().slideY(begin: 0.08, end: 0, duration: 520.ms).fade(),
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrationForm(AsyncValue authState) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: AppLogoMark(size: 64)),
        const SizedBox(height: 22),
        Text(
          'Create Paired Accounts',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter a recovery email and a base username.',
          style: TextStyle(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Recovery Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _usernameCtrl,
          keyboardType: TextInputType.text,
          onSubmitted: (_) => authState.isLoading ? null : _handleRegister(),
          decoration: const InputDecoration(
            labelText: 'Base Username',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: authState.isLoading ? null : _handleRegister,
          icon: authState.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome_rounded),
          label: const Text('Generate Accounts'),
        ),
      ],
    );
  }

  Widget _buildCredentialsSuccess() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 64)
            .animate()
            .scale(),
        const SizedBox(height: 16),
        Text(
          'Accounts Ready',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Save these credentials before continuing.',
          style: TextStyle(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        _buildCredBox(
            'User 1', _credentials!['user1_name']!, _credentials!['password']!),
        const SizedBox(height: 16),
        _buildCredBox(
            'User 2', _credentials!['user2_name']!, _credentials!['password']!),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => context.go('/login'),
          child: const Text('Go to Login'),
        ),
      ],
    );
  }

  Widget _buildCredBox(String title, String user, String pwd) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.elevatedDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.primaryGlow, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SelectableText('Username: $user'),
          SelectableText('Password: $pwd'),
        ],
      ),
    );
  }
}
