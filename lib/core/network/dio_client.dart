import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../error/app_exception.dart';

final dioClientProvider = Provider<DioClient>((ref) => DioClient());

class DioClient {
  DioClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: dotenv.env['BACKEND_BASE_URL'] ?? 'http://localhost:3000',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(_JwtInterceptor());
    _dio.interceptors.add(_ErrorInterceptor());
  }

  late final Dio _dio;

  Dio get dio => _dio;
}

/// Reads the access token from Supabase's current session on every request.
/// Supabase handles token refresh automatically, so this is always fresh.
class _JwtInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      final token = session.accessToken;
      final expiresAt = session.expiresAt;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final preview = token.length > 20 ? token.substring(0, 20) : token;
      debugPrint('[JWT] Session exists | expiresAt: $expiresAt | now: $now | expired: ${expiresAt != null && expiresAt < now}');
      debugPrint('[JWT] Token prefix: $preview... (len=${token.length})');
      options.headers['Authorization'] = 'Bearer $token';
    } else {
      debugPrint('[JWT] WARNING: No active Supabase session — request will be sent without Authorization header');
    }
    debugPrint('[JWT] ${options.method} ${options.baseUrl}${options.path}');
    handler.next(options);
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;
    final message = err.response?.data?['message'] as String? ??
        err.message ??
        'Unknown network error';
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: NetworkException(message, statusCode: statusCode),
        response: err.response,
        type: err.type,
      ),
    );
  }
}
