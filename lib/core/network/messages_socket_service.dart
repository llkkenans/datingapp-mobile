import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Event payloads (mirror messaging.gateway.ts payload shapes) ──────────────

class TypingEvent {
  const TypingEvent({
    required this.conversationId,
    required this.userId,
    required this.isTyping,
  });
  final String conversationId;
  final String userId;
  final bool isTyping;

  factory TypingEvent.fromJson(Map<String, dynamic> j) => TypingEvent(
        conversationId: j['conversationId'] as String,
        userId: j['userId'] as String,
        isTyping: j['isTyping'] as bool,
      );
}

class MessageNewEvent {
  const MessageNewEvent({
    required this.conversationId,
    required this.messageId,
    required this.senderId,
    this.content,
    this.photoUrl,
    required this.status,
    required this.createdAt,
  });

  final String conversationId;
  final String messageId;
  final String senderId;
  final String? content;
  final String? photoUrl;
  final String status;
  final DateTime createdAt;

  factory MessageNewEvent.fromJson(Map<String, dynamic> j) {
    final msg = j['message'] as Map<String, dynamic>;
    return MessageNewEvent(
      conversationId: j['conversationId'] as String,
      messageId: msg['id'] as String,
      senderId: msg['senderId'] as String,
      content: msg['content'] as String?,
      photoUrl: msg['photoUrl'] as String?,
      status: msg['status'] as String,
      createdAt: DateTime.parse(msg['createdAt'] as String),
    );
  }
}

class MessageReadEvent {
  const MessageReadEvent({
    required this.conversationId,
    required this.readUpToMessageId,
    required this.readAt,
  });

  final String conversationId;
  final String readUpToMessageId;
  final DateTime readAt;

  factory MessageReadEvent.fromJson(Map<String, dynamic> j) => MessageReadEvent(
        conversationId: j['conversationId'] as String,
        readUpToMessageId: j['readUpToMessageId'] as String,
        readAt: DateTime.parse(j['readAt'] as String),
      );
}

// ─── Service ──────────────────────────────────────────────────────────────────

class MessagesSocketService {
  late io.Socket _socket;
  bool _initialized = false;
  bool _hasConnected = false;

  final _messageNewCtrl = StreamController<MessageNewEvent>.broadcast();
  final _messageReadCtrl = StreamController<MessageReadEvent>.broadcast();
  final _typingCtrl = StreamController<TypingEvent>.broadcast();
  final _reconnectCtrl = StreamController<void>.broadcast();

  Stream<MessageNewEvent> get onMessageNew => _messageNewCtrl.stream;
  Stream<MessageReadEvent> get onMessageRead => _messageReadCtrl.stream;
  Stream<TypingEvent> get onTyping => _typingCtrl.stream;
  Stream<void> get onReconnect => _reconnectCtrl.stream;

  void connect() {
    if (_initialized) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      debugPrint('[MessagesSocket] No active session — skipping connect');
      return;
    }

    final baseUrl = dotenv.env['BACKEND_BASE_URL'] ?? 'http://localhost:3000';

    _socket = io.io(
      '$baseUrl/messages',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuthFn((cb) {
            final token =
                Supabase.instance.client.auth.currentSession?.accessToken ?? '';
            cb({'token': token});
          })
          .disableAutoConnect()
          .build(),
    );

    _socket
      ..on('connect', (_) {
            if (_hasConnected) {
              debugPrint('[MessagesSocket] Reconnected — triggering resync');
              _reconnectCtrl.add(null);
            } else {
              debugPrint('[MessagesSocket] Connected');
              _hasConnected = true;
            }
          })
      ..on('disconnect', (_) => debugPrint('[MessagesSocket] Disconnected'))
      ..on('connect_error', (e) => debugPrint('[MessagesSocket] Error: $e'))
      ..on('message.new', (d) => _emit(_messageNewCtrl, d, MessageNewEvent.fromJson))
      ..on('message.read', (d) => _emit(_messageReadCtrl, d, MessageReadEvent.fromJson))
      ..on('message.typing', (d) => _emit(_typingCtrl, d, TypingEvent.fromJson))
      ..connect();

    _initialized = true;
  }

  void _emit<T>(
    StreamController<T> ctrl,
    dynamic data,
    T Function(Map<String, dynamic>) parse,
  ) {
    try {
      if (data is Map) ctrl.add(parse(Map<String, dynamic>.from(data)));
    } catch (e) {
      debugPrint('[MessagesSocket] Parse error: $e');
    }
  }

  void sendTypingStart(String conversationId) {
    if (!_initialized) return;
    _socket.emit('message.typing.start', {'conversationId': conversationId});
  }

  void sendTypingStop(String conversationId) {
    if (!_initialized) return;
    _socket.emit('message.typing.stop', {'conversationId': conversationId});
  }

  void dispose() {
    if (_initialized) {
      _socket
        ..disconnect()
        ..dispose();
    }
    _messageNewCtrl.close();
    _messageReadCtrl.close();
    _typingCtrl.close();
    _reconnectCtrl.close();
  }
}

final messagesSocketServiceProvider = Provider<MessagesSocketService>((ref) {
  final service = MessagesSocketService();
  service.connect();
  ref.onDispose(service.dispose);
  return service;
});
