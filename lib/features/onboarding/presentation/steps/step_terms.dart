import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/onboarding_providers.dart';
import '../widgets/onboarding_button.dart';

const _guidelines = [
  (Icons.favorite_outline, 'Be respectful', 'Treat every person with kindness. Harassment, hate speech, and discrimination are not tolerated.'),
  (Icons.no_photography_outlined, 'No inappropriate content', 'Do not share explicit, violent, or offensive photos or messages.'),
  (Icons.person_off_outlined, 'Real people only', 'Do not impersonate others or create fake profiles. Use your real identity.'),
  (Icons.report_gmailerrorred_outlined, 'Report bad behavior', 'Use the in-app report tools whenever you see something wrong. We review every report.'),
  (Icons.privacy_tip_outlined, 'Guard your privacy', 'Do not share personal details like your home address or financial information with strangers.'),
  (Icons.verified_user_outlined, 'Safety first', 'Meet in public for first in-person meetings. Trust your instincts.'),
];

class StepTerms extends ConsumerWidget {
  const StepTerms({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accepted = ref.watch(onboardingProvider).form.termsAccepted;
    final state = ref.watch(onboardingProvider);
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
                  'Community guidelines',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This community works because everyone respects these rules.',
                  style: TextStyle(fontSize: 15, color: Colors.white54),
                ),
                const SizedBox(height: 28),
                for (final (icon, title, body) in _guidelines) ...[
                  _GuidelineItem(icon: icon, title: title, body: body),
                  const SizedBox(height: 20),
                ],
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => notifier.updateTermsAccepted(!accepted),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: accepted,
                        onChanged: (v) =>
                            notifier.updateTermsAccepted(v ?? false),
                        activeColor: const Color(0xFF6C63FF),
                        side: const BorderSide(color: Colors.white38, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'I have read and agree to follow these community guidelines.',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 14, height: 1.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF5350).withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFEF5350).withValues(alpha:0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Color(0xFFEF5350), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            state.error!,
                            style: const TextStyle(
                                color: Color(0xFFEF5350), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: OnboardingButton(
            label: 'Finish and join',
            enabled: accepted,
            loading: state.submitting,
            onPressed: notifier.submit,
          ),
        ),
      ],
    );
  }
}

class _GuidelineItem extends StatelessWidget {
  const _GuidelineItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha:0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF6C63FF), size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
