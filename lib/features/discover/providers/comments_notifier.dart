import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/discover_models.dart';
import '../data/discover_repository.dart';
import 'feed_notifier.dart';

// ─── State ────────────────────────────────────────────────────────────────────

sealed class CommentsState {
  const CommentsState();
}

final class CommentsLoading extends CommentsState {
  const CommentsLoading();
}

final class CommentsLoaded extends CommentsState {
  const CommentsLoaded({
    required this.comments,
    required this.hasMore,
    this.nextCursor,
    this.isLoadingMore = false,
    // True while addComment request is in flight — UI disables submit button
    // and shows a spinner. No optimistic insert: real ID is needed immediately
    // for deleteComment to work without reconciliation overhead.
    this.isSubmitting = false,
    this.submitError,
  });

  final List<DiscoverComment> comments;
  final bool hasMore;
  final String? nextCursor;
  final bool isLoadingMore;
  final bool isSubmitting;
  // Non-null on addComment failure. UI shows a SnackBar then calls clearSubmitError().
  final String? submitError;

  CommentsLoaded copyWith({
    List<DiscoverComment>? comments,
    bool? hasMore,
    String? nextCursor,
    bool? isLoadingMore,
    bool? isSubmitting,
    String? submitError,
    bool clearSubmitError = false,
  }) {
    return CommentsLoaded(
      comments: comments ?? this.comments,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError:
          clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }
}

final class CommentsError extends CommentsState {
  const CommentsError(this.message);
  final String message;
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class CommentsNotifier extends StateNotifier<CommentsState> {
  CommentsNotifier(this._postId, this._repo, this._feedNotifier)
      : super(const CommentsLoading()) {
    _load();
  }

  final String _postId;
  final DiscoverRepository _repo;
  final FeedNotifier _feedNotifier;

  // ─── Init ────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final page = await _repo.getComments(_postId);
      state = CommentsLoaded(
        comments: page.items,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    } catch (e) {
      state = CommentsError(_friendlyError(e));
    }
  }

  Future<void> refresh() async {
    state = const CommentsLoading();
    await _load();
  }

  // ─── Pagination ───────────────────────────────────────────────────────────

  Future<void> loadMore() async {
    final current = state;
    if (current is! CommentsLoaded) return;
    if (!current.hasMore || current.isLoadingMore) return;

    state = current.copyWith(isLoadingMore: true);
    try {
      final page = await _repo.getComments(_postId, before: current.nextCursor);
      final loaded = state;
      if (loaded is! CommentsLoaded) return;
      // Backend returns newest-first; older pages append to end of list.
      state = loaded.copyWith(
        comments: [...loaded.comments, ...page.items],
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
        isLoadingMore: false,
      );
    } catch (_) {
      final loaded = state;
      if (loaded is! CommentsLoaded) return;
      state = loaded.copyWith(isLoadingMore: false);
    }
  }

  // ─── Add comment (spinner, not optimistic) ────────────────────────────────

  Future<void> addComment(String content) async {
    final current = state;
    if (current is! CommentsLoaded) return;
    if (current.isSubmitting) return;

    state = current.copyWith(isSubmitting: true, clearSubmitError: true);
    try {
      final comment = await _repo.addComment(_postId, content);
      final loaded = state;
      if (loaded is! CommentsLoaded) return;
      // Prepend: the new comment is the most recent.
      state = loaded.copyWith(
        comments: [comment, ...loaded.comments],
        isSubmitting: false,
      );
      _feedNotifier.incrementCommentCount(_postId);
    } catch (e) {
      final loaded = state;
      if (loaded is! CommentsLoaded) return;
      state = loaded.copyWith(
        isSubmitting: false,
        submitError: _friendlyError(e),
      );
    }
  }

  void clearSubmitError() {
    final current = state;
    if (current is! CommentsLoaded) return;
    state = current.copyWith(clearSubmitError: true);
  }

  // ─── Delete comment ───────────────────────────────────────────────────────

  Future<void> deleteComment(String commentId) async {
    await _repo.deleteComment(commentId);
    final current = state;
    if (current is! CommentsLoaded) return;
    state = current.copyWith(
      comments: current.comments.where((c) => c.id != commentId).toList(),
    );
    _feedNotifier.decrementCommentCount(_postId);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('404')) return 'Post no longer exists.';
    if (msg.contains('NetworkException') || msg.contains('SocketException')) {
      return 'No connection. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}

// family provider — one CommentsNotifier per postId
final commentsNotifierProvider = StateNotifierProvider.family<
    CommentsNotifier, CommentsState, String>(
  (ref, postId) => CommentsNotifier(
    postId,
    ref.read(discoverRepositoryProvider),
    ref.read(feedNotifierProvider.notifier),
  ),
);
