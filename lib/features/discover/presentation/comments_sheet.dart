import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/discover_models.dart';
import '../providers/comments_notifier.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _kBg = Color(0xFF0F0F0F);
const _kSurface = Color(0xFF1C1C1E);
const _kAccent = Color(0xFF6C63FF);
const _kPlaceholder = Color(0xFF2C2C2E);

// ─── Entry point ──────────────────────────────────────────────────────────────

void showCommentsSheet(BuildContext context, {required String postId}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CommentsSheet(postId: postId),
  );
}

// ─── Sheet ────────────────────────────────────────────────────────────────────

class CommentsSheet extends ConsumerStatefulWidget {
  const CommentsSheet({super.key, required this.postId});
  final String postId;

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _inputFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(() => setState(() {}));
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(commentsNotifierProvider(widget.postId).notifier).loadMore();
    }
  }

  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    await ref
        .read(commentsNotifierProvider(widget.postId).notifier)
        .addComment(text);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CommentsState>(
      commentsNotifierProvider(widget.postId),
      (_, next) {
        if (next is CommentsLoaded && next.submitError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.submitError!),
              backgroundColor: _kSurface,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
          ref
              .read(commentsNotifierProvider(widget.postId).notifier)
              .clearSubmitError();
        }
      },
    );

    final state = ref.watch(commentsNotifierProvider(widget.postId));
    final isSubmitting =
        state is CommentsLoaded && state.isSubmitting;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.60,
      minChildSize: 0.40,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.60, 0.92],
      builder: (context, sheetScrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
                child: Row(
                  children: [
                    const Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white54, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, thickness: 1,
                  color: Colors.white.withValues(alpha: 0.08)),

              // Comment list
              Expanded(
                child: _CommentList(
                  postId: widget.postId,
                  state: state,
                  scrollController: sheetScrollCtrl,
                ),
              ),

              // Input bar
              Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Container(
                  decoration: BoxDecoration(
                    color: _kBg,
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _Avatar(
                        url: Supabase.instance.client.auth.currentUser
                            ?.userMetadata?['avatar_url'] as String?,
                        size: 32,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 120),
                          child: TextField(
                            controller: _textCtrl,
                            focusNode: _inputFocus,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Add a comment…',
                              hintStyle: const TextStyle(
                                fontSize: 14,
                                color: Colors.white38,
                              ),
                              filled: true,
                              fillColor: _kSurface,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Send button
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: isSubmitting
                            ? const Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(
                                  color: _kAccent,
                                  strokeWidth: 2,
                                ),
                              )
                            : IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.send_rounded,
                                  size: 22,
                                  color: _textCtrl.text.trim().isNotEmpty
                                      ? _kAccent
                                      : Colors.white24,
                                ),
                                onPressed: _textCtrl.text.trim().isNotEmpty
                                    ? _submit
                                    : null,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Comment list ─────────────────────────────────────────────────────────────

class _CommentList extends StatelessWidget {
  const _CommentList({
    required this.postId,
    required this.state,
    required this.scrollController,
  });

  final String postId;
  final CommentsState state;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      CommentsLoading() => const Center(
          child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2),
        ),
      CommentsError(:final message) => Center(
          child: Text(message,
              style: const TextStyle(color: Colors.white54, fontSize: 14)),
        ),
      CommentsLoaded(:final comments, :final hasMore, :final isLoadingMore) =>
        comments.isEmpty
            ? const Center(
                child: Text(
                  'No comments yet.\nBe the first!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 14, height: 1.5),
                ),
              )
            : ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: comments.length + (hasMore || isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == comments.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: _kAccent,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }
                  return _CommentTile(
                    comment: comments[index],
                    postId: postId,
                  );
                },
              ),
    };
  }
}

// ─── Comment tile ─────────────────────────────────────────────────────────────

class _CommentTile extends ConsumerWidget {
  const _CommentTile({required this.comment, required this.postId});
  final DiscoverComment comment;
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId =
        Supabase.instance.client.auth.currentUser?.id ?? '';
    final isOwn = comment.author.id == currentUserId;

    return GestureDetector(
      onLongPress: isOwn
          ? () => _confirmDelete(context, ref)
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(url: comment.author.avatarUrl, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '@${comment.author.username}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimestamp(comment.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.content,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kSurface,
        title: const Text(
          'Delete comment?',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(commentsNotifierProvider(postId).notifier)
          .deleteComment(comment.id);
    }
  }
}

// ─── Local avatar widget ──────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) => ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: url != null
              ? CachedNetworkImage(
                  imageUrl: url!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      const ColoredBox(color: _kPlaceholder),
                  errorWidget: (_, _, _) => const _AvatarFallback(),
                )
              : const _AvatarFallback(),
        ),
      );
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();
  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: _kPlaceholder,
        child:
            Center(child: Icon(Icons.person_rounded, color: Colors.white38, size: 18)),
      );
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
