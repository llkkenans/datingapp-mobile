import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/onboarding_providers.dart';
import '../widgets/onboarding_button.dart';
import '../widgets/selection_card.dart';

const _genderOptions = [
  ('MALE', 'Man', '👨'),
  ('FEMALE', 'Woman', '👩'),
  ('OTHER', 'Non-binary / Other', '🧑'),
];

class StepGender extends ConsumerWidget {
  const StepGender({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider).form.gender;
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
                  'I identify as...',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This helps us find more compatible matches for you.',
                  style: TextStyle(fontSize: 15, color: Colors.white54),
                ),
                const SizedBox(height: 32),
                for (final (value, label, emoji) in _genderOptions) ...[
                  SelectionCard(
                    label: label,
                    emoji: emoji,
                    selected: selected == value,
                    onTap: () => notifier.updateGender(value),
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
