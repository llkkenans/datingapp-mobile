import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/onboarding_providers.dart';
import '../widgets/onboarding_button.dart';

enum _Status { idle, checking, available, taken, invalid }

final _usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');

class StepUsername extends ConsumerStatefulWidget {
  const StepUsername({super.key});

  @override
  ConsumerState<StepUsername> createState() => _StepUsernameState();
}

class _StepUsernameState extends ConsumerState<StepUsername> {
  late final TextEditingController _ctrl;
  _Status _status = _Status.idle;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(onboardingProvider).form.username;
    _ctrl = TextEditingController(text: saved);
    if (saved.isNotEmpty) _scheduleCheck(saved);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _status = _Status.idle;
        _error = null;
      });
      return;
    }

    if (trimmed.length < 3 || trimmed.length > 20) {
      setState(() {
        _status = _Status.invalid;
        _error = 'Must be 3–20 characters.';
      });
      return;
    }

    if (!_usernameRegex.hasMatch(trimmed)) {
      setState(() {
        _status = _Status.invalid;
        _error = 'Only letters, numbers and underscores allowed.';
      });
      return;
    }

    setState(() {
      _status = _Status.checking;
      _error = null;
    });
    _debounce = Timer(const Duration(milliseconds: 500), () => _check(trimmed));
  }

  void _scheduleCheck(String value) {
    final trimmed = value.trim();
    if (trimmed.length >= 3 &&
        trimmed.length <= 20 &&
        _usernameRegex.hasMatch(trimmed)) {
      _check(trimmed);
    }
  }

  Future<void> _check(String username) async {
    if (!mounted) return;
    setState(() => _status = _Status.checking);
    try {
      debugPrint('[Username] Checking availability for: $username');
      final available =
          await ref.read(onboardingProvider.notifier).checkUsernameAvailable(username);
      debugPrint('[Username] Response — available: $available');
      if (!mounted) return;
      setState(() {
        _status = available ? _Status.available : _Status.taken;
        _error = available ? null : 'This username is already taken.';
      });
    } on DioException catch (e) {
      debugPrint('[Username] DioException: ${e.type} | status: ${e.response?.statusCode} | message: ${e.message}');
      debugPrint('[Username] Response data: ${e.response?.data}');
      if (!mounted) return;
      setState(() {
        _status = _Status.idle;
        _error = 'Could not reach server (${e.response?.statusCode ?? e.type.name}). Check your connection.';
      });
    } catch (e) {
      debugPrint('[Username] Unexpected error: $e');
      if (!mounted) return;
      setState(() {
        _status = _Status.idle;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  Widget? get _suffixIcon {
    return switch (_status) {
      _Status.checking => const SizedBox(
          width: 16,
          height: 16,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      _Status.available => const Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50)),
      _Status.taken || _Status.invalid => const Icon(Icons.cancel_outlined, color: Color(0xFFEF5350)),
      _Status.idle => null,
    };
  }

  bool get _canContinue => _status == _Status.available;

  void _onContinue() {
    ref.read(onboardingProvider.notifier)
      ..updateUsername(_ctrl.text.trim())
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
                  'Pick a username',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This is how others will find you. You can only change it later by contacting support.',
                  style: TextStyle(fontSize: 15, color: Colors.white54),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _ctrl,
                  onChanged: _onChanged,
                  autofocus: true,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'e.g. alex_johnson',
                    hintStyle: const TextStyle(color: Colors.white30),
                    prefixText: '@',
                    prefixStyle: const TextStyle(color: Color(0xFF6C63FF), fontSize: 16),
                    suffixIcon: _suffixIcon,
                    errorText: _error,
                    errorStyle: const TextStyle(color: Color(0xFFEF5350)),
                    filled: true,
                    fillColor: const Color(0xFF1C1C1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                if (_status == _Status.available)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 14, color: Color(0xFF4CAF50)),
                        const SizedBox(width: 4),
                        Text(
                          '@${_ctrl.text.trim()} is available!',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF4CAF50)),
                        ),
                      ],
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
