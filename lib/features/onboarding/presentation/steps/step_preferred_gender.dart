import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/onboarding_providers.dart';
import '../widgets/onboarding_button.dart';
import '../widgets/selection_card.dart';

const _options = [
  ('MALE', 'Men', '👨'),
  ('FEMALE', 'Women', '👩'),
  ('OTHER', 'Non-binary / Other people', '🧑'),
  ('ANY', 'Everyone', '🌈'),
];

class StepPreferredGender extends ConsumerWidget {
  const StepPreferredGender({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider).form.preferredGender;
    final notifier = ref.read(onboardingProvider.notifier);

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
                  "I'm interested in...",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'We use this to find you better matches.',
                  style: TextStyle(fontSize: 15, color: Colors.white54),
                ),
                const SizedBox(height: 32),
                for (final (value, label, emoji) in _options) ...[
                  SelectionCard(
                    label: label,
                    emoji: emoji,
                    selected: selected == value,
                    onTap: () => notifier.updatePreferredGender(value),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: OnboardingButton(
            label: 'Continue',
            enabled: selected != null,
            onPressed: notifier.nextStep,
          ),
        ),
      ],
    );
  }
}
