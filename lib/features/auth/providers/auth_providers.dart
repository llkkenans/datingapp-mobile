import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_repository.dart';

part 'auth_providers.g.dart';

@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepository(Supabase.instance.client);
}

/// Reactive stream of Supabase auth state changes.
/// Use this to react to sign-in / sign-out events across the app.
@riverpod
Stream<AuthState> authStateChanges(Ref ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
}

/// Exposes sign-in / sign-up / sign-out actions.
/// State is AsyncValue — check [state.isLoading] for loading spinners
/// and [state.error] for error messages.
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  FutureOr<void> build() {}

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithGoogle(),
    );
  }

  Future<void> signInWithApple() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithApple(),
    );
  }

  Future<void> signUpWithEmail(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signUpWithEmail(email, password),
    );
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithEmail(email, password),
    );
  }

  Future<void> sendPhoneOtp(String phone) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).sendPhoneOtp(phone),
    );
  }

  Future<void> verifyPhoneOtp(String phone, String otp) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).verifyPhoneOtp(phone, otp),
    );
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signOut(),
    );
  }

  void clearError() {
    if (state.hasError) state = const AsyncData(null);
  }
}
