import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/text_match_notifier.dart';
import '../providers/voice_match_notifier.dart';

class MatchTabScreen extends ConsumerWidget {
  const MatchTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textState = ref.watch(textMatchNotifierProvider);
    final textNotifier = ref.read(textMatchNotifierProvider.notifier);
    final voiceState = ref.watch(voiceMatchNotifierProvider);
    final voiceNotifier = ref.read(voiceMatchNotifierProvider.notifier);

    ref.listen<TextMatchState>(textMatchNotifierProvider, (prev, next) {
      if (prev is! TextMatchSearching) return;
      if (next is TextMatchSessionActive) {
        context.push('/match/text/session/${next.sessionId}');
      }
    });

    ref.listen<VoiceMatchState>(voiceMatchNotifierProvider, (prev, next) {
      if (prev is! VoiceMatchSearching) return;
      if (next is VoiceMatchSessionActive) {
        context.push(
          '/match/voice/session/${next.sessionId}',
          extra: next,
        );
      }
    });

    Widget body;
    if (textState is TextMatchSearching) {
      body = _SearchingView(
        label: 'Finding a text match...',
        onCancel: textNotifier.cancelSearch,
      );
    } else if (textState is TextMatchError) {
      body = _ErrorView(
        message: textState.message,
        onDismiss: textNotifier.reset,
      );
    } else if (voiceState is VoiceMatchSearching) {
      body = _SearchingView(
        label: 'Finding a voice match...',
        onCancel: voiceNotifier.cancelSearch,
      );
    } else if (voiceState is VoiceMatchError) {
      body = _ErrorView(
        message: voiceState.message,
        onDismiss: voiceNotifier.reset,
      );
    } else {
      body = _IdleView(
        onStartTextMatch: textNotifier.startSearch,
        onStartVoiceMatch: voiceNotifier.startSearch,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Match',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: body,
    );
  }
}

// ─── Idle view ────────────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  const _IdleView({
    required this.onStartTextMatch,
    required this.onStartVoiceMatch,
  });
  final Future<void> Function() onStartTextMatch;
  final Future<void> Function() onStartVoiceMatch;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            'Talk first.\nReveal later.',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Match anonymously through conversation quality.',
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 48),
          _MatchTypeCard(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Text\nMatch',
            description: 'Anonymous 3-minute text conversation',
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF6B6B), Color(0xFFFF8FA3), Color(0xFFFFB088)],
            ),
            onTap: onStartTextMatch,
          ),
          const SizedBox(height: 16),
          _MatchTypeCard(
            icon: Icons.mic_none_rounded,
            title: 'Voice\nMatch',
            description: 'Anonymous 3-minute voice call',
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0FB88A), Color(0xFF1DD3A6), Color(0xFF6EE7C8)],
            ),
            onTap: onStartVoiceMatch,
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
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Gradient gradient;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ExtrudedTitle(title),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtrudedTitle extends StatelessWidget {
  const _ExtrudedTitle(this.text);

  final String text;

  static const _style = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    fontStyle: FontStyle.italic,
    letterSpacing: -0.5,
    height: 0.95,
    color: Colors.black,
  );

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: Matrix4.rotationZ(-0.0524),
      alignment: Alignment.centerLeft,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 6; i >= 1; i--)
            Transform.translate(
              offset: Offset(i.toDouble(), i.toDouble()),
              child: Text(text, style: _style),
            ),
          Text(text, style: _style.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}

// ─── Searching view ───────────────────────────────────────────────────────────

class _SearchingView extends StatefulWidget {
  const _SearchingView({required this.onCancel, required this.label});
  final Future<void> Function() onCancel;
  final String label;

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
    final cs = Theme.of(context).colorScheme;
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
                            border:
                                Border.all(color: cs.primary, width: 1.5),
                          ),
                        ),
                      ),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.favorite_rounded,
                          color: cs.primary, size: 32),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 40),
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Looking for someone to talk to',
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 48),
          TextButton(
            onPressed: widget.onCancel,
            child: Text(
              'Cancel',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
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
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                color: cs.error, size: 52),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
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
