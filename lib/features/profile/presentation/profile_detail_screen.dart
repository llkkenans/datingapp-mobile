import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../messages/presentation/chat_detail_screen.dart';
import '../models/profile_detail.dart';
import '../providers/profile_detail_provider.dart';
import '../providers/profile_notifier.dart';

class ProfileDetailScreen extends ConsumerWidget {
  const ProfileDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(profileDetailProvider(userId));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(error: e),
        data: (profile) => _ProfileBody(profile: profile),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile});

  final ProfileDetail profile;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Avatar ──────────────────────────────────────────────────────────
          CircleAvatar(
            radius: 52,
            backgroundColor: cs.surfaceContainerHighest,
            backgroundImage: profile.avatarUrl != null
                ? NetworkImage(profile.avatarUrl!)
                : null,
            child: profile.avatarUrl == null
                ? Icon(Icons.person_outline,
                    size: 48, color: cs.onSurfaceVariant)
                : null,
          ),
          const SizedBox(height: 16),

          // ── Username ─────────────────────────────────────────────────────────
          Text(
            profile.username,
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),

          // ── Age · City ───────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${profile.age}',
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('·',
                    style:
                        TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
              ),
              Icon(Icons.location_on_outlined,
                  size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 3),
              Text(
                profile.city,
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
              ),
            ],
          ),

          // ── Bio ──────────────────────────────────────────────────────────────
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 24),
            _Section(
              label: 'About',
              child: Text(
                profile.bio!,
                style: TextStyle(
                    color: cs.onSurfaceVariant, fontSize: 15, height: 1.5),
              ),
            ),
          ],

          // ── Interests ────────────────────────────────────────────────────────
          if (profile.interests.isNotEmpty) ...[
            const SizedBox(height: 24),
            _Section(
              label: 'Interests',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: profile.interests
                    .map((i) => _InterestChip(name: i.name))
                    .toList(),
              ),
            ),
          ],

          const SizedBox(height: 36),

          // ── Action area ──────────────────────────────────────────────────────
          _ActionArea(profile: profile),
        ],
      ),
    );
  }
}

// ─── Action area ──────────────────────────────────────────────────────────────

class _ActionArea extends StatelessWidget {
  const _ActionArea({required this.profile});

  final ProfileDetail profile;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return switch (profile.messageRequestStatus) {
      null => SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => _showSendRequestSheet(context, profile),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
            child: const Text('Send Message Request'),
          ),
        ),
      MessageRequestStatus.pendingSent => SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              side: BorderSide(color: cs.outline),
            ),
            child: Text(
              'Request Sent',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
        ),
      MessageRequestStatus.pendingReceived => _StatusLabel(
          icon: Icons.mail_outline_rounded,
          text: 'They sent you a request',
          cs: cs,
        ),
      MessageRequestStatus.accepted => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: profile.conversationId != null
                    ? () => context.push(
                          '/messages/${profile.conversationId!}',
                          extra: ChatArgs(
                            username: profile.username,
                            avatarUrl: profile.avatarUrl,
                          ),
                        )
                    : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  side: BorderSide(color: cs.outline),
                ),
                child: Text(
                  'Open Conversation',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            ),
            if (profile.conversationId == null) ...[
              const SizedBox(height: 8),
              Text(
                'Conversation not available yet.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      MessageRequestStatus.declinedByMe ||
      MessageRequestStatus.declinedByThem =>
        _StatusLabel(
          icon: Icons.block_outlined,
          text: 'Request Declined',
          cs: cs,
        ),
    };
  }

  void _showSendRequestSheet(BuildContext context, ProfileDetail profile) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SendRequestSheet(profile: profile),
    );
  }
}

// ─── Send request bottom sheet ─────────────────────────────────────────────

class _SendRequestSheet extends ConsumerStatefulWidget {
  const _SendRequestSheet({required this.profile});

  final ProfileDetail profile;

  @override
  ConsumerState<_SendRequestSheet> createState() => _SendRequestSheetState();
}

class _SendRequestSheetState extends ConsumerState<_SendRequestSheet> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _errorMessage = null;
    });

    try {
      await ref.read(profileRepositoryProvider).sendMessageRequest(
            receiverId: widget.profile.userId,
            content: content,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ref.invalidate(profileDetailProvider(widget.profile.userId));
    } on DioException catch (e) {
      final data = e.response?.data;
      final String msg;
      if (data is Map && data['message'] is String) {
        msg = data['message'] as String;
      } else if (data is Map && data['message'] is List) {
        msg = (data['message'] as List).join(' ');
      } else {
        msg = 'Could not send request.';
      }
      if (mounted) setState(() { _sending = false; _errorMessage = msg; });
    } catch (_) {
      if (mounted) setState(() { _sending = false; _errorMessage = 'Could not send request.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Message ${widget.profile.username}',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: cs.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Send a message request to start a conversation.',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 4,
            minLines: 2,
            maxLength: 300,
            decoration: InputDecoration(
              hintText: 'Write something...',
              hintStyle: TextStyle(color: cs.onSurfaceVariant),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.outline),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 13, color: cs.error),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _sending ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send Request'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status label ──────────────────────────────────────────────────────────

class _StatusLabel extends StatelessWidget {
  const _StatusLabel(
      {required this.icon, required this.text, required this.cs});

  final IconData icon;
  final String text;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
      ],
    );
  }
}

// ─── Section ──────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

// ─── Interest chip ────────────────────────────────────────────────────────────

class _InterestChip extends StatelessWidget {
  const _InterestChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
      ),
      child: Text(name, style: TextStyle(color: cs.primary, fontSize: 13)),
    );
  }
}

// ─── Error body ───────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final msg = error.toString();
    final display = msg.contains('404')
        ? 'This profile no longer exists.'
        : msg.contains('403')
            ? 'You don\'t have permission to view this profile.'
            : 'Could not load profile.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined,
                size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(display,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
