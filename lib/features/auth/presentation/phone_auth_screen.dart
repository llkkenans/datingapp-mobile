import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_providers.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/auth_routing.dart';

class PhoneAuthScreen extends ConsumerStatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  ConsumerState<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends ConsumerState<PhoneAuthScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();

  bool _otpSent = false;
  String _confirmedPhone = '';

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;

    final phone = _phoneCtrl.text.trim();
    await ref.read(authNotifierProvider.notifier).sendPhoneOtp(phone);

    if (mounted && !ref.read(authNotifierProvider).hasError) {
      setState(() {
        _otpSent = true;
        _confirmedPhone = phone;
      });
    }
  }

  Future<void> _verifyOtp() async {
    if (!_otpFormKey.currentState!.validate()) return;

    final otp = _otpCtrl.text.trim();
    await ref
        .read(authNotifierProvider.notifier)
        .verifyPhoneOtp(_confirmedPhone, otp);

    if (mounted && !ref.read(authNotifierProvider).hasError) {
      final route = await determineAuthenticatedRoute(
        ref.read(dioClientProvider).dio,
      );
      if (mounted) context.go(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    ref.listen(authNotifierProvider, (_, next) {
      if (next.hasError) {
        final msg = _friendlyMessage(next.error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
        );
        ref.read(authNotifierProvider.notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            if (_otpSent) {
              setState(() {
                _otpSent = false;
                _otpCtrl.clear();
              });
            } else {
              context.pop();
            }
          },
        ),
        title: Text(_otpSent ? 'Enter code' : 'Phone number'),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _otpSent
              ? _OtpStep(
                  key: const ValueKey('otp'),
                  controller: _otpCtrl,
                  formKey: _otpFormKey,
                  phone: _confirmedPhone,
                  isLoading: isLoading,
                  onSubmit: _verifyOtp,
                  onResend: () async {
                    _otpCtrl.clear();
                    // Capture messenger before the async gap.
                    final messenger = ScaffoldMessenger.of(context);
                    await ref
                        .read(authNotifierProvider.notifier)
                        .sendPhoneOtp(_confirmedPhone);
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Verification code resent.'),
                        ),
                      );
                    }
                  },
                )
              : _PhoneStep(
                  key: const ValueKey('phone'),
                  controller: _phoneCtrl,
                  formKey: _phoneFormKey,
                  isLoading: isLoading,
                  onSubmit: _sendOtp,
                ),
        ),
      ),
    );
  }

  String _friendlyMessage(Object? error) {
    final raw = error?.toString() ?? '';
    final match = RegExp(r'AppException\(\d*\): (.+)').firstMatch(raw);
    if (match != null) return match.group(1)!;
    if (raw.isNotEmpty) return raw;
    return 'Something went wrong. Please try again.';
  }
}

// ── Phone entry step ─────────────────────────────────────────────────────────

class _PhoneStep extends StatelessWidget {
  const _PhoneStep({
    super.key,
    required this.controller,
    required this.formKey,
    required this.isLoading,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final GlobalKey<FormState> formKey;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter your phone number',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Include your country code, e.g. +14155552671',
              style: TextStyle(fontSize: 14, color: Colors.white54),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: controller,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[+\d]')),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Phone number is required.';
                }
                if (!RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(v.trim())) {
                  return 'Enter a valid number with country code (e.g. +14155552671).';
                }
                return null;
              },
              decoration: InputDecoration(
                hintText: '+1 415 555 2671',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF1C1C1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red),
                ),
                errorStyle: const TextStyle(color: Colors.redAccent),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: isLoading ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Send code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── OTP entry step ────────────────────────────────────────────────────────────

class _OtpStep extends StatelessWidget {
  const _OtpStep({
    super.key,
    required this.controller,
    required this.formKey,
    required this.phone,
    required this.isLoading,
    required this.onSubmit,
    required this.onResend,
  });

  final TextEditingController controller;
  final GlobalKey<FormState> formKey;
  final String phone;
  final bool isLoading;
  final VoidCallback onSubmit;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter the code',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We sent a 6-digit code to $phone',
              style: const TextStyle(fontSize: 14, color: Colors.white54),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                letterSpacing: 8,
              ),
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter the 6-digit code.';
                if (v.length != 6) return 'Code must be exactly 6 digits.';
                return null;
              },
              decoration: InputDecoration(
                counterText: '',
                hintText: '------',
                hintStyle: const TextStyle(
                  color: Colors.white24,
                  letterSpacing: 8,
                ),
                filled: true,
                fillColor: const Color(0xFF1C1C1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red),
                ),
                errorStyle: const TextStyle(color: Colors.redAccent),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: isLoading ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Verify',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: isLoading ? null : onResend,
                child: const Text(
                  'Resend code',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
