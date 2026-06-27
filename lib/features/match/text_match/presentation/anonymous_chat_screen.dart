import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/match_socket_service.dart';
import '../../providers/text_match_notifier.dart';

class _ChatMessage {
  const _ChatMessage({
    required this.content,
    required this.isMe,
    required this.sentAt,
  });
  final String content;
  final bool isMe;
  final DateTime sentAt;
}

class AnonymousChatScreen extends ConsumerStatefulWidget {
  const AnonymousChatScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  ConsumerState<AnonymousChatScreen> createState() =>
      _AnonymousChatScreenState();
}

class _AnonymousChatScreenState extends ConsumerState<AnonymousChatScreen> {
  Timer? _clockTimer;
  Duration _remaining = Duration.zero;

  final List<_ChatMessage> _messages = [];
  final _inputController = TextEditingController();
  StreamSubscription<ChatMessageEvent>? _msgSub;
  StreamSubscription<ChatMessageErrorEvent>? _errSub;

  @override
  void initState() {
    super.initState();
    final state = ref.read(textMatchNotifierProvider);
    if (state is TextMatchSessionActive) {
      _updateRemaining(state.expiresAt);
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final s = ref.read(textMatchNotifierProvider);
        if (s is TextMatchSessionActive) {
          setState(() => _updateRemaining(s.expiresAt));
          if (_remaining == Duration.zero) {
            ref
                .read(textMatchNotifierProvider.notifier)
                .localExpire(s.sessionId);
          }
        }
      });
    }

    final socket = ref.read(matchSocketServiceProvider);

    _msgSub = socket.onSessionMessage.listen((event) {
      if (!mounted || event.sessionId != widget.sessionId) return;
      setState(() {
        _messages.add(_ChatMessage(
          content: event.content,
          isMe: false,
          sentAt: event.sentAt,
        ));
      });
    });

    _errSub = socket.onSessionMessageError.listen((event) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(event.message),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  void _updateRemaining(DateTime expiresAt) {
    final diff = expiresAt.toUtc().difference(DateTime.now().toUtc());
    _remaining = diff.isNegative ? Duration.zero : diff;
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _msgSub?.cancel();
    _errSub?.cancel();
    _inputController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _sendMessage() {
    final content = _inputController.text.trim();
    if (content.isEmpty) return;
    _inputController.clear();
    setState(() {
      _messages.add(_ChatMessage(
        content: content,
        isMe: true,
        sentAt: DateTime.now(),
      ));
    });
    ref
        .read(matchSocketServiceProvider)
        .sendSessionMessage(widget.sessionId, content);
  }

  Future<bool> _confirmSkip(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            title: const Text('Skip this match?'),
            content: const Text(
              "You'll be taken to a rating screen. The session ends for both of you.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Skip',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(textMatchNotifierProvider);
    final notifier = ref.read(textMatchNotifierProvider.notifier);

    ref.listen<TextMatchState>(textMatchNotifierProvider, (_, next) {
      if (!mounted) return;
      if (next is TextMatchMutualLike) {
        context.pushReplacement('/match/text/success', extra: next);
      } else if (next is TextMatchExpired) {
        context.pushReplacement('/match/text/rating', extra: next.sessionId);
      } else if (next is TextMatchEnded) {
        context.pushReplacement('/match/text/rating', extra: next.sessionId);
      }
    });

    final iLiked = state is TextMatchSessionActive ? state.iLiked : false;
    final partnerLiked =
        state is TextMatchSessionActive ? state.partnerLiked : false;
    final isTimeLow = _remaining.inSeconds <= 30 && _remaining.inSeconds > 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final confirmed = await _confirmSkip(context);
        if (confirmed && mounted) {
          await notifier.skipSession(widget.sessionId);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F0F0F),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              final confirmed = await _confirmSkip(context);
              if (confirmed && mounted) {
                await notifier.skipSession(widget.sessionId);
              }
            },
          ),
          title: Column(
            children: [
              const Text(
                'Anonymous Match',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              if (partnerLiked)
                const Text(
                  'They liked you!',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6C63FF)),
                ),
            ],
          ),
          centerTitle: true,
          actions: [
            _TimerBadge(
              label: _formatDuration(_remaining),
              isLow: isTimeLow,
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _ChatList(messages: _messages),
            ),
            _MessageInput(
              controller: _inputController,
              onSend: _sendMessage,
            ),
            _ActionBar(
              iLiked: iLiked,
              onLike: iLiked ? null : () => notifier.like(widget.sessionId),
              onSkip: () async {
                final confirmed = await _confirmSkip(context);
                if (confirmed && mounted) {
                  await notifier.skipSession(widget.sessionId);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Timer badge ──────────────────────────────────────────────────────────────

class _TimerBadge extends StatelessWidget {
  const _TimerBadge({required this.label, required this.isLow});
  final String label;
  final bool isLow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isLow
            ? Color.fromRGBO(255, 0, 0, 0.12)
            : Color.fromRGBO(255, 255, 255, 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLow
              ? Color.fromRGBO(255, 100, 100, 0.6)
              : Colors.white24,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isLow ? Colors.redAccent : Colors.white,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ─── Chat list ────────────────────────────────────────────────────────────────

class _ChatList extends StatelessWidget {
  const _ChatList({required this.messages});
  final List<_ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: Text(
          'Say hello! Your identity is hidden.',
          style: TextStyle(color: Colors.white30, fontSize: 14),
        ),
      );
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[messages.length - 1 - index];
        return _MessageBubble(message: msg);
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? Color.fromRGBO(108, 99, 255, 0.85)
              : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Text(
          message.content,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
    );
  }
}

// ─── Message input ────────────────────────────────────────────────────────────

class _MessageInput extends StatelessWidget {
  const _MessageInput({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Message...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Color.fromRGBO(255, 255, 255, 0.06),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action bar ───────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.iLiked,
    required this.onLike,
    required this.onSkip,
  });

  final bool iLiked;
  final VoidCallback? onLike;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onSkip,
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Skip'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white54,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onLike,
              icon: Icon(
                iLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_outline_rounded,
                size: 18,
              ),
              label: Text(iLiked ? 'Liked!' : 'Like'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    iLiked ? Color.fromRGBO(108, 99, 255, 0.6) : primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
