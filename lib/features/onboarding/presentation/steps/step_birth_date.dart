import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/onboarding_providers.dart';
import '../widgets/onboarding_button.dart';

bool _isAtLeast18(DateTime date) {
  final today = DateTime.now();
  final cutoff = DateTime(today.year - 18, today.month, today.day);
  return !date.isAfter(cutoff);
}

class StepBirthDate extends ConsumerStatefulWidget {
  const StepBirthDate({super.key});

  @override
  ConsumerState<StepBirthDate> createState() => _StepBirthDateState();
}

class _StepBirthDateState extends ConsumerState<StepBirthDate> {
  DateTime? _selected;
  bool _showUnderAgeError = false;

  @override
  void initState() {
    super.initState();
    _selected = ref.read(onboardingProvider).form.birthDate;
  }

  Future<void> _pick() async {
    final today = DateTime.now();
    final latest = DateTime(today.year - 18, today.month, today.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selected ?? latest,
      firstDate: DateTime(1920),
      lastDate: latest,
      helpText: 'Select your birthday',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: const Color(0xFF6C63FF),
              ),
        ),
        child: child!,
      ),
    );

    if (picked == null) return;

    final valid = _isAtLeast18(picked);
    setState(() {
      _selected = picked;
      _showUnderAgeError = !valid;
    });
  }

  String _format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / ${d.month.toString().padLeft(2, '0')} / ${d.year}';

  bool get _canContinue =>
      _selected != null && _isAtLeast18(_selected!) && !_showUnderAgeError;

  void _onContinue() {
    ref.read(onboardingProvider.notifier)
      ..updateBirthDate(_selected!)
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
                  'When were you born?',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You must be 18 or older to use this app.',
                  style: TextStyle(fontSize: 15, color: Colors.white54),
                ),
                const SizedBox(height: 40),
                GestureDetector(
                  onTap: _pick,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _showUnderAgeError
                            ? const Color(0xFFEF5350)
                            : _selected != null
                                ? const Color(0xFF6C63FF)
                                : Colors.white12,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 20,
                          color: _selected != null
                              ? const Color(0xFF6C63FF)
                              : Colors.white38,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _selected != null
                              ? _format(_selected!)
                              : 'Tap to select your birthday',
                          style: TextStyle(
                            fontSize: 16,
                            color: _selected != null ? Colors.white : Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showUnderAgeError) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      Icon(Icons.error_outline, size: 16, color: Color(0xFFEF5350)),
                      SizedBox(width: 6),
                      Text(
                        'You must be at least 18 years old.',
                        style: TextStyle(color: Color(0xFFEF5350), fontSize: 13),
                      ),
                    ],
                  ),
                ],
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
