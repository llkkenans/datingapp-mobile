import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/feed_notifier.dart';
import 'create_post_screen.dart';
import 'widgets/post_card.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class DiscoverFeedScreen extends ConsumerStatefulWidget {
  const DiscoverFeedScreen({super.key});

  @override
  ConsumerState<DiscoverFeedScreen> createState() => _DiscoverFeedScreenState();
}

class _DiscoverFeedScreenState extends ConsumerState<DiscoverFeedScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(feedNotifierProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    ref.listen<FeedState>(feedNotifierProvider, (_, next) {
      if (next is FeedLoaded && next.likeError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.likeError!),
            backgroundColor: cs.surfaceContainerHighest,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        ref.read(feedNotifierProvider.notifier).clearLikeError();
      }
    });

    final state = ref.watch(feedNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Text(
          'Discover',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreatePostScreen()),
        ),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        child: const Icon(Icons.add),
      ),
      body: switch (state) {
        FeedLoading() => Center(
            child: CircularProgressIndicator(
              color: cs.primary,
              strokeWidth: 2,
            ),
          ),
        FeedError(:final message) => _ErrorState(
            message: message,
            onRetry: () => ref.read(feedNotifierProvider.notifier).refresh(),
          ),
        FeedLoaded(:final posts, :final hasMore, :final isLoadingMore) =>
          RefreshIndicator(
            color: cs.primary,
            backgroundColor: cs.surfaceContainerHighest,
            onRefresh: () => ref.read(feedNotifierProvider.notifier).refresh(),
            child: posts.isEmpty
                ? const CustomScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(),
                      ),
                    ],
                  )
                : CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == posts.length) {
                              return hasMore
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 24),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: cs.primary,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : const SizedBox(height: 32);
                            }
                            return PostCard(
                              post: posts[index],
                              onLikeTap: () => ref
                                  .read(feedNotifierProvider.notifier)
                                  .toggleLike(posts[index].id),
                            );
                          },
                          childCount: posts.length +
                              (hasMore || isLoadingMore ? 1 : 0),
                        ),
                      ),
                    ],
                  ),
          ),
      },
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.explore_outlined,
            size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.25)),
        const SizedBox(height: 16),
        Text(
          'Nothing here yet',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Be the first to share something\nwith the community.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ─── Error state ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: Text('Retry', style: TextStyle(color: cs.primary)),
          ),
        ],
      ),
    );
  }
}
