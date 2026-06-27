import 'dart:io';
import 'package:dio/dio.dart';
import '../models/interest.dart';
import '../models/onboarding_form.dart';

class OnboardingRepository {
  OnboardingRepository(this._dio);

  final Dio _dio;

  Future<bool> checkUsernameAvailable(String username) async {
    final response = await _dio.get(
      '/api/v1/onboarding/check-username',
      queryParameters: {'username': username},
    );
    return response.data['available'] as bool;
  }

  Future<List<Interest>> fetchInterests() async {
    final response = await _dio.get('/api/v1/interests');
    return (response.data as List)
        .map((e) => Interest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> uploadAvatar(File file) async {
    final filename = file.path.split('/').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: filename),
    });
    final response = await _dio.post(
      '/api/v1/profiles/me/avatar',
      data: formData,
    );
    return response.data['avatarUrl'] as String;
  }

  Future<void> completeOnboarding(OnboardingForm form) async {
    final date = form.birthDate!;
    final birthDate =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    await _dio.post('/api/v1/onboarding/complete', data: {
      'username': form.username,
      'birthDate': birthDate,
      'gender': form.gender,
      'preferredGender': form.preferredGender,
      'city': form.city,
      if (form.bio.isNotEmpty) 'bio': form.bio,
      'interestIds': form.interestIds,
    });
  }
}
