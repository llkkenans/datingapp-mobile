import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/discover_models.dart';
import '../comments_sheet.dart';
import '../fullscreen_image_viewer.dart';

// ─── Card ─────────────────────────────────────────────────────────────────────

class PostCard extends StatefulWidget {
  const PostCard({super.key, required this.post, required this.onLikeTap});

  final DiscoverPost post;
  final VoidCallback onLikeTap;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
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
    widget.onLikeTap();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final post = widget.post;
    final author = post.author;
    final imageWidth = (MediaQuery.of(context).size.width - 78) * 0.38;

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

        // Caption
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
            padding: const EdgeInsets.fromLTRB(62, 0, 16, 0),
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
          padding: const EdgeInsets.fromLTRB(54, 4, 16, 4),
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
                onPressed: () => showCommentsSheet(
                  context,
                  postId: post.id,
                  postAuthorId: post.author.id,
                ),
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

// ─── Private helpers ──────────────────────────────────────────────────────────

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
                color: cs.onSurfaceVariant, size: 20)),
      );
}

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
