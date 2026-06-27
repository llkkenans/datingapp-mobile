import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_providers.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/auth_routing.dart';

class EmailAuthScreen extends ConsumerStatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  ConsumerState<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends ConsumerState<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final notifier = ref.read(authNotifierProvider.notifier);

    if (_isSignUp) {
      await notifier.signUpWithEmail(email, password);
    } else {
      await notifier.signInWithEmail(email, password);
    }

    // After a successful sign-in/sign-up, Supabase session is set.
    // Check onboarding status and route accordingly.
    if (mounted && !ref.read(authNotifierProvider).hasError) {
      final route = await determineAuthenticatedRoute(
        ref.read(dioClientProvider).dio,
      );
      if (mounted) context.go(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    ref.listen(authNotifierProvider, (_, next) {
      if (next.hasError) {
        final msg = _friendlyMessage(next.error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
        );
        ref.read(authNotifierProvider.notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: Text(_isSignUp ? 'Create account' : 'Sign in'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                // Toggle sign-in / sign-up
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TabButton(
                      label: 'Sign in',
                      selected: !_isSignUp,
                      onTap: () => setState(() => _isSignUp = false),
                    ),
                    const SizedBox(width: 16),
                    _TabButton(
                      label: 'Sign up',
                      selected: _isSignUp,
                      onTap: () => setState(() => _isSignUp = true),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Email
                _InputField(
                  controller: _emailCtrl,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
                // Password
                _InputField(
                  controller: _passwordCtrl,
                  label: 'Password',
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.white54,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: _validatePassword,
                ),
                if (_isSignUp) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Password must be at least 6 characters.',
                    style: TextStyle(fontSize: 12, color: Colors.white38),
                  ),
                ],
                const SizedBox(height: 32),
                // Submit button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isSignUp ? 'Create account' : 'Sign in',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required.';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email address.';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    // Supabase requires a minimum of 6 characters by default.
    if (value.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  String _friendlyMessage(Object? error) {
    final raw = error?.toString() ?? '';
    // Supabase wraps errors as AppException(null): <message>
    final match = RegExp(r'AppException\(\d*\): (.+)').firstMatch(raw);
    if (match != null) return match.group(1)!;
    if (raw.toLowerCase().contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (raw.toLowerCase().contains('user already registered')) {
      return 'An account with this email already exists.';
    }
    if (raw.isNotEmpty) return raw;
    return 'Something went wrong. Please try again.';
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 17,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white54,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2,
            width: 48,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF1C1C1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}
