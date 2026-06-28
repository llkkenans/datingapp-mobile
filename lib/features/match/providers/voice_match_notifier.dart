import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/match_socket_service.dart';
import '../data/match_repository.dart';

// ─── State ────────────────────────────────────────────────────────────────────

sealed class VoiceMatchState {
  const VoiceMatchState();
}

final class VoiceMatchIdle extends VoiceMatchState {
  const VoiceMatchIdle();
}

final class VoiceMatchSearching extends VoiceMatchState {
  const VoiceMatchSearching();
}

final class VoiceMatchSessionActive extends VoiceMatchState {
  const VoiceMatchSessionActive({
    required this.sessionId,
    required this.roomId,
    required this.zegoToken,
    required this.expiresAt,
    this.iLiked = false,
    this.partnerLiked = false,
  });
  final String sessionId;
  final String roomId;
  final String zegoToken;
  final DateTime expiresAt;
  final bool iLiked;
  final bool partnerLiked;

  VoiceMatchSessionActive copyWith({bool? iLiked, bool? partnerLiked}) =>
      VoiceMatchSessionActive(
        sessionId: sessionId,
        roomId: roomId,
        zegoToken: zegoToken,
        expiresAt: expiresAt,
        iLiked: iLiked ?? this.iLiked,
        partnerLiked: partnerLiked ?? this.partnerLiked,
      );
}

final class VoiceMatchMutualLike extends VoiceMatchState {
  const VoiceMatchMutualLike({
    required this.conversationId,
    this.partnerUsername,
    this.partnerAvatarUrl,
  });
  final String conversationId;
  final String? partnerUsername;
  final String? partnerAvatarUrl;
}

final class VoiceMatchExpired extends VoiceMatchState {
  const VoiceMatchExpired({required this.sessionId});
  final String sessionId;
}

final class VoiceMatchEnded extends VoiceMatchState {
  const VoiceMatchEnded({required this.sessionId});
  final String sessionId;
}

final class VoiceMatchError extends VoiceMatchState {
  const VoiceMatchError({required this.message});
  final String message;
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class VoiceMatchNotifier extends StateNotifier<VoiceMatchState> {
  VoiceMatchNotifier(this._repo, this._socket) : super(const VoiceMatchIdle()) {
    _listenToSocket();
  }

  final MatchRepository _repo;
  final MatchSocketService _socket;
  final List<StreamSubscription<dynamic>> _subs = [];

  void _listenToSocket() {
    _subs
      ..add(_socket.onMatchFound.listen(_onMatchFound))
      ..add(_socket.onMatchExpired.listen(_onMatchExpired))
      ..add(_socket.onMutualLike.listen(_onMutualLike))
      ..add(_socket.onPartnerLiked.listen(_onPartnerLiked))
      ..add(_socket.onConversationCreated.listen(_onConversationCreated));
  }

  // ─── Public actions ──────────────────────────────────────────────────────────

  Future<void> startSearch() async {
    debugPrint('[VoiceMatch] startSearch() called — current state: ${state.runtimeType}');
    if (state is! VoiceMatchIdle) {
      debugPrint('[VoiceMatch] startSearch() blocked — state is not Idle, aborting');
      return;
    }
    state = const VoiceMatchSearching();
    debugPrint('[VoiceMatch] State → Searching; calling enqueueVoice()...');
    try {
      await _repo.enqueueVoice();
      debugPrint('[VoiceMatch] enqueueVoice() completed — waiting for match.found WS event');
    } on Exception catch (e) {
      debugPrint('[VoiceMatch] enqueueVoice() threw: $e');
      state = VoiceMatchError(message: _friendlyError(e));
    }
  }

  Future<void> cancelSearch() async {
    if (state is! VoiceMatchSearching) return;
    try {
      await _repo.cancelVoiceQueue();
    } finally {
      state = const VoiceMatchIdle();
    }
  }

  Future<void> like(String sessionId) async {
    final current = state;
    if (current is! VoiceMatchSessionActive || current.iLiked) return;

    // Optimistically mark liked so the button updates immediately
    state = current.copyWith(iLiked: true);
    try {
      final res = await _repo.recordLike(sessionId);
      final mutualLike = res['mutualLike'] as bool? ?? false;
      if (mutualLike && state is! VoiceMatchMutualLike) {
        // HTTP beat the WS event — set state now; WS conversationCreated enriches it
        state = VoiceMatchMutualLike(
          conversationId: res['conversationId'] as String? ?? '',
        );
      }
    } on Exception catch (e) {
      if (state is VoiceMatchSessionActive) {
        state = (state as VoiceMatchSessionActive).copyWith(iLiked: false);
      }
      state = VoiceMatchError(message: _friendlyError(e));
    }
  }

  Future<void> endCall(String sessionId) async {
    if (state is! VoiceMatchSessionActive) return;
    try {
      await _repo.endSession(sessionId);
      // Backend also emits match.expired to both sides; set locally too for instant UX
      state = VoiceMatchEnded(sessionId: sessionId);
    } on Exception catch (e) {
      state = VoiceMatchError(message: _friendlyError(e));
    }
  }

  // Called by the client-side countdown when it hits zero.
  // Only transitions if we're still in SessionActive for this session;
  // no-op if MutualLike already landed or session already expired.
  void localExpire(String sessionId) {
    final current = state;
    if (current is VoiceMatchSessionActive && current.sessionId == sessionId) {
      state = VoiceMatchExpired(sessionId: sessionId);
    }
  }

  void reset() => state = const VoiceMatchIdle();

  // ─── Socket event handlers ────────────────────────────────────────────────

  void _onMatchFound(MatchFoundEvent event) {
    if (event.type != 'VOICE') return;
    if (state is! VoiceMatchSearching) return;
    final roomId = event.roomId;
    final zegoToken = event.zegoToken;
    if (roomId == null || zegoToken == null) {
      // Backend sent an incomplete VOICE payload — surface as error rather than silently hang
      state = const VoiceMatchError(
        message: 'Voice session is missing RTC credentials. Please try again.',
      );
      return;
    }
    state = VoiceMatchSessionActive(
      sessionId: event.sessionId,
      roomId: roomId,
      zegoToken: zegoToken,
      expiresAt: event.expiresAt,
    );
  }

  void _onMatchExpired(MatchExpiredEvent event) {
    final current = state;
    if (current is VoiceMatchSessionActive && current.sessionId == event.sessionId) {
      state = VoiceMatchExpired(sessionId: event.sessionId);
    }
  }

  void _onMutualLike(MutualLikeEvent event) {
    // Accept from SessionActive or Expired so a late WS event still wins
    if (state is VoiceMatchSessionActive || state is VoiceMatchExpired) {
      state = VoiceMatchMutualLike(conversationId: event.conversationId);
    }
  }

  void _onPartnerLiked(PartnerLikedEvent event) {
    final current = state;
    if (current is VoiceMatchSessionActive && current.sessionId == event.sessionId) {
      state = current.copyWith(partnerLiked: true);
    }
  }

  void _onConversationCreated(ConversationCreatedEvent event) {
    final current = state;
    if (current is VoiceMatchMutualLike) {
      // Enrich with partner profile — anonymity lifted after mutual like
      state = VoiceMatchMutualLike(
        conversationId: event.conversationId,
        partnerUsername: event.withUsername,
        partnerAvatarUrl: event.withAvatarUrl,
      );
    }
  }

  String _friendlyError(Exception e) {
    final msg = e.toString();
    if (msg.contains('409')) return 'You\'re already in a queue or session.';
    if (msg.contains('410')) return 'This session has already ended.';
    if (msg.contains('403')) return 'You\'re not part of this session.';
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

final voiceMatchNotifierProvider =
    StateNotifierProvider<VoiceMatchNotifier, VoiceMatchState>((ref) {
  return VoiceMatchNotifier(
    ref.read(matchRepositoryProvider),
    ref.read(matchSocketServiceProvider),
  );
});
