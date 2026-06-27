import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/text_match_notifier.dart';

class MatchTabScreen extends ConsumerWidget {
  const MatchTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(textMatchNotifierProvider);
    final notifier = ref.read(textMatchNotifierProvider.notifier);

    // Navigate to session screen when match is found
    ref.listen<TextMatchState>(textMatchNotifierProvider, (prev, next) {
      if (prev is! TextMatchSearching) return;
      if (next is TextMatchSessionActive) {
        context.push('/match/text/session/${next.sessionId}');
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text(
          'Match',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: switch (state) {
        TextMatchSearching() => _SearchingView(onCancel: notifier.cancelSearch),
        TextMatchError(:final message) => _ErrorView(
            message: message,
            onDismiss: notifier.reset,
          ),
        _ => _IdleView(onStartTextMatch: notifier.startSearch),
      },
    );
  }
}

// ─── Idle view ────────────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  const _IdleView({required this.onStartTextMatch});
  final Future<void> Function() onStartTextMatch;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Talk first.\nReveal later.',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Match anonymously through conversation quality.',
            style: TextStyle(fontSize: 14, color: Colors.white54),
          ),
          const SizedBox(height: 48),
          _MatchTypeCard(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Text Match',
            description: 'Anonymous 3-minute text conversation',
            onTap: onStartTextMatch,
          ),
          const SizedBox(height: 16),
          _MatchTypeCard(
            icon: Icons.mic_none_rounded,
            title: 'Voice Match',
            description: 'Anonymous 3-minute voice call',
            onTap: null,
            comingSoon: true,
          ),
        ],
      ),
    );
  }
}

class _MatchTypeCard extends StatelessWidget {
  const _MatchTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.comingSoon = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final Future<void> Function()? onTap;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Opacity(
      opacity: comingSoon ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: onTap != null ? () => onTap!() : null,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Color.fromRGBO(108, 99, 255, 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Color.fromRGBO(108, 99, 255, 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: primary, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (comingSoon) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Soon',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.white54),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              if (!comingSoon)
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: primary),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Searching view ───────────────────────────────────────────────────────────

class _SearchingView extends StatefulWidget {
  const _SearchingView({required this.onCancel});
  final Future<void> Function() onCancel;

  @override
  State<_SearchingView> createState() => _SearchingViewState();
}

class _SearchingViewState extends State<_SearchingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) {
              final v = _pulse.value;
              return SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Opacity(
                        opacity: (1 - ((v + i / 3) % 1)).clamp(0.0, 0.35),
                        child: Container(
                          width: 80 + i * 40.0,
                          height: 80 + i * 40.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: primary, width: 1.5),
                          ),
                        ),
                      ),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(108, 99, 255, 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.favorite_rounded,
                          color: primary, size: 32),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 40),
          const Text(
            'Searching for a match...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Looking for someone to talk to',
            style: TextStyle(fontSize: 14, color: Colors.white54),
          ),
          const SizedBox(height: 48),
          TextButton(
            onPressed: widget.onCancel,
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.redAccent, size: 52),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onDismiss,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
