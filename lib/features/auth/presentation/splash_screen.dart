import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/auth_routing.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Run after the first frame so GoRouter is fully mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndRoute());
  }

  Future<void> _checkAndRoute() async {
    // Brief pause so the splash is visible on first cold launch.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      context.go('/auth/welcome');
      return;
    }

    // Session exists — determine whether onboarding is complete.
    final route = await determineAuthenticatedRoute(
      ref.read(dioClientProvider).dio,
    );
    if (mounted) context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_rounded, size: 64, color: Color(0xFF6C63FF)),
            SizedBox(height: 16),
            Text(
              'DateApp',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Talk first. Reveal later.',
              style: TextStyle(fontSize: 14, color: Colors.white54),
            ),
            SizedBox(height: 40),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF6C63FF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
