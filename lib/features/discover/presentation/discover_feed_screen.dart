import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/discover_models.dart';
import '../providers/feed_notifier.dart';
import 'comments_sheet.dart';
import 'create_post_screen.dart';
import 'fullscreen_image_viewer.dart';

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
                            return _PostCard(post: posts[index]);
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

// ─── Post card ────────────────────────────────────────────────────────────────

class _PostCard extends ConsumerStatefulWidget {
  const _PostCard({required this.post});
  final DiscoverPost post;

  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartCtrl;
  late final Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _heartCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  void _onLikeTap() {
    _heartCtrl.forward(from: 0);
    ref.read(feedNotifierProvider.notifier).toggleLike(widget.post.id);
  }

  void _onCommentTap(BuildContext context) {
    showCommentsSheet(context, postId: widget.post.id);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final post = widget.post;
    final author = post.author;
    final imageWidth = (MediaQuery.of(context).size.width - 32) * 0.38;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Author row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              _Avatar(url: author.avatarUrl, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${author.username}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _formatTimestamp(post.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Caption — left-aligned with username (16 outer + 36 avatar + 10 gap)
        if (post.caption != null && post.caption!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(62, 0, 16, 10),
            child: Text(
              post.caption!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
                height: 1.4,
              ),
            ),
          ),

        // Photo
        if (post.photoUrl != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: imageWidth,
                  child: AspectRatio(
                    aspectRatio: 4 / 5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FullscreenImageViewer(
                              imageUrl: post.photoUrl!,
                              heroTag: post.photoUrl!,
                            ),
                          ),
                        ),
                        child: Hero(
                          tag: post.photoUrl!,
                          child: CachedNetworkImage(
                            imageUrl: post.photoUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => ColoredBox(
                                color: cs.surfaceContainerHighest),
                            errorWidget: (_, _, _) => ColoredBox(
                                color: cs.surfaceContainerHighest),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),

        // Action row
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
          child: Row(
            children: [
              ScaleTransition(
                scale: _heartScale,
                child: IconButton(
                  icon: Icon(
                    post.liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: post.liked ? cs.primary : cs.onSurfaceVariant,
                    size: 22,
                  ),
                  onPressed: _onLikeTap,
                  splashRadius: 20,
                ),
              ),
              if (post.likeCount > 0)
                Text(
                  '${post.likeCount}',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: cs.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: () => _onCommentTap(context),
                splashRadius: 20,
              ),
              if (post.commentCount > 0)
                Text(
                  '${post.commentCount}',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),

        Divider(
          height: 1,
          thickness: 1,
          color: cs.outline.withValues(alpha: 0.4),
        ),
      ],
    );
  }
}

// ─── Shared avatar widget ─────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    ColoredBox(color: cs.surfaceContainerHighest),
                errorWidget: (_, _, _) => _AvatarFallback(cs: cs),
              )
            : _AvatarFallback(cs: cs),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: cs.surfaceContainerHighest,
        child: Center(
          child: Icon(Icons.person_rounded,
              color: cs.onSurfaceVariant, size: 20),
        ),
      );
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
            child: Text('Retry',
                style: TextStyle(color: cs.primary)),
          ),
        ],
      ),
    );
  }
}

// ─── Timestamp helper ─────────────────────────────────────────────────────────

String _formatTimestamp(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';

  final today = DateTime(now.year, now.month, now.day);
  final dtDay = DateTime(dt.year, dt.month, dt.day);
  final daysDiff = today.difference(dtDay).inDays;

  if (daysDiff == 1) return 'Yesterday';
  if (daysDiff < 7) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  }
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[dt.month - 1]} ${dt.day}';
}
