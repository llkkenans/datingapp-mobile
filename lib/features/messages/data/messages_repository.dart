import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import 'messages_models.dart';

class MessagesRepository {
  MessagesRepository(this._dio);

  final Dio _dio;

  Future<List<Conversation>> getConversations() async {
    final res = await _dio.get<List<dynamic>>('/api/v1/conversations');
    return (res.data!)
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MessagesPage> getMessages(
    String conversationId, {
    String? before,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/v1/conversations/$conversationId/messages',
      queryParameters: before != null ? {'before': before} : null,
    );
    return MessagesPage.fromJson(res.data!);
  }

  Future<Message> sendMessage(
    String conversationId,
    String content,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/conversations/$conversationId/messages',
      data: {'content': content},
    );
    return Message.fromJson(res.data!);
  }

  Future<Message> sendPhotoMessage(
    String conversationId,
    File file,
  ) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
    });
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/conversations/$conversationId/messages/photo',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return Message.fromJson(res.data!);
  }

  Future<MarkReadResult> markRead(
    String conversationId,
    String messageId,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/conversations/$conversationId/messages/$messageId/read',
    );
    return MarkReadResult.fromJson(res.data!);
  }
}

final messagesRepositoryProvider = Provider<MessagesRepository>(
  (ref) => MessagesRepository(ref.read(dioClientProvider).dio),
);
