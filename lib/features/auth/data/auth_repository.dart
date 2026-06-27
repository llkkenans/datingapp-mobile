import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/error/app_exception.dart' as app;

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;
  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;

  Future<void> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.datingapp://login-callback/',
      );
    } on AuthException catch (e) {
      throw app.AuthException(e.message);
    } catch (_) {
      throw app.AuthException('Google sign-in failed. Please try again.');
    }
  }

  Future<void> signInWithApple() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'io.supabase.datingapp://login-callback/',
      );
    } on AuthException catch (e) {
      throw app.AuthException(e.message);
    } catch (_) {
      throw app.AuthException('Apple sign-in failed. Please try again.');
    }
  }

  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      if (response.user == null) {
        throw app.AuthException('Sign-up failed. Please try again.');
      }
      return response;
    } on AuthException catch (e) {
      throw app.AuthException(e.message);
    } on app.AuthException {
      rethrow;
    } catch (_) {
      throw app.AuthException('Sign-up failed. Please try again.');
    }
  }

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      throw app.AuthException(e.message);
    } catch (_) {
      throw app.AuthException('Sign-in failed. Please try again.');
    }
  }

  Future<void> sendPhoneOtp(String phone) async {
    try {
      await _client.auth.signInWithOtp(phone: phone);
    } on AuthException catch (e) {
      throw app.AuthException(e.message);
    } catch (_) {
      throw app.AuthException(
        'Failed to send verification code. Please try again.',
      );
    }
  }

  Future<AuthResponse> verifyPhoneOtp(String phone, String otp) async {
    try {
      return await _client.auth.verifyOTP(
        phone: phone,
        token: otp,
        type: OtpType.sms,
      );
    } on AuthException catch (e) {
      throw app.AuthException(e.message);
    } catch (_) {
      throw app.AuthException('Invalid code. Please try again.');
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw app.AuthException(e.message);
    } catch (_) {
      throw app.AuthException('Sign-out failed. Please try again.');
    }
  }
}
