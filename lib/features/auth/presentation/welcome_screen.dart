import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_providers.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/auth_routing.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  // Listen for OAuth callbacks (Google/Apple open an external browser; when the
  // user returns, Supabase fires onAuthStateChange and we handle routing here).
  late final Stream<AuthState> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = Supabase.instance.client.auth.onAuthStateChange;
    _authStream.listen(_onAuthStateChange);
  }

  Future<void> _onAuthStateChange(AuthState data) async {
    if (data.event == AuthChangeEvent.signedIn && mounted) {
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              // Logo + tagline
              Column(
                children: [
                  Icon(
                    Icons.favorite_rounded,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'DateApp',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Talk first. Reveal later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.white54),
                  ),
                ],
              ),
              const Spacer(flex: 2),
              // Auth buttons
              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SocialButton(
                      label: 'Continue with Google',
                      icon: Icons.g_mobiledata_rounded,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      onTap: () => ref
                          .read(authNotifierProvider.notifier)
                          .signInWithGoogle(),
                    ),
                    const SizedBox(height: 12),
                    _SocialButton(
                      label: 'Continue with Apple',
                      icon: Icons.apple_rounded,
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      onTap: () => ref
                          .read(authNotifierProvider.notifier)
                          .signInWithApple(),
                    ),
                    const SizedBox(height: 12),
                    _SocialButton(
                      label: 'Continue with Email',
                      icon: Icons.email_outlined,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      onTap: () => context.push('/auth/email'),
                    ),
                    const SizedBox(height: 12),
                    _SocialButton(
                      label: 'Continue with Phone',
                      icon: Icons.phone_outlined,
                      backgroundColor: const Color(0xFF1C1C1E),
                      foregroundColor: Colors.white,
                      border: Border.all(color: Colors.white24),
                      onTap: () => context.push('/auth/phone'),
                    ),
                  ],
                ),
              const Spacer(),
              const Text(
                'By continuing you agree to our Terms & Privacy Policy.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white38),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _friendlyMessage(Object? error) {
    final msg = error?.toString() ?? '';
    if (msg.contains('AuthException')) {
      // Extract message from AuthException(message)
      final match = RegExp(r'AppException\(\d*\): (.+)').firstMatch(msg);
      if (match != null) return match.group(1)!;
    }
    if (msg.isNotEmpty) return msg;
    return 'Something went wrong. Please try again.';
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
    this.border,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: border,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: foregroundColor, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
