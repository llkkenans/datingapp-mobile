import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Event payloads (mirror backend WS_EVENTS / payload shapes) ───────────────

class MatchFoundEvent {
  const MatchFoundEvent({
    required this.sessionId,
    required this.type,
    required this.expiresAt,
    this.roomId,
    this.zegoToken,
  });
  final String sessionId;
  final String type; // 'TEXT' | 'VOICE'
  final DateTime expiresAt;
  final String? roomId;    // only present for VOICE sessions
  final String? zegoToken; // only present for VOICE sessions

  factory MatchFoundEvent.fromJson(Map<String, dynamic> j) => MatchFoundEvent(
        sessionId: j['sessionId'] as String,
        type: j['type'] as String,
        expiresAt: DateTime.parse(j['expiresAt'] as String),
        roomId: j['roomId'] as String?,
        zegoToken: j['zegoToken'] as String?,
      );
}

class MatchExpiredEvent {
  const MatchExpiredEvent({required this.sessionId});
  final String sessionId;

  factory MatchExpiredEvent.fromJson(Map<String, dynamic> j) =>
      MatchExpiredEvent(sessionId: j['sessionId'] as String);
}

class MutualLikeEvent {
  const MutualLikeEvent({required this.sessionId, required this.conversationId});
  final String sessionId;
  final String conversationId;

  factory MutualLikeEvent.fromJson(Map<String, dynamic> j) => MutualLikeEvent(
        sessionId: j['sessionId'] as String,
        conversationId: j['conversationId'] as String,
      );
}

class PartnerLikedEvent {
  const PartnerLikedEvent({required this.sessionId});
  final String sessionId;

  factory PartnerLikedEvent.fromJson(Map<String, dynamic> j) =>
      PartnerLikedEvent(sessionId: j['sessionId'] as String);
}

class ConversationCreatedEvent {
  const ConversationCreatedEvent({
    required this.conversationId,
    required this.withUserId,
    required this.withUsername,
    this.withAvatarUrl,
  });
  final String conversationId;
  final String withUserId;
  final String withUsername;
  final String? withAvatarUrl;

  factory ConversationCreatedEvent.fromJson(Map<String, dynamic> j) =>
      ConversationCreatedEvent(
        conversationId: j['conversationId'] as String,
        withUserId: j['withUserId'] as String,
        withUsername: j['withUsername'] as String,
        withAvatarUrl: j['withAvatarUrl'] as String?,
      );
}

class ChatMessageEvent {
  const ChatMessageEvent({
    required this.sessionId,
    required this.content,
    required this.sentAt,
  });
  final String sessionId;
  final String content;
  final DateTime sentAt;

  factory ChatMessageEvent.fromJson(Map<String, dynamic> j) => ChatMessageEvent(
        sessionId: j['sessionId'] as String,
        content: j['content'] as String,
        sentAt: DateTime.parse(j['sentAt'] as String),
      );
}

class ChatMessageErrorEvent {
  const ChatMessageErrorEvent({required this.message});
  final String message;

  factory ChatMessageErrorEvent.fromJson(Map<String, dynamic> j) =>
      ChatMessageErrorEvent(
        message: j['message'] as String? ?? 'Message could not be sent',
      );
}

// ─── Service ──────────────────────────────────────────────────────────────────

class MatchSocketService {
  late io.Socket _socket;
  bool _initialized = false;

  final _matchFoundCtrl = StreamController<MatchFoundEvent>.broadcast();
  final _matchExpiredCtrl = StreamController<MatchExpiredEvent>.broadcast();
  final _mutualLikeCtrl = StreamController<MutualLikeEvent>.broadcast();
  final _partnerLikedCtrl = StreamController<PartnerLikedEvent>.broadcast();
  final _conversationCreatedCtrl =
      StreamController<ConversationCreatedEvent>.broadcast();
  final _sessionMessageCtrl = StreamController<ChatMessageEvent>.broadcast();
  final _sessionMessageErrorCtrl =
      StreamController<ChatMessageErrorEvent>.broadcast();

  Stream<MatchFoundEvent> get onMatchFound => _matchFoundCtrl.stream;
  Stream<MatchExpiredEvent> get onMatchExpired => _matchExpiredCtrl.stream;
  Stream<MutualLikeEvent> get onMutualLike => _mutualLikeCtrl.stream;
  Stream<PartnerLikedEvent> get onPartnerLiked => _partnerLikedCtrl.stream;
  Stream<ConversationCreatedEvent> get onConversationCreated =>
      _conversationCreatedCtrl.stream;
  Stream<ChatMessageEvent> get onSessionMessage => _sessionMessageCtrl.stream;
  Stream<ChatMessageErrorEvent> get onSessionMessageError =>
      _sessionMessageErrorCtrl.stream;

  void connect() {
    if (_initialized) return;
    final session = Supabase.instance.client.auth.currentSession;
    final userId = session?.user.id;
    if (userId == null) {
      debugPrint('[MatchSocket] No active session — skipping connect');
      return;
    }

    final baseUrl = dotenv.env['BACKEND_BASE_URL'] ?? 'http://localhost:3000';

    // Backend auth stub: MatchGateway.handleConnection trusts handshake.auth.userId
    // directly (no JWT verification yet — see match.gateway.ts comment).
    // We send both userId and JWT so the backend can add verification later.
    // Namespace is appended to the URL — socket_io_client does not use OptionBuilder.setNamespace.
    _socket = io.io(
      '$baseUrl/match',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'userId': userId, 'token': session?.accessToken})
          .disableAutoConnect()
          .build(),
    );

    _socket
      ..on('connect', (_) => debugPrint('[MatchSocket] Connected'))
      ..on('disconnect', (_) => debugPrint('[MatchSocket] Disconnected'))
      ..on('connect_error', (e) => debugPrint('[MatchSocket] Error: $e'))
      ..on('match.found', (d) => _emit(_matchFoundCtrl, d, MatchFoundEvent.fromJson))
      ..on('match.expired', (d) => _emit(_matchExpiredCtrl, d, MatchExpiredEvent.fromJson))
      ..on('match.mutual_like', (d) => _emit(_mutualLikeCtrl, d, MutualLikeEvent.fromJson))
      ..on('match.partner_liked', (d) => _emit(_partnerLikedCtrl, d, PartnerLikedEvent.fromJson))
      ..on('conversation.created',
          (d) => _emit(_conversationCreatedCtrl, d, ConversationCreatedEvent.fromJson))
      ..on('session.message',
          (d) => _emit(_sessionMessageCtrl, d, ChatMessageEvent.fromJson))
      ..on('session.message.error',
          (d) => _emit(_sessionMessageErrorCtrl, d, ChatMessageErrorEvent.fromJson))
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
      debugPrint('[MatchSocket] Parse error for ${ctrl.runtimeType}: $e');
    }
  }

  void sendSessionMessage(String sessionId, String content) {
    if (!_initialized) return;
    _socket.emit('session.message', {'sessionId': sessionId, 'content': content});
  }

  void dispose() {
    if (_initialized) {
      _socket
        ..disconnect()
        ..dispose();
    }
    _matchFoundCtrl.close();
    _matchExpiredCtrl.close();
    _mutualLikeCtrl.close();
    _partnerLikedCtrl.close();
    _conversationCreatedCtrl.close();
    _sessionMessageCtrl.close();
    _sessionMessageErrorCtrl.close();
  }
}

final matchSocketServiceProvider = Provider<MatchSocketService>((ref) {
  final service = MatchSocketService();
  service.connect();
  ref.onDispose(service.dispose);
  return service;
});
