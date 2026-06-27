import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/onboarding_providers.dart';
import '../widgets/onboarding_button.dart';

class StepCity extends ConsumerStatefulWidget {
  const StepCity({super.key});

  @override
  ConsumerState<StepCity> createState() => _StepCityState();
}

class _StepCityState extends ConsumerState<StepCity> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: ref.read(onboardingProvider).form.city);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _canContinue => _ctrl.text.trim().length >= 2;

  void _onContinue() {
    ref.read(onboardingProvider.notifier)
      ..updateCity(_ctrl.text.trim())
      ..nextStep();
  }

  @override
  Widget build(BuildContext context) {
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
                  'Which city are you in?',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'We use city-level location only — never your exact address.',
                  style: TextStyle(fontSize: 15, color: Colors.white54),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    if (_canContinue) _onContinue();
                  },
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'e.g. Istanbul, New York, London',
                    hintStyle: const TextStyle(color: Colors.white30),
                    prefixIcon: const Icon(Icons.location_city_outlined,
                        color: Colors.white38),
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
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: OnboardingButton(
            label: 'Continue',
            enabled: _canContinue,
            onPressed: _onContinue,
          ),
        ),
      ],
    );
  }
}
