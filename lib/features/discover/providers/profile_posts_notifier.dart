import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/discover_models.dart';
import '../data/discover_repository.dart';
import 'feed_notifier.dart';

class ProfilePostsNotifier extends StateNotifier<FeedState> {
  ProfilePostsNotifier(this._repo, this._userId) : super(const FeedLoading()) {
    _load();
  }

  final DiscoverRepository _repo;
  final String _userId;

  // ─── Init / refresh ───────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final page = await _repo.getFeed(authorId: _userId);
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
      final page = await _repo.getFeed(
        authorId: _userId,
        before: current.nextCursor,
      );
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

    final optimistic = original.copyWith(
      liked: !wasLiked,
      likeCount: wasLiked ? original.likeCount - 1 : original.likeCount + 1,
    );
    state = current.copyWith(
      posts: _replaceAt(current.posts, idx, optimistic),
      clearLikeError: true,
    );

    try {
      final result = wasLiked
          ? await _repo.unlikePost(postId)
          : await _repo.likePost(postId);

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
      return 'No connection.';
    }
    return 'Could not load posts.';
  }
}

final profilePostsNotifierProvider = StateNotifierProvider.family<
    ProfilePostsNotifier, FeedState, String>(
  (ref, userId) =>
      ProfilePostsNotifier(ref.read(discoverRepositoryProvider), userId),
);
