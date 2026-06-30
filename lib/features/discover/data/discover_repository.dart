import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import 'discover_models.dart';

class DiscoverRepository {
  DiscoverRepository(this._dio);

  final Dio _dio;

  Future<FeedPage> getFeed({String? before, String? authorId}) async {
    final params = <String, dynamic>{};
    if (before != null) params['before'] = before;
    if (authorId != null) params['authorId'] = authorId;
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/v1/discover/feed',
      queryParameters: params.isNotEmpty ? params : null,
    );
    return FeedPage.fromJson(res.data!);
  }

  Future<DiscoverPost> createPost({
    String? caption,
    File? photoFile,
  }) async {
    final formData = FormData();
    if (caption != null && caption.isNotEmpty) {
      formData.fields.add(MapEntry('caption', caption));
    }
    if (photoFile != null) {
      formData.files.add(MapEntry(
        'file',
        await MultipartFile.fromFile(photoFile.path),
      ));
    }
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/discover/posts',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return DiscoverPost.fromJson(res.data!);
  }

  Future<void> deletePost(String postId) async {
    await _dio.delete<void>('/api/v1/discover/posts/$postId');
  }

  Future<({bool liked, int likeCount})> likePost(String postId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/discover/posts/$postId/like',
    );
    final data = res.data!;
    return (liked: data['liked'] as bool, likeCount: data['likeCount'] as int);
  }

  Future<({bool liked, int likeCount})> unlikePost(String postId) async {
    final res = await _dio.delete<Map<String, dynamic>>(
      '/api/v1/discover/posts/$postId/like',
    );
    final data = res.data!;
    return (liked: data['liked'] as bool, likeCount: data['likeCount'] as int);
  }

  Future<CommentPage> getComments(String postId, {String? before}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/v1/discover/posts/$postId/comments',
      queryParameters: before != null ? {'before': before} : null,
    );
    return CommentPage.fromJson(res.data!);
  }

  Future<DiscoverComment> addComment(String postId, String content) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/discover/posts/$postId/comments',
      data: {'content': content},
    );
    return DiscoverComment.fromJson(res.data!);
  }

  Future<void> deleteComment(String commentId) async {
    await _dio.delete<void>('/api/v1/discover/comments/$commentId');
  }
}

final discoverRepositoryProvider = Provider<DiscoverRepository>(
  (ref) => DiscoverRepository(ref.read(dioClientProvider).dio),
);
