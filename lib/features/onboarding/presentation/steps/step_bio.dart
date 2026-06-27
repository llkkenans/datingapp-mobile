import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/onboarding_providers.dart';
import '../widgets/onboarding_button.dart';

const _maxBio = 500;

class StepBio extends ConsumerStatefulWidget {
  const StepBio({super.key});

  @override
  ConsumerState<StepBio> createState() => _StepBioState();
}

class _StepBioState extends ConsumerState<StepBio> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: ref.read(onboardingProvider).form.bio);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onContinue() {
    ref.read(onboardingProvider.notifier)
      ..updateBio(_ctrl.text.trim())
      ..nextStep();
  }

  void _onSkip() {
    ref.read(onboardingProvider.notifier)
      ..updateBio('')
      ..nextStep();
  }

  @override
  Widget build(BuildContext context) {
    final count = _ctrl.text.length;
    final overLimit = count > _maxBio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tell us about yourself',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A short bio helps others get to know you before you match.',
                  style: TextStyle(fontSize: 15, color: Colors.white54),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _ctrl,
                  maxLines: 5,
                  maxLength: _maxBio,
                  autofocus: false,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, height: 1.5),
                  decoration: InputDecoration(
                    hintText:
                        'Write something interesting — hobbies, what you\'re looking for, a fun fact...',
                    hintStyle: const TextStyle(
                        color: Colors.white30, fontSize: 15, height: 1.5),
                    filled: true,
                    fillColor: const Color(0xFF1C1C1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF6C63FF), width: 1.5),
                    ),
                    counterStyle: TextStyle(
                      color: overLimit
                          ? const Color(0xFFEF5350)
                          : Colors.white38,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: OnboardingButton(
            label: 'Continue',
            enabled: !overLimit,
            onPressed: _onContinue,
          ),
        ),
        Center(
          child: TextButton(
            onPressed: _onSkip,
            child: const Text(
              'Skip for now',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
