import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/auth/presentation/email_auth_screen.dart';
import '../../features/auth/presentation/phone_auth_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/home/presentation/main_shell.dart';
import '../../features/match/presentation/match_tab_screen.dart';
import '../../features/match/text_match/presentation/anonymous_chat_screen.dart';
import '../../features/match/text_match/presentation/match_rating_screen.dart';
import '../../features/match/text_match/presentation/match_success_screen.dart';
import '../../features/match/providers/text_match_notifier.dart';
import '../../features/match/providers/voice_match_notifier.dart';
import '../../features/match/voice_match/presentation/voice_call_screen.dart';
import '../../features/match/voice_match/presentation/voice_match_success_screen.dart';
import 'go_router_refresh_stream.dart';
import 'auth_routing.dart';
import '../network/dio_client.dart';

// ─── Phase-6 placeholder tabs ─────────────────────────────────────────────────

class _DiscoverPlaceholder extends StatelessWidget {
  const _DiscoverPlaceholder();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Text(
            'Discover — Phase 6',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
}

class _MessagesPlaceholder extends StatelessWidget {
  const _MessagesPlaceholder();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Text(
            'Messages — Phase 6',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
}

class _ProfilePlaceholder extends StatelessWidget {
  const _ProfilePlaceholder();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Text(
            'Profile — Phase 6',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
}

// ─── Router ───────────────────────────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  );
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: refreshListenable,
    redirect: (context, state) async {
      final session = Supabase.instance.client.auth.currentSession;
      final location = state.matchedLocation;

      if (location == '/') return null;

      final onAuthRoute = location.startsWith('/auth');

      if (session == null && !onAuthRoute) return '/auth/welcome';

      if (session != null && onAuthRoute) {
        return await determineAuthenticatedRoute(
          ref.read(dioClientProvider).dio,
        );
      }

      return null;
    },
    routes: [
      // ── Pre-auth / onboarding ───────────────────────────────────────────────
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth/welcome',
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/auth/email',
        name: 'email-auth',
        builder: (context, state) => const EmailAuthScreen(),
      ),
      GoRoute(
        path: '/auth/phone',
        name: 'phone-auth',
        builder: (context, state) => const PhoneAuthScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // ── Text match flow (full-screen, outside bottom-nav shell) ────────────
      GoRoute(
        path: '/match/text/session/:sessionId',
        name: 'text-match-session',
        builder: (context, state) => AnonymousChatScreen(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: '/match/text/rating',
        name: 'text-match-rating',
        builder: (context, state) => MatchRatingScreen(
          sessionId: state.extra as String? ?? '',
        ),
      ),
      GoRoute(
        path: '/match/text/success',
        name: 'text-match-success',
        builder: (context, state) {
          final mutualLike = state.extra as TextMatchMutualLike;
          return MatchSuccessScreen(mutualLike: mutualLike);
        },
      ),

      // ── Voice match flow ───────────────────────────────────────────────────
      GoRoute(
        path: '/match/voice/session/:sessionId',
        name: 'voice-match-session',
        builder: (context, state) {
          final session = state.extra as VoiceMatchSessionActive;
          return VoiceCallScreen(
            sessionId: session.sessionId,
            roomId: session.roomId,
            zegoToken: session.zegoToken,
            expiresAt: session.expiresAt,
          );
        },
      ),
      GoRoute(
        path: '/match/voice/rating',
        name: 'voice-match-rating',
        builder: (context, state) => MatchRatingScreen(
          sessionId: state.extra as String? ?? '',
          isVoiceMatch: true,
        ),
      ),
      GoRoute(
        path: '/match/voice/success',
        name: 'voice-match-success',
        builder: (context, state) {
          final mutualLike = state.extra as VoiceMatchMutualLike;
          return VoiceMatchSuccessScreen(mutualLike: mutualLike);
        },
      ),

      // ── Bottom navigation shell ────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                name: 'discover',
                builder: (context, state) => const _DiscoverPlaceholder(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/match',
                name: 'match',
                builder: (context, state) => const MatchTabScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/messages',
                name: 'messages',
                builder: (context, state) => const _MessagesPlaceholder(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                builder: (context, state) => const _ProfilePlaceholder(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          'Route not found: ${state.uri}',
          style: const TextStyle(color: Colors.white54),
        ),
      ),
    ),
  );
});
