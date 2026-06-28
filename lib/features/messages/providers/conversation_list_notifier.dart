import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/messages_socket_service.dart';
import '../data/messages_models.dart';
import '../data/messages_repository.dart';

// ─── State ────────────────────────────────────────────────────────────────────

sealed class ConversationListState {
  const ConversationListState();
}

final class ConversationListLoading extends ConversationListState {
  const ConversationListLoading();
}

final class ConversationListLoaded extends ConversationListState {
  const ConversationListLoaded(this.conversations);
  final List<Conversation> conversations;
}

final class ConversationListError extends ConversationListState {
  const ConversationListError(this.message);
  final String message;
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ConversationListNotifier
    extends StateNotifier<ConversationListState> {
  ConversationListNotifier(this._repo, this._socket)
      : super(const ConversationListLoading()) {
    _listenToSocket();
    _load();
  }

  final MessagesRepository _repo;
  final MessagesSocketService _socket;
  final List<StreamSubscription<dynamic>> _subs = [];

  void _listenToSocket() {
    _subs.add(_socket.onMessageNew.listen(_onMessageNew));
  }

  // ─── Init ────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final conversations = await _repo.getConversations();
      state = ConversationListLoaded(conversations);
    } catch (e) {
      state = ConversationListError(_friendlyError(e));
    }
  }

  Future<void> refresh() => _load();

  // ─── Called by ChatNotifier after a successful send ───────────────────────
  // The backend only emits message.new to the recipient, not the sender, so
  // the sender's conversation list won't update via WS for their own messages.

  void onMessageSent(String conversationId, Message message) {
    _updateLastMessage(
      conversationId,
      LastMessage(
        id: message.id,
        content: message.content,
        photoUrl: message.photoUrl,
        senderId: message.senderId,
        status: message.status,
        createdAt: message.createdAt,
      ),
      message.createdAt,
    );
  }

  // ─── Socket handlers ──────────────────────────────────────────────────────

  void _onMessageNew(MessageNewEvent event) {
    final current = state;
    if (current is! ConversationListLoaded) return;

    final exists = current.conversations.any((c) => c.id == event.conversationId);
    if (!exists) {
      // New conversation appeared while the list is open — full refresh to get
      // otherUser details which the WS payload does not include.
      debugPrint('[ConvList] Unknown conversation ${event.conversationId} — refreshing');
      _load();
      return;
    }

    _updateLastMessage(
      event.conversationId,
      LastMessage(
        id: event.messageId,
        content: event.content,
        photoUrl: event.photoUrl,
        senderId: event.senderId,
        status: MessageStatus.fromJson(event.status),
        createdAt: event.createdAt,
      ),
      event.createdAt,
    );
  }

  void _updateLastMessage(
    String conversationId,
    LastMessage lastMessage,
    DateTime lastMessageAt,
  ) {
    final current = state;
    if (current is! ConversationListLoaded) return;

    final updated = current.conversations.map((c) {
      if (c.id != conversationId) return c;
      return c.copyWith(lastMessage: lastMessage, lastMessageAt: lastMessageAt);
    }).toList()
      ..sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime); // most recent first
      });

    state = ConversationListLoaded(updated);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('401') || msg.contains('403')) return 'Session expired. Please log in again.';
    if (msg.contains('NetworkException') || msg.contains('SocketException')) {
      return 'No connection. Pull to refresh.';
    }
    return 'Could not load conversations.';
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

final conversationListNotifierProvider =
    StateNotifierProvider<ConversationListNotifier, ConversationListState>((ref) {
  return ConversationListNotifier(
    ref.read(messagesRepositoryProvider),
    ref.read(messagesSocketServiceProvider),
  );
});
