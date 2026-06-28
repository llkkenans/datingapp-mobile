import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/messages_models.dart';
import '../providers/conversation_list_notifier.dart';
import 'chat_detail_screen.dart';

class ConversationListScreen extends ConsumerWidget {
  const ConversationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationListNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        titleSpacing: 20,
        title: const Text(
          'Messages',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
      ),
      body: switch (state) {
        ConversationListLoading() => const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF6C63FF),
              strokeWidth: 2,
            ),
          ),
        ConversationListError(:final message) => _ErrorState(
            message: message,
            onRetry: () => ref
                .read(conversationListNotifierProvider.notifier)
                .refresh(),
          ),
        ConversationListLoaded(:final conversations) => RefreshIndicator(
            color: const Color(0xFF6C63FF),
            backgroundColor: const Color(0xFF1C1C1E),
            onRefresh: () => ref
                .read(conversationListNotifierProvider.notifier)
                .refresh(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (conversations.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _ConversationTile(
                        conversation: conversations[index],
                      ),
                      childCount: conversations.length,
                    ),
                  ),
              ],
            ),
          ),
      },
    );
  }
}

// ─── Conversation tile ────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});
  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final user = conversation.otherUser;
    final last = conversation.lastMessage;
    final hasUnread = conversation.unreadCount > 0;

    return InkWell(
      onTap: () => context.push(
        '/messages/${conversation.id}',
        extra: ChatArgs(
          username: user.username,
          avatarUrl: user.avatarUrl,
          isOnline: user.isOnline,
        ),
      ),
      splashColor: Color.fromRGBO(255, 255, 255, 0.04),
      highlightColor: Color.fromRGBO(255, 255, 255, 0.02),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _AvatarStack(
              url: user.avatarUrl,
              isOnline: user.isOnline,
              fromMatch: conversation.fromMatch,
              unreadCount: conversation.unreadCount,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '@${user.username}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w600,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimestamp(
                            conversation.lastMessageAt ?? conversation.createdAt),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white30),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _lastMessagePreview(last),
                    style: TextStyle(
                      fontSize: 13,
                      color: hasUnread ? Colors.white54 : Colors.white38,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _lastMessagePreview(LastMessage? last) {
    if (last == null) return 'Say hello!';
    if (last.content != null && last.content!.isNotEmpty) return last.content!;
    if (last.photoUrl != null) return '📷 Photo';
    return '';
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';

    final today = DateTime(now.year, now.month, now.day);
    final dtDay = DateTime(dt.year, dt.month, dt.day);
    final daysDiff = today.difference(dtDay).inDays;

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
}

// ─── Avatar stack with indicators ────────────────────────────────────────────

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({
    required this.url,
    required this.isOnline,
    required this.fromMatch,
    required this.unreadCount,
  });

  final String? url;
  final bool isOnline;
  final bool fromMatch;
  final int unreadCount;

  static const _primary = Color(0xFF6C63FF);
  static const _onlineGreen = Color(0xFF34C759);
  static const _bg = Color(0xFF0F0F0F);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 5,
            left: 5,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: fromMatch
                    ? Border.all(color: _primary, width: 1.5)
                    : null,
              ),
              child: ClipOval(
                child: url != null
                    ? CachedNetworkImage(
                        imageUrl: url!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            const ColoredBox(color: Color(0xFF2C2C2E)),
                        errorWidget: (_, _, _) =>
                            const _AvatarFallback(),
                      )
                    : const _AvatarFallback(),
              ),
            ),
          ),

          // Online dot — bottom-right corner of the avatar
          if (isOnline)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: _onlineGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: _bg, width: 2),
                ),
              ),
            ),

          // Unread badge — top-right
          if (unreadCount > 0)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();
  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFF2C2C2E),
        child: Center(
          child: Icon(Icons.person_rounded, color: Colors.white38, size: 24),
        ),
      );
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.chat_bubble_outline_rounded,
            size: 56, color: Colors.white12),
        SizedBox(height: 16),
        Text(
          'No conversations yet',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white),
        ),
        SizedBox(height: 8),
        Text(
          'Conversations appear here\nafter a mutual match.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.white38, height: 1.5),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'Retry',
              style: TextStyle(color: Color(0xFF6C63FF)),
            ),
          ),
        ],
      ),
    );
  }
}
