import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/match_socket_service.dart';
import '../data/match_repository.dart';

// ─── State ────────────────────────────────────────────────────────────────────

sealed class TextMatchState {
  const TextMatchState();
}

final class TextMatchIdle extends TextMatchState {
  const TextMatchIdle();
}

final class TextMatchSearching extends TextMatchState {
  const TextMatchSearching();
}

final class TextMatchSessionActive extends TextMatchState {
  const TextMatchSessionActive({
    required this.sessionId,
    required this.expiresAt,
    this.iLiked = false,
    this.partnerLiked = false,
  });
  final String sessionId;
  final DateTime expiresAt;
  final bool iLiked;
  final bool partnerLiked;

  TextMatchSessionActive copyWith({bool? iLiked, bool? partnerLiked}) =>
      TextMatchSessionActive(
        sessionId: sessionId,
        expiresAt: expiresAt,
        iLiked: iLiked ?? this.iLiked,
        partnerLiked: partnerLiked ?? this.partnerLiked,
      );
}

final class TextMatchMutualLike extends TextMatchState {
  const TextMatchMutualLike({
    required this.conversationId,
    this.partnerUsername,
    this.partnerAvatarUrl,
  });
  final String conversationId;
  final String? partnerUsername;
  final String? partnerAvatarUrl;
}

final class TextMatchExpired extends TextMatchState {
  const TextMatchExpired({required this.sessionId});
  final String sessionId;
}

final class TextMatchEnded extends TextMatchState {
  const TextMatchEnded({required this.sessionId});
  final String sessionId;
}

final class TextMatchError extends TextMatchState {
  const TextMatchError({required this.message});
  final String message;
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class TextMatchNotifier extends StateNotifier<TextMatchState> {
  TextMatchNotifier(this._repo, this._socket) : super(const TextMatchIdle()) {
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
    if (state is! TextMatchIdle) return;
    state = const TextMatchSearching();
    try {
      await _repo.enqueueText();
    } on Exception catch (e) {
      state = TextMatchError(message: _friendlyError(e));
    }
  }

  Future<void> cancelSearch() async {
    if (state is! TextMatchSearching) return;
    try {
      await _repo.cancelTextQueue();
    } finally {
      state = const TextMatchIdle();
    }
  }

  Future<void> like(String sessionId) async {
    final current = state;
    if (current is! TextMatchSessionActive || current.iLiked) return;

    // Optimistically mark liked so the button updates immediately
    state = current.copyWith(iLiked: true);
    try {
      final res = await _repo.recordLike(sessionId);
      final mutualLike = res['mutualLike'] as bool? ?? false;
      if (mutualLike && state is! TextMatchMutualLike) {
        // HTTP beat the WS event — set state now; WS conversationCreated enriches it
        state = TextMatchMutualLike(
          conversationId: res['conversationId'] as String? ?? '',
        );
      }
    } on Exception catch (e) {
      // Roll back optimistic like and surface the error
      if (state is TextMatchSessionActive) {
        state = (state as TextMatchSessionActive).copyWith(iLiked: false);
      }
      state = TextMatchError(message: _friendlyError(e));
    }
  }

  Future<void> skipSession(String sessionId) async {
    if (state is! TextMatchSessionActive) return;
    try {
      await _repo.endSession(sessionId);
      // Backend also emits match.expired to both sides; set locally too for instant UX
      state = TextMatchEnded(sessionId: sessionId);
    } on Exception catch (e) {
      state = TextMatchError(message: _friendlyError(e));
    }
  }

  void reset() => state = const TextMatchIdle();

  // ─── Socket event handlers ────────────────────────────────────────────────

  void _onMatchFound(MatchFoundEvent event) {
    if (event.type != 'TEXT') return;
    if (state is TextMatchSearching) {
      state = TextMatchSessionActive(
        sessionId: event.sessionId,
        expiresAt: event.expiresAt,
      );
    }
  }

  void _onMatchExpired(MatchExpiredEvent event) {
    final current = state;
    if (current is TextMatchSessionActive && current.sessionId == event.sessionId) {
      state = TextMatchExpired(sessionId: event.sessionId);
    }
  }

  void _onMutualLike(MutualLikeEvent event) {
    // Accept from SessionActive or Expired so a late WS event still wins
    if (state is TextMatchSessionActive || state is TextMatchExpired) {
      state = TextMatchMutualLike(conversationId: event.conversationId);
    }
  }

  // Called by the client-side countdown when it hits zero.
  // Only transitions if we're still in SessionActive for this session;
  // no-op if MutualLike already landed or session already expired.
  void localExpire(String sessionId) {
    final current = state;
    if (current is TextMatchSessionActive && current.sessionId == sessionId) {
      state = TextMatchExpired(sessionId: sessionId);
    }
  }

  void _onPartnerLiked(PartnerLikedEvent event) {
    final current = state;
    if (current is TextMatchSessionActive && current.sessionId == event.sessionId) {
      state = current.copyWith(partnerLiked: true);
    }
  }

  void _onConversationCreated(ConversationCreatedEvent event) {
    final current = state;
    if (current is TextMatchMutualLike) {
      // Enrich with partner profile — anonymity lifted after mutual like
      state = TextMatchMutualLike(
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

final textMatchNotifierProvider =
    StateNotifierProvider<TextMatchNotifier, TextMatchState>((ref) {
  return TextMatchNotifier(
    ref.read(matchRepositoryProvider),
    ref.read(matchSocketServiceProvider),
  );
});
