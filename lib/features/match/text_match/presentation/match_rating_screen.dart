import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/match_repository.dart';
import '../../providers/text_match_notifier.dart';
import '../../providers/voice_match_notifier.dart';

class MatchRatingScreen extends ConsumerStatefulWidget {
  const MatchRatingScreen({
    super.key,
    required this.sessionId,
    this.isVoiceMatch = false,
  });
  final String sessionId;
  final bool isVoiceMatch;

  @override
  ConsumerState<MatchRatingScreen> createState() => _MatchRatingScreenState();
}

class _MatchRatingScreenState extends ConsumerState<MatchRatingScreen> {
  int _stars = 0;
  bool _submitted = false;
  bool _submitting = false;
  String? _submitError;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(108, 99, 255, 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.star_rounded, color: primary, size: 40),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Rate this match',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your rating is private and helps improve future match quality.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white54),
                ),
                const SizedBox(height: 40),
                _StarRow(
                  value: _stars,
                  onChanged: _submitted ? null : (v) => setState(() => _stars = v),
                ),
                const SizedBox(height: 48),
                if (_submitted)
                  _SubmittedState(onDone: _done)
                else
                  _SubmitActions(
                    canSubmit: _stars > 0 && !_submitting,
                    isLoading: _submitting,
                    errorMessage: _submitError,
                    onSubmit: _submit,
                    onSkip: _done,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      await ref.read(matchRepositoryProvider).submitRating(
            sessionId: widget.sessionId,
            stars: _stars,
          );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 409) {
        // Already rated — treat as success
        setState(() {
          _submitting = false;
          _submitted = true;
        });
      } else {
        setState(() {
          _submitting = false;
          _submitError = 'Something went wrong. Please try again.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = 'Something went wrong. Please try again.';
      });
    }
  }

  void _done() {
    if (widget.isVoiceMatch) {
      ref.read(voiceMatchNotifierProvider.notifier).reset();
    } else {
      ref.read(textMatchNotifierProvider.notifier).reset();
    }
    context.go('/match');
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final filled = i < value;
        return GestureDetector(
          onTap: onChanged != null ? () => onChanged!(i + 1) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 44,
              color: filled ? const Color(0xFFFFD700) : Colors.white24,
            ),
          ),
        );
      }),
    );
  }
}

class _SubmitActions extends StatelessWidget {
  const _SubmitActions({
    required this.canSubmit,
    required this.isLoading,
    required this.onSubmit,
    required this.onSkip,
    this.errorMessage,
  });
  final bool canSubmit;
  final bool isLoading;
  final VoidCallback onSubmit;
  final VoidCallback onSkip;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: canSubmit ? onSubmit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit Rating', style: TextStyle(fontSize: 16)),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        ],
        const SizedBox(height: 12),
        TextButton(
          onPressed: onSkip,
          child: const Text(
            'Skip',
            style: TextStyle(color: Colors.white38),
          ),
        ),
      ],
    );
  }
}

class _SubmittedState extends StatelessWidget {
  const _SubmittedState({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.check_circle_outline_rounded,
            color: Colors.greenAccent, size: 44),
        const SizedBox(height: 12),
        const Text(
          'Thanks for rating!',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: onDone,
          child: const Text('Back to Match'),
        ),
      ],
    );
  }
}
