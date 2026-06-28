import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/messages_socket_service.dart';
import '../data/messages_models.dart';
import '../data/messages_repository.dart';
import 'conversation_list_notifier.dart';

// ─── State ────────────────────────────────────────────────────────────────────

sealed class ChatState {
  const ChatState();
}

final class ChatLoading extends ChatState {
  const ChatLoading();
}

final class ChatLoaded extends ChatState {
  const ChatLoaded({
    required this.messages,
    required this.hasMore,
    this.nextCursor,
    this.isLoadingMore = false,
    this.sendError,
  });

  final List<Message> messages;
  final bool hasMore;
  final String? nextCursor;
  final bool isLoadingMore;
  // Set on failed send; cleared on next user action. UI shows a dismissible banner.
  final String? sendError;

  ChatLoaded copyWith({
    List<Message>? messages,
    bool? hasMore,
    String? nextCursor,
    bool? isLoadingMore,
    String? sendError,
    bool clearSendError = false,
  }) {
    return ChatLoaded(
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      sendError: clearSendError ? null : (sendError ?? this.sendError),
    );
  }
}

final class ChatError extends ChatState {
  const ChatError(this.message);
  final String message;
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(
    this._conversationId,
    this._repo,
    this._socket,
    this._convListNotifier,
  ) : super(const ChatLoading()) {
    _listenToSocket();
    _init();
  }

  final String _conversationId;
  final MessagesRepository _repo;
  final MessagesSocketService _socket;
  final ConversationListNotifier _convListNotifier;
  final List<StreamSubscription<dynamic>> _subs = [];

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  void _listenToSocket() {
    _subs
      ..add(_socket.onMessageNew.listen(_onMessageNew))
      ..add(_socket.onMessageRead.listen(_onMessageRead));
  }

  // ─── Init ────────────────────────────────────────────────────────────────

  Future<void> _init() async {
    try {
      final page = await _repo.getMessages(_conversationId);
      state = ChatLoaded(
        messages: page.messages,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
      _maybeMarkReadOnOpen(page.messages);
    } catch (e) {
      state = ChatError(_friendlyError(e));
    }
  }

  // ─── Pagination ───────────────────────────────────────────────────────────

  Future<void> loadMore() async {
    final current = state;
    if (current is! ChatLoaded) return;
    if (!current.hasMore || current.isLoadingMore) return;

    state = current.copyWith(isLoadingMore: true);
    try {
      final page = await _repo.getMessages(
        _conversationId,
        before: current.nextCursor,
      );
      final loaded = state;
      if (loaded is! ChatLoaded) return;
      state = loaded.copyWith(
        // Older messages prepended — list is oldest-first
        messages: [...page.messages, ...loaded.messages],
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
        isLoadingMore: false,
      );
    } catch (e) {
      final loaded = state;
      if (loaded is! ChatLoaded) return;
      state = loaded.copyWith(isLoadingMore: false, sendError: _friendlyError(e));
    }
  }

  // ─── Send text (optimistic) ───────────────────────────────────────────────

  Future<void> sendMessage(String content) async {
    final current = state;
    if (current is! ChatLoaded) return;

    final tempId = 'local_${DateTime.now().microsecondsSinceEpoch}';
    final pending = Message(
      id: tempId,
      conversationId: _conversationId,
      senderId: _currentUserId,
      content: content,
      status: MessageStatus.sent,
      createdAt: DateTime.now(),
    );

    state = current.copyWith(
      messages: [...current.messages, pending],
      clearSendError: true,
    );

    try {
      final confirmed = await _repo.sendMessage(_conversationId, content);
      _reconcile(tempId, confirmed);
      _convListNotifier.onMessageSent(_conversationId, confirmed);
    } catch (e) {
      _removePending(tempId, error: _friendlyError(e));
    }
  }

  // ─── Send photo (optimistic) ──────────────────────────────────────────────

  Future<void> sendPhoto(File file) async {
    final current = state;
    if (current is! ChatLoaded) return;

    final tempId = 'local_${DateTime.now().microsecondsSinceEpoch}';
    final pending = Message(
      id: tempId,
      conversationId: _conversationId,
      senderId: _currentUserId,
      status: MessageStatus.sent,
      createdAt: DateTime.now(),
      localFilePath: file.path,
    );

    state = current.copyWith(
      messages: [...current.messages, pending],
      clearSendError: true,
    );

    try {
      final confirmed = await _repo.sendPhotoMessage(_conversationId, file);
      _reconcile(tempId, confirmed);
      _convListNotifier.onMessageSent(_conversationId, confirmed);
    } catch (e) {
      _removePending(tempId, error: _friendlyError(e));
    }
  }

  void dismissSendError() {
    final current = state;
    if (current is! ChatLoaded) return;
    state = current.copyWith(clearSendError: true);
  }

  // ─── Optimistic reconciliation helpers ───────────────────────────────────

  void _reconcile(String tempId, Message confirmed) {
    final current = state;
    if (current is! ChatLoaded) return;
    final idx = current.messages.indexWhere((m) => m.id == tempId);
    if (idx == -1) return;
    final updated = List<Message>.from(current.messages);
    updated[idx] = confirmed;
    state = current.copyWith(messages: updated);
  }

  void _removePending(String tempId, {required String error}) {
    final current = state;
    if (current is! ChatLoaded) return;
    state = current.copyWith(
      messages: current.messages.where((m) => m.id != tempId).toList(),
      sendError: error,
    );
  }

  // ─── Socket handlers ──────────────────────────────────────────────────────

  void _onMessageNew(MessageNewEvent event) {
    if (event.conversationId != _conversationId) return;
    final current = state;
    if (current is! ChatLoaded) return;

    // Guard against duplicate delivery (WS reconnect edge case)
    if (current.messages.any((m) => m.id == event.messageId)) return;

    final incoming = Message(
      id: event.messageId,
      conversationId: event.conversationId,
      senderId: event.senderId,
      content: event.content,
      photoUrl: event.photoUrl,
      status: MessageStatus.fromJson(event.status),
      createdAt: event.createdAt,
    );

    state = current.copyWith(messages: [...current.messages, incoming]);

    // Screen is open = user is reading — mark as read immediately
    _markReadFireAndForget(event.messageId);
  }

  // Received when the OTHER participant reads our sent messages.
  // Updates status of our outgoing messages to READ up to and including
  // the readUpToMessageId (matched by createdAt boundary, same as the backend).
  void _onMessageRead(MessageReadEvent event) {
    if (event.conversationId != _conversationId) return;
    final current = state;
    if (current is! ChatLoaded) return;

    final boundary = current.messages
        .where((m) => m.id == event.readUpToMessageId)
        .map((m) => m.createdAt)
        .firstOrNull;
    if (boundary == null) return;

    final updated = current.messages.map((m) {
      if (m.senderId == _currentUserId &&
          !m.isPending &&
          m.status != MessageStatus.read &&
          !m.createdAt.isAfter(boundary)) {
        return m.copyWith(status: MessageStatus.read);
      }
      return m;
    }).toList();

    state = current.copyWith(messages: updated);
  }

  // ─── markRead ─────────────────────────────────────────────────────────────

  // Called on open when the last message is from the other party and unread.
  void _maybeMarkReadOnOpen(List<Message> messages) {
    if (messages.isEmpty) return;
    final last = messages.last;
    if (last.senderId != _currentUserId && last.status != MessageStatus.read) {
      _markReadFireAndForget(last.id);
    }
  }

  void _markReadFireAndForget(String messageId) {
    _repo.markRead(_conversationId, messageId).then((_) {}, onError: (e) {
      debugPrint('[Chat] markRead failed (fire-and-forget): $e');
    });
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('403')) return 'You can\'t send messages here.';
    if (msg.contains('404')) return 'Conversation not found.';
    if (msg.contains('413')) return 'Photo is too large (max 5 MB).';
    if (msg.contains('415')) return 'Only JPEG, PNG, and WebP photos are supported.';
    if (msg.contains('NetworkException') || msg.contains('SocketException')) {
      return 'No connection. Check your network.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

// family provider — one ChatNotifier instance per conversationId
final chatNotifierProvider =
    StateNotifierProvider.family<ChatNotifier, ChatState, String>(
  (ref, conversationId) => ChatNotifier(
    conversationId,
    ref.read(messagesRepositoryProvider),
    ref.read(messagesSocketServiceProvider),
    ref.read(conversationListNotifierProvider.notifier),
  ),
);
