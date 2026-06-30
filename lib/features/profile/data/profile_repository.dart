import 'package:dio/dio.dart';
import '../models/browse_profile.dart';
import '../models/profile.dart';

class ProfileRepository {
  ProfileRepository(this._dio);

  final Dio _dio;

  Future<Profile> getMyProfile() async {
    final response = await _dio.get('/api/v1/profiles/me');
    return Profile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Profile> updateProfile({
    String? username,
    String? bio,
    String? city,
    String? gender,
    String? preferredGender,
    List<String>? interestIds,
  }) async {
    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    if (bio != null) body['bio'] = bio;
    if (city != null) body['city'] = city;
    if (gender != null) body['gender'] = gender;
    if (preferredGender != null) body['preferredGender'] = preferredGender;
    if (interestIds != null) body['interestIds'] = interestIds;
    final response = await _dio.patch('/api/v1/profiles/me', data: body);
    return Profile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<bool> checkUsernameAvailable(String username) async {
    final response = await _dio.get(
      '/api/v1/onboarding/check-username',
      queryParameters: {'username': username},
    );
    return response.data['available'] as bool;
  }

  Future<List<BrowseProfile>> browsePeople({int limit = 20}) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/profiles/browse',
      queryParameters: {'limit': limit},
    );
    return (response.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(BrowseProfile.fromJson)
        .toList();
  }
}
