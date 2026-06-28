import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/messages_models.dart';
import '../providers/chat_notifier.dart';

// ─── Route args ───────────────────────────────────────────────────────────────

class ChatArgs {
  const ChatArgs({
    this.username,
    this.avatarUrl,
    this.isOnline = false,
  });
  final String? username;
  final String? avatarUrl;
  final bool isOnline;
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.conversationId,
    this.username,
    this.avatarUrl,
    this.isOnline = false,
  });

  final String conversationId;
  final String? username;
  final String? avatarUrl;
  final bool isOnline;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _picker = ImagePicker();
  bool _inputHasText = false;

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _inputController.addListener(() {
      final hasText = _inputController.text.trim().isNotEmpty;
      if (hasText != _inputHasText) setState(() => _inputHasText = hasText);
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 100) {
      ref
          .read(chatNotifierProvider(widget.conversationId).notifier)
          .loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _send() {
    final content = _inputController.text.trim();
    if (content.isEmpty) return;
    _inputController.clear();
    ref
        .read(chatNotifierProvider(widget.conversationId).notifier)
        .sendMessage(content);
  }

  Future<void> _pickPhoto() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (xfile == null || !mounted) return;
    ref
        .read(chatNotifierProvider(widget.conversationId).notifier)
        .sendPhoto(File(xfile.path));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatNotifierProvider(widget.conversationId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        titleSpacing: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _AppBarTitle(
          username: widget.username,
          avatarUrl: widget.avatarUrl,
          isOnline: widget.isOnline,
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          if (state is ChatLoaded && state.sendError != null)
            _ErrorBanner(
              message: state.sendError!,
              onDismiss: () => ref
                  .read(chatNotifierProvider(widget.conversationId).notifier)
                  .dismissSendError(),
            ),
          Expanded(
            child: switch (state) {
              ChatLoading() => const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF6C63FF),
                    strokeWidth: 2,
                  ),
                ),
              ChatError(:final message) => Center(
                  child: Text(
                    message,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ChatLoaded() => _MessageList(
                  state: state,
                  currentUserId: _currentUserId,
                  scrollController: _scrollController,
                ),
            },
          ),
          _InputBar(
            controller: _inputController,
            hasText: _inputHasText,
            onSend: _send,
            onPickPhoto: _pickPhoto,
          ),
        ],
      ),
    );
  }
}

// ─── AppBar title ─────────────────────────────────────────────────────────────

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({
    required this.username,
    required this.avatarUrl,
    required this.isOnline,
  });

  final String? username;
  final String? avatarUrl;
  final bool isOnline;

  static const _onlineGreen = Color(0xFF34C759);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 38,
          height: 38,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipOval(
                child: avatarUrl != null
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl!,
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            const ColoredBox(color: Color(0xFF2C2C2E)),
                        errorWidget: (_, _, _) =>
                            const _MiniAvatarFallback(),
                      )
                    : const SizedBox(
                        width: 34,
                        height: 34,
                        child: _MiniAvatarFallback(),
                      ),
              ),
              if (isOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: _onlineGreen,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF0F0F0F), width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  username != null ? '@$username' : 'Conversation',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isOnline) ...[
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _onlineGreen,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Message list ─────────────────────────────────────────────────────────────

sealed class _ListItem {}

class _MessageItem extends _ListItem {
  _MessageItem(this.message, {this.showStatus = false});
  final Message message;
  final bool showStatus;
}

class _DividerItem extends _ListItem {
  _DividerItem(this.date);
  final DateTime date;
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.state,
    required this.currentUserId,
    required this.scrollController,
  });

  final ChatLoaded state;
  final String currentUserId;
  final ScrollController scrollController;

  List<_ListItem> _buildItems(List<Message> messages) {
    // Find last outgoing non-pending message for the read receipt
    int lastOutgoingIdx = -1;
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].senderId == currentUserId && !messages[i].isPending) {
        lastOutgoingIdx = i;
        break;
      }
    }

    final items = <_ListItem>[];
    DateTime? lastDay;
    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final day = DateTime(
          msg.createdAt.year, msg.createdAt.month, msg.createdAt.day);
      if (lastDay == null || day != lastDay) {
        items.add(_DividerItem(day));
        lastDay = day;
      }
      items.add(_MessageItem(msg, showStatus: i == lastOutgoingIdx));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems(state.messages);
    final isLoadingMore = state.isLoadingMore;
    final totalCount = items.length + (isLoadingMore ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        // Pagination spinner — appears visually at the top
        if (isLoadingMore && index == items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Color(0xFF6C63FF),
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        }

        final item = items[items.length - 1 - index];
        return switch (item) {
          _DividerItem(:final date) => _DateDivider(date: date),
          _MessageItem(:final message, :final showStatus) => _Bubble(
              message: message,
              isMe: message.senderId == currentUserId,
              showStatus: showStatus,
            ),
        };
      },
    );
  }
}

// ─── Date divider ─────────────────────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});
  final DateTime date;

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    if (date.year == now.year) {
      return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
    }
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          _label,
          style: const TextStyle(fontSize: 11, color: Colors.white30),
        ),
      ),
    );
  }
}

// ─── Message bubble ───────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.isMe,
    required this.showStatus,
  });

  final Message message;
  final bool isMe;
  final bool showStatus;

  String get _statusLabel => switch (message.status) {
        MessageStatus.sent => 'Sent',
        MessageStatus.delivered => 'Delivered',
        MessageStatus.read => 'Read',
      };

  BorderRadius get _radius => BorderRadius.only(
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
        bottomLeft: Radius.circular(isMe ? 16 : 4),
        bottomRight: Radius.circular(isMe ? 4 : 16),
      );

  @override
  Widget build(BuildContext context) {
    final isPhoto =
        message.photoUrl != null || message.localFilePath != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Opacity(
              opacity: message.isPending ? 0.65 : 1.0,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width *
                      (isPhoto ? 0.60 : 0.72),
                ),
                child: isPhoto
                    ? _PhotoBubble(
                        message: message,
                        isMe: isMe,
                        radius: _radius,
                      )
                    : _TextBubble(
                        content: message.content ?? '',
                        isMe: isMe,
                        radius: _radius,
                      ),
              ),
            ),
          ),
          if (showStatus && isMe)
            Padding(
              padding: const EdgeInsets.only(top: 3, right: 2),
              child: Text(
                _statusLabel,
                style:
                    const TextStyle(fontSize: 10, color: Colors.white30),
              ),
            ),
        ],
      ),
    );
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({
    required this.content,
    required this.isMe,
    required this.radius,
  });
  final String content;
  final bool isMe;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? Color.fromRGBO(108, 99, 255, 0.85)
            : const Color(0xFF2C2C2E),
        borderRadius: radius,
      ),
      child: Text(
        content,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
    );
  }
}

// ─── Photo bubble ─────────────────────────────────────────────────────────────

class _PhotoBubble extends StatelessWidget {
  const _PhotoBubble({
    required this.message,
    required this.isMe,
    required this.radius,
  });

  final Message message;
  final bool isMe;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final heroTag = message.id;

    Widget image;
    if (message.localFilePath != null) {
      image = Image.file(File(message.localFilePath!), fit: BoxFit.cover);
    } else {
      image = CachedNetworkImage(
        imageUrl: message.photoUrl!,
        fit: BoxFit.cover,
        placeholder: (_, _) => const SizedBox(
          height: 160,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  color: Color(0xFF6C63FF), strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (_, _, _) => const SizedBox(
          height: 120,
          child: Center(
            child:
                Icon(Icons.broken_image_rounded, color: Colors.white38),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: message.photoUrl != null
          ? () => Navigator.push(
                context,
                PageRouteBuilder(
                  opaque: false,
                  barrierColor: Colors.black87,
                  pageBuilder: (_, _, _) => _PhotoViewer(
                    heroTag: heroTag,
                    imageUrl: message.photoUrl!,
                  ),
                  transitionsBuilder: (_, anim, _, child) =>
                      FadeTransition(opacity: anim, child: child),
                ),
              )
          : null,
      child: Hero(
        tag: heroTag,
        child: ClipRRect(borderRadius: radius, child: image),
      ),
    );
  }
}

// ─── Full-screen photo viewer ─────────────────────────────────────────────────

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.heroTag, required this.imageUrl});
  final String heroTag;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: Center(
          child: Hero(
            tag: heroTag,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Color.fromRGBO(255, 149, 0, 0.15),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFFF9500), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style:
                  const TextStyle(fontSize: 13, color: Color(0xFFFF9500)),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded,
                color: Color(0xFFFF9500), size: 16),
          ),
        ],
      ),
    );
  }
}

// ─── Input bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.hasText,
    required this.onSend,
    required this.onPickPhoto,
  });

  final TextEditingController controller;
  final bool hasText;
  final VoidCallback onSend;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPickPhoto,
            icon: const Icon(
              Icons.add_photo_alternate_outlined,
              color: Colors.white54,
              size: 22,
            ),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Message...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Color.fromRGBO(255, 255, 255, 0.06),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: hasText ? onSend : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: hasText
                    ? const Color(0xFF6C63FF)
                    : Color.fromRGBO(108, 99, 255, 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send_rounded,
                color: hasText ? Colors.white : Colors.white38,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _MiniAvatarFallback extends StatelessWidget {
  const _MiniAvatarFallback();
  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFF2C2C2E),
        child: Center(
          child:
              Icon(Icons.person_rounded, color: Colors.white38, size: 18),
        ),
      );
}
