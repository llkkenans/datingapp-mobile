import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../data/onboarding_repository.dart';
import '../models/interest.dart';
import '../models/onboarding_form.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository(ref.watch(dioClientProvider).dio);
});

final interestsProvider = FutureProvider<List<Interest>>((ref) {
  return ref.read(onboardingRepositoryProvider).fetchInterests();
});

// ---------------------------------------------------------------------------

class OnboardingState {
  const OnboardingState({
    this.step = 0,
    this.form = const OnboardingForm(),
    this.submitting = false,
    this.error,
    this.completed = false,
  });

  final int step;
  final OnboardingForm form;
  final bool submitting;
  final String? error;
  final bool completed;

  OnboardingState copyWith({
    int? step,
    OnboardingForm? form,
    bool? submitting,
    String? error,
    bool clearError = false,
    bool? completed,
  }) =>
      OnboardingState(
        step: step ?? this.step,
        form: form ?? this.form,
        submitting: submitting ?? this.submitting,
        error: clearError ? null : (error ?? this.error),
        completed: completed ?? this.completed,
      );
}

// ---------------------------------------------------------------------------

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier(this._repo) : super(const OnboardingState());

  final OnboardingRepository _repo;

  static const int totalSteps = 9;

  void nextStep() {
    if (state.step < totalSteps - 1) {
      state = state.copyWith(step: state.step + 1, clearError: true);
    }
  }

  void prevStep() {
    if (state.step > 0) {
      state = state.copyWith(step: state.step - 1, clearError: true);
    }
  }

  void updateUsername(String v) =>
      state = state.copyWith(form: state.form.copyWith(username: v));

  void updateBirthDate(DateTime v) =>
      state = state.copyWith(form: state.form.copyWith(birthDate: v));

  void updateGender(String v) =>
      state = state.copyWith(form: state.form.copyWith(gender: v));

  void updatePreferredGender(String v) =>
      state = state.copyWith(form: state.form.copyWith(preferredGender: v));

  void updateCity(String v) =>
      state = state.copyWith(form: state.form.copyWith(city: v));

  void updateAvatarUrl(String v) =>
      state = state.copyWith(form: state.form.copyWith(avatarUrl: v));

  void updateInterestIds(List<String> ids) =>
      state = state.copyWith(form: state.form.copyWith(interestIds: ids));

  void updateBio(String v) =>
      state = state.copyWith(form: state.form.copyWith(bio: v));

  void updateTermsAccepted(bool v) =>
      state = state.copyWith(form: state.form.copyWith(termsAccepted: v));

  Future<bool> checkUsernameAvailable(String username) =>
      _repo.checkUsernameAvailable(username);

  Future<void> uploadAvatar(File file) async {
    final url = await _repo.uploadAvatar(file);
    updateAvatarUrl(url);
  }

  Future<void> submit() async {
    state = state.copyWith(submitting: true, clearError: true);
    try {
      await _repo.completeOnboarding(state.form);
      state = state.copyWith(submitting: false, completed: true);
    } catch (e) {
      final msg = e.toString();
      final displayMsg = msg.toLowerCase().contains('username')
          ? 'This username is already taken. Please go back and choose another.'
          : 'Could not complete your profile. Please try again.';
      state = state.copyWith(submitting: false, error: displayMsg);
    }
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier(ref.read(onboardingRepositoryProvider));
});
