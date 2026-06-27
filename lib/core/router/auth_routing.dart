import 'package:dio/dio.dart';

/// Calls GET /api/v1/users/me and returns the correct post-auth route.
/// Falls back to /onboarding if the backend is unreachable (e.g. during
/// development before the backend is running).
Future<String> determineAuthenticatedRoute(Dio dio) async {
  try {
    final response = await dio.get('/api/v1/users/me');
    final data = response.data as Map<String, dynamic>?;
    final onboardingCompleted = data?['onboardingCompleted'] == true;
    return onboardingCompleted ? '/discover' : '/onboarding';
  } catch (_) {
    return '/onboarding';
  }
}
