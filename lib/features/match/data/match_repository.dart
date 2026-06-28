import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';

class MatchRepository {
  MatchRepository(this._dio);
  final Dio _dio;

  Future<void> enqueueText() async {
    await _dio.post<void>('/api/v1/match/text');
  }

  Future<void> cancelTextQueue() async {
    await _dio.delete<void>('/api/v1/match/text');
  }

  Future<void> enqueueVoice() async {
    final res = await _dio.post<dynamic>('/api/v1/match/voice');
    debugPrint('[MatchRepo] enqueueVoice → HTTP ${res.statusCode} | body: ${res.data}');
  }

  Future<void> cancelVoiceQueue() async {
    final res = await _dio.delete<dynamic>('/api/v1/match/voice');
    debugPrint('[MatchRepo] cancelVoiceQueue → HTTP ${res.statusCode}');
  }

  Future<Map<String, dynamic>> getSession(String sessionId) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/v1/match/sessions/$sessionId');
    return res.data!;
  }

  Future<Map<String, dynamic>> recordLike(String sessionId) async {
    final res =
        await _dio.post<Map<String, dynamic>>('/api/v1/match/sessions/$sessionId/like');
    return res.data!;
  }

  Future<void> endSession(String sessionId) async {
    await _dio.post<void>('/api/v1/match/sessions/$sessionId/end');
  }

  Future<void> submitRating({required String sessionId, required int stars}) async {
    await _dio.post<void>(
      '/api/v1/ratings',
      data: {'sessionId': sessionId, 'stars': stars},
    );
  }
}

final matchRepositoryProvider = Provider<MatchRepository>(
  (ref) => MatchRepository(ref.read(dioClientProvider).dio),
);
