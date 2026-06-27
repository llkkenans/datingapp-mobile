import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/onboarding_providers.dart';
import 'steps/step_bio.dart';
import 'steps/step_birth_date.dart';
import 'steps/step_city.dart';
import 'steps/step_gender.dart';
import 'steps/step_interests.dart';
import 'steps/step_photo.dart';
import 'steps/step_preferred_gender.dart';
import 'steps/step_terms.dart';
import 'steps/step_username.dart';

const _steps = <Widget>[
  StepUsername(),
  StepBirthDate(),
  StepGender(),
  StepPreferredGender(),
  StepCity(),
  StepPhoto(),
  StepInterests(),
  StepBio(),
  StepTerms(),
];

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<OnboardingState>(onboardingProvider, (_, state) {
      if (state.completed) context.go('/home');
    });

    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return PopScope(
      // Intercept all back presses and use them to go to the previous step.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && state.step > 0) notifier.prevStep();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: SafeArea(
          child: Column(
            children: [
              _ProgressHeader(
                step: state.step,
                totalSteps: _steps.length,
                onBack: state.step > 0 ? notifier.prevStep : null,
              ),
              Expanded(child: _steps[state.step]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.step,
    required this.totalSteps,
    this.onBack,
  });

  final int step;
  final int totalSteps;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 40,
                child: onBack != null
                    ? GestureDetector(
                        onTap: onBack,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      )
                    : null,
              ),
              const Spacer(),
              Text(
                'Step ${step + 1} of $totalSteps',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: (step + 1) / totalSteps),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            builder: (_, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF6C63FF),
                ),
                minHeight: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
