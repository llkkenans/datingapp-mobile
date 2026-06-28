import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/discover_models.dart';
import '../data/discover_repository.dart';

// ─── State ────────────────────────────────────────────────────────────────────

sealed class FeedState {
  const FeedState();
}

final class FeedLoading extends FeedState {
  const FeedLoading();
}

final class FeedLoaded extends FeedState {
  const FeedLoaded({
    required this.posts,
    required this.hasMore,
    this.nextCursor,
    this.isLoadingMore = false,
    // Non-null when a like/unlike call fails. UI should show a brief SnackBar
    // then call clearLikeError() so it won't re-trigger on rebuild.
    this.likeError,
  });

  final List<DiscoverPost> posts;
  final bool hasMore;
  final String? nextCursor;
  final bool isLoadingMore;
  final String? likeError;

  FeedLoaded copyWith({
    List<DiscoverPost>? posts,
    bool? hasMore,
    String? nextCursor,
    bool? isLoadingMore,
    String? likeError,
    bool clearLikeError = false,
  }) {
    return FeedLoaded(
      posts: posts ?? this.posts,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      likeError: clearLikeError ? null : (likeError ?? this.likeError),
    );
  }
}

final class FeedError extends FeedState {
  const FeedError(this.message);
  final String message;
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class FeedNotifier extends StateNotifier<FeedState> {
  FeedNotifier(this._repo) : super(const FeedLoading()) {
    _load();
  }

  final DiscoverRepository _repo;

  // ─── Init / refresh ───────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final page = await _repo.getFeed();
      state = FeedLoaded(
        posts: page.items,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    } catch (e) {
      state = FeedError(_friendlyError(e));
    }
  }

  Future<void> refresh() async {
    state = const FeedLoading();
    await _load();
  }

  // ─── Pagination ───────────────────────────────────────────────────────────

  Future<void> loadMore() async {
    final current = state;
    if (current is! FeedLoaded) return;
    if (!current.hasMore || current.isLoadingMore) return;

    state = current.copyWith(isLoadingMore: true);
    try {
      final page = await _repo.getFeed(before: current.nextCursor);
      final loaded = state;
      if (loaded is! FeedLoaded) return;
      state = loaded.copyWith(
        posts: [...loaded.posts, ...page.items],
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
        isLoadingMore: false,
      );
    } catch (_) {
      final loaded = state;
      if (loaded is! FeedLoaded) return;
      state = loaded.copyWith(isLoadingMore: false);
    }
  }

  // ─── Like / unlike (optimistic) ───────────────────────────────────────────

  Future<void> toggleLike(String postId) async {
    final current = state;
    if (current is! FeedLoaded) return;

    final idx = current.posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;

    final original = current.posts[idx];
    final wasLiked = original.liked;

    // Optimistic update
    final optimistic = original.copyWith(
      liked: !wasLiked,
      likeCount: wasLiked ? original.likeCount - 1 : original.likeCount + 1,
    );
    state = current.copyWith(
      posts: _replaceAt(current.posts, idx, optimistic),
      clearLikeError: true,
    );

    try {
      final result =
          wasLiked ? await _repo.unlikePost(postId) : await _repo.likePost(postId);

      // Apply server-authoritative likeCount in case of concurrent likes
      final loaded = state;
      if (loaded is! FeedLoaded) return;
      final confirmedIdx = loaded.posts.indexWhere((p) => p.id == postId);
      if (confirmedIdx == -1) return;
      state = loaded.copyWith(
        posts: _replaceAt(
          loaded.posts,
          confirmedIdx,
          loaded.posts[confirmedIdx].copyWith(
            liked: result.liked,
            likeCount: result.likeCount,
          ),
        ),
      );
    } catch (_) {
      // Revert optimistic change and surface error for SnackBar
      final loaded = state;
      if (loaded is! FeedLoaded) return;
      final revertIdx = loaded.posts.indexWhere((p) => p.id == postId);
      if (revertIdx == -1) return;
      state = loaded.copyWith(
        posts: _replaceAt(loaded.posts, revertIdx, original),
        likeError: 'Could not update like. Please try again.',
      );
    }
  }

  void clearLikeError() {
    final current = state;
    if (current is! FeedLoaded) return;
    state = current.copyWith(clearLikeError: true);
  }

  // ─── Create post ──────────────────────────────────────────────────────────

  Future<void> createPost({String? caption, File? photoFile}) async {
    final post = await _repo.createPost(caption: caption, photoFile: photoFile);
    final current = state;
    if (current is! FeedLoaded) return;
    state = current.copyWith(posts: [post, ...current.posts]);
  }

  // ─── Delete post ──────────────────────────────────────────────────────────

  Future<void> deletePost(String postId) async {
    await _repo.deletePost(postId);
    final current = state;
    if (current is! FeedLoaded) return;
    state = current.copyWith(
      posts: current.posts.where((p) => p.id != postId).toList(),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  List<DiscoverPost> _replaceAt(
    List<DiscoverPost> list,
    int idx,
    DiscoverPost replacement,
  ) {
    final updated = List<DiscoverPost>.from(list);
    updated[idx] = replacement;
    return updated;
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('401') || msg.contains('403')) {
      return 'Session expired. Please log in again.';
    }
    if (msg.contains('NetworkException') || msg.contains('SocketException')) {
      return 'No connection. Pull to refresh.';
    }
    return 'Could not load feed. Pull to refresh.';
  }
}

final feedNotifierProvider =
    StateNotifierProvider<FeedNotifier, FeedState>(
  (ref) => FeedNotifier(ref.read(discoverRepositoryProvider)),
);
