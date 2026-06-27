import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/onboarding_providers.dart';
import '../widgets/onboarding_button.dart';

// No backend max documented — 10 is a sensible default for V1.
const _maxInterests = 10;

class StepInterests extends ConsumerWidget {
  const StepInterests({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIds = ref.watch(onboardingProvider).form.interestIds;
    final notifier = ref.read(onboardingProvider.notifier);
    final interestsAsync = ref.watch(interestsProvider);

    void toggle(String id) {
      final current = List<String>.from(selectedIds);
      if (current.contains(id)) {
        current.remove(id);
      } else if (current.length < _maxInterests) {
        current.add(id);
      }
      notifier.updateInterestIds(current);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: interestsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_outlined,
                      color: Colors.white38, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'Could not load interests.',
                    style: TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => ref.invalidate(interestsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (interests) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What are you into?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pick at least 1, up to $_maxInterests. '
                    '${selectedIds.length}/$_maxInterests selected.',
                    style: const TextStyle(fontSize: 15, color: Colors.white54),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: interests.map((interest) {
                      final selected = selectedIds.contains(interest.id);
                      final atMax =
                          selectedIds.length >= _maxInterests && !selected;
                      return FilterChip(
                        label: Text(interest.name),
                        selected: selected,
                        onSelected: atMax ? null : (_) => toggle(interest.id),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        backgroundColor: const Color(0xFF1C1C1E),
                        selectedColor:
                            const Color(0xFF6C63FF).withValues(alpha: 0.25),
                        checkmarkColor: const Color(0xFF6C63FF),
                        side: BorderSide(
                          color: selected
                              ? const Color(0xFF6C63FF)
                              : Colors.white12,
                          width: selected ? 1.5 : 1,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: OnboardingButton(
            label: 'Continue',
            enabled: selectedIds.isNotEmpty,
            onPressed: notifier.nextStep,
          ),
        ),
      ],
    );
  }
}
