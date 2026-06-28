import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import '../../providers/voice_match_notifier.dart';

class VoiceCallScreen extends ConsumerStatefulWidget {
  const VoiceCallScreen({
    super.key,
    required this.sessionId,
    required this.roomId,
    required this.zegoToken,
    required this.expiresAt,
  });
  final String sessionId;
  final String roomId;
  final String zegoToken;
  final DateTime expiresAt;

  @override
  ConsumerState<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends ConsumerState<VoiceCallScreen>
    with SingleTickerProviderStateMixin {
  Timer? _clockTimer;
  Duration _remaining = Duration.zero;

  bool _muted = false;
  bool _speakerOn = false;
  bool _zegoReady = false;
  bool _zegoDestroyed = false;
  final List<String> _remoteStreamIds = [];

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _updateRemaining(widget.expiresAt);
    _startCountdown();
    _initZego();
  }

  void _updateRemaining(DateTime expiresAt) {
    final diff = expiresAt.toUtc().difference(DateTime.now().toUtc());
    _remaining = diff.isNegative ? Duration.zero : diff;
  }

  void _startCountdown() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final s = ref.read(voiceMatchNotifierProvider);
      if (s is VoiceMatchSessionActive) {
        setState(() => _updateRemaining(s.expiresAt));
        if (_remaining == Duration.zero) {
          ref
              .read(voiceMatchNotifierProvider.notifier)
              .localExpire(s.sessionId);
        }
      }
    });
  }

  Future<void> _initZego() async {
    try {
      final appIdStr = dotenv.env['ZEGO_APP_ID'] ?? '0';
      final appId = int.tryParse(appIdStr) ?? 0;
      debugPrint('[Zego] ZEGO_APP_ID raw="${dotenv.env['ZEGO_APP_ID']}" parsed=$appId');
      if (appId == 0) {
        debugPrint('[Zego] App ID is 0 — skipping engine init');
        return;
      }

      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      debugPrint('[Zego] userId=$userId roomId=${widget.roomId}');
      debugPrint('[Zego] zegoToken (first 20 chars): ${widget.zegoToken.length > 20 ? widget.zegoToken.substring(0, 20) : widget.zegoToken}...');

      debugPrint('[Zego] Calling createEngineWithProfile...');
      await ZegoExpressEngine.createEngineWithProfile(
        ZegoEngineProfile(appId, ZegoScenario.Default),
      );
      debugPrint('[Zego] Engine created');

      ZegoExpressEngine.onRoomStreamUpdate =
          (roomID, updateType, streamList, _) {
        debugPrint('[Zego] onRoomStreamUpdate: type=$updateType streams=${streamList.map((s) => s.streamID).toList()}');
        if (!mounted) return;
        for (final stream in streamList) {
          if (updateType == ZegoUpdateType.Add) {
            ZegoExpressEngine.instance.startPlayingStream(stream.streamID);
            if (!_remoteStreamIds.contains(stream.streamID)) {
              _remoteStreamIds.add(stream.streamID);
            }
          } else {
            ZegoExpressEngine.instance.stopPlayingStream(stream.streamID);
            _remoteStreamIds.remove(stream.streamID);
          }
        }
      };

      // Listen for room state changes so we can detect login success/failure
      ZegoExpressEngine.onRoomStateChanged = (roomID, reason, errorCode, extendedData) {
        debugPrint('[Zego] onRoomStateChanged: room=$roomID reason=$reason errorCode=$errorCode');
      };

      final config = ZegoRoomConfig.defaultConfig()..token = widget.zegoToken;
      debugPrint('[Zego] Calling loginRoom...');
      final loginResult = await ZegoExpressEngine.instance.loginRoom(
        widget.roomId,
        ZegoUser(userId, userId),
        config: config,
      );
      debugPrint('[Zego] loginRoom result: $loginResult');

      final streamId = '${widget.roomId}_$userId';
      debugPrint('[Zego] Starting publishing stream: $streamId');
      await ZegoExpressEngine.instance.startPublishingStream(streamId);
      debugPrint('[Zego] Publishing started');

      // ── Mic capture verification ──────────────────────────────────────────
      // onCapturedSoundLevelUpdate fires ~every 100ms with values 0–100.
      // Silence = near-zero floats. No callbacks at all = mic not captured.
      // Consistent 0.0 on a real device = muted/permission denied.
      // On iOS Simulator the Mac host mic is used; values may be very low
      // even with a live mic (simulator ADC is 8-bit, dynamic range is poor).
      ZegoExpressEngine.onCapturedSoundLevelUpdate = (soundLevel) {
        debugPrint('[Zego] 🎙 capturedSoundLevel=$soundLevel');
      };
      ZegoExpressEngine.onRemoteSoundLevelUpdate = (soundLevels) {
        debugPrint('[Zego] 🔊 remoteSoundLevels=$soundLevels');
      };
      // Audio route tells us earpiece / speaker / bluetooth / headphone
      ZegoExpressEngine.onAudioRouteChange = (audioRoute) {
        debugPrint('[Zego] 🔈 audioRoute changed → $audioRoute');
      };
      // Publisher quality: stateChanged fires when publish state changes (e.g. no-send)
      ZegoExpressEngine.onPublisherStateUpdate = (streamID, state, errorCode, extendedData) {
        debugPrint('[Zego] 📡 publisherState: stream=$streamID state=$state errorCode=$errorCode');
      };
      // Start the sound level monitor — without this onCapturedSoundLevelUpdate never fires
      await ZegoExpressEngine.instance.startSoundLevelMonitor(
        config: ZegoSoundLevelConfig(500, false),
      );
      debugPrint('[Zego] Sound level monitor started — watch for 🎙 lines');
      // ─────────────────────────────────────────────────────────────────────

      if (mounted) setState(() => _zegoReady = true);
      debugPrint('[Zego] Init complete — zegoReady=true');
    } catch (e, st) {
      debugPrint('[Zego] _initZego ERROR: $e');
      debugPrint('[Zego] Stack trace: $st');
    }
  }

  Future<void> _teardownZego() async {
    if (_zegoDestroyed) return;
    _zegoDestroyed = true;

    try {
      await ZegoExpressEngine.instance.stopSoundLevelMonitor();
      await ZegoExpressEngine.instance.stopPublishingStream();
      for (final id in List<String>.from(_remoteStreamIds)) {
        await ZegoExpressEngine.instance.stopPlayingStream(id);
      }
      await ZegoExpressEngine.instance.logoutRoom(widget.roomId);
    } catch (_) {}

    try {
      await ZegoExpressEngine.destroyEngine();
    } catch (_) {}
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pulse.dispose();
    _teardownZego();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    try {
      await ZegoExpressEngine.instance.muteMicrophone(_muted);
    } catch (_) {}
  }

  Future<void> _toggleSpeaker() async {
    setState(() => _speakerOn = !_speakerOn);
    try {
      await ZegoExpressEngine.instance.setAudioRouteToSpeaker(_speakerOn);
    } catch (_) {}
  }

  Future<void> _endCall() async {
    await _teardownZego();
    if (mounted) {
      await ref
          .read(voiceMatchNotifierProvider.notifier)
          .endCall(widget.sessionId);
    }
  }

  Future<bool> _confirmEnd(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            title: const Text('End this call?'),
            content: const Text(
              "You'll both be taken to a rating screen.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'End Call',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voiceMatchNotifierProvider);
    final primary = Theme.of(context).colorScheme.primary;

    ref.listen<VoiceMatchState>(voiceMatchNotifierProvider, (_, next) {
      if (!mounted) return;
      if (next is VoiceMatchMutualLike) {
        _teardownZego();
        context.pushReplacement('/match/voice/success', extra: next);
      } else if (next is VoiceMatchExpired) {
        _teardownZego();
        context.pushReplacement('/match/voice/rating', extra: next.sessionId);
      } else if (next is VoiceMatchEnded) {
        _teardownZego();
        context.pushReplacement('/match/voice/rating', extra: next.sessionId);
      }
    });

    final partnerLiked =
        state is VoiceMatchSessionActive ? state.partnerLiked : false;
    final iLiked = state is VoiceMatchSessionActive ? state.iLiked : false;
    final isTimeLow = _remaining.inSeconds <= 30 && _remaining.inSeconds > 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final confirmed = await _confirmEnd(context);
        if (confirmed && mounted) await _endCall();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F0F0F),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              final confirmed = await _confirmEnd(context);
              if (confirmed && mounted) await _endCall();
            },
          ),
          title: Column(
            children: [
              const Text(
                'Anonymous Voice Call',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              if (partnerLiked)
                const Text(
                  'They liked you!',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6C63FF)),
                ),
            ],
          ),
          centerTitle: true,
          actions: [
            _TimerBadge(
              label: _formatDuration(_remaining),
              isLow: isTimeLow,
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _CallVisual(
                  pulse: _pulse,
                  isConnected: _zegoReady,
                  iLiked: iLiked,
                  primary: primary,
                ),
              ),
              _VoiceActionBar(
                muted: _muted,
                speakerOn: _speakerOn,
                iLiked: iLiked,
                onMute: _toggleMute,
                onSpeaker: _toggleSpeaker,
                onLike: iLiked
                    ? null
                    : () => ref
                        .read(voiceMatchNotifierProvider.notifier)
                        .like(widget.sessionId),
                onEndCall: () async {
                  final confirmed = await _confirmEnd(context);
                  if (confirmed && mounted) await _endCall();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Pulsing call visual ──────────────────────────────────────────────────────

class _CallVisual extends StatelessWidget {
  const _CallVisual({
    required this.pulse,
    required this.isConnected,
    required this.iLiked,
    required this.primary,
  });
  final AnimationController pulse;
  final bool isConnected;
  final bool iLiked;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    const connectedColor = Color(0xFF34C759);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (context, child) {
              final v = pulse.value;
              return SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Opacity(
                        opacity: isConnected
                            ? (1 - ((v + i / 3) % 1)).clamp(0.0, 0.3)
                            : 0,
                        child: Container(
                          width: 80 + i * 40.0,
                          height: 80 + i * 40.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: connectedColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: isConnected
                            ? Color.fromRGBO(52, 199, 89, 0.2)
                            : Color.fromRGBO(108, 99, 255, 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mic_rounded,
                        color: isConnected ? connectedColor : primary,
                        size: 36,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            isConnected ? 'Connected anonymously' : 'Connecting...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isConnected ? Colors.white : Colors.white54,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Identity revealed only on mutual like',
            style: TextStyle(fontSize: 13, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}

// ─── Timer badge ──────────────────────────────────────────────────────────────

class _TimerBadge extends StatelessWidget {
  const _TimerBadge({required this.label, required this.isLow});
  final String label;
  final bool isLow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isLow
            ? Color.fromRGBO(255, 0, 0, 0.12)
            : Color.fromRGBO(255, 255, 255, 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLow
              ? Color.fromRGBO(255, 100, 100, 0.6)
              : Colors.white24,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isLow ? Colors.redAccent : Colors.white,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ─── Voice action bar ─────────────────────────────────────────────────────────

class _VoiceActionBar extends StatelessWidget {
  const _VoiceActionBar({
    required this.muted,
    required this.speakerOn,
    required this.iLiked,
    required this.onMute,
    required this.onSpeaker,
    required this.onLike,
    required this.onEndCall,
  });
  final bool muted;
  final bool speakerOn;
  final bool iLiked;
  final VoidCallback onMute;
  final VoidCallback onSpeaker;
  final VoidCallback? onLike;
  final VoidCallback onEndCall;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CircleControl(
                icon: muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label: muted ? 'Unmute' : 'Mute',
                active: muted,
                onTap: onMute,
              ),
              _CircleControl(
                icon: speakerOn
                    ? Icons.volume_up_rounded
                    : Icons.hearing_rounded,
                label: speakerOn ? 'Speaker' : 'Earpiece',
                active: speakerOn,
                onTap: onSpeaker,
              ),
              _CircleControl(
                icon: iLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_outline_rounded,
                label: iLiked ? 'Liked!' : 'Like',
                active: iLiked,
                activeColor: primary,
                onTap: onLike,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onEndCall,
              icon: const Icon(Icons.call_end_rounded, size: 20),
              label: const Text('End Call'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleControl extends StatelessWidget {
  const _CircleControl({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.activeColor,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = activeColor ?? Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: active
                    ? effectiveColor.withAlpha(46)
                    : Color.fromRGBO(255, 255, 255, 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: active ? effectiveColor : Colors.white54,
                size: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
