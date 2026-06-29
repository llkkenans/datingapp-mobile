import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/profile.dart';
import '../providers/profile_notifier.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────

const _bg = Color(0xFF0F0F0F);
const _surface = Color(0xFF2C2C2E);
const _border = Color(0xFF3A3A3C);
const _muted = Color(0xFF8A8A8E);
const _accent = Color(0xFFC0FF00);
const _accentBorder = Color(0x66C0FF00); // rgba(192,255,0,0.4)

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _genderLabel(String g) => switch (g) {
      'MALE' => 'Man',
      'FEMALE' => 'Woman',
      _ => 'Non-binary / Other',
    };

String _prefGenderLabel(String g) => switch (g) {
      'MALE' => 'Men',
      'FEMALE' => 'Women',
      'ANY' => 'Everyone',
      _ => 'Non-binary / Other',
    };

// ─── Screen ───────────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileNotifierProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
            onRetry: () => ref.read(profileNotifierProvider.notifier).load()),
        data: (profile) => _ProfileBody(profile: profile),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          sliver: SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _Header(profile: profile),
                const SizedBox(height: 28),
                if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                  _Section(
                    label: 'About',
                    child: Text(
                      profile.bio!,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 15, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                _Section(
                  label: 'Location',
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 15, color: _muted),
                      const SizedBox(width: 5),
                      Text(profile.city,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 15)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _Section(
                        label: 'I am',
                        child: Text(
                          _genderLabel(profile.gender),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 15),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _Section(
                        label: 'Interested in',
                        child: Text(
                          _prefGenderLabel(profile.preferredGender),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
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
                const SizedBox(height: 32),
                _ActionRow(profile: profile),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.username,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        CircleAvatar(
          radius: 32,
          backgroundColor: _surface,
          backgroundImage: profile.avatarUrl != null
              ? NetworkImage(profile.avatarUrl!)
              : null,
          child: profile.avatarUrl == null
              ? Text(
                  profile.username.isNotEmpty
                      ? profile.username[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      fontSize: 24,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600),
                )
              : null,
        ),
      ],
    );
  }
}

// ─── Action row ───────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.push('/profile/edit'),
            icon: const Icon(Icons.edit_outlined, size: 17),
            label: const Text('Edit profile'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: _border),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 48,
          height: 48,
          child: OutlinedButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings coming soon')),
            ),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: const BorderSide(color: _border),
              shape: const CircleBorder(),
            ),
            child: const Icon(Icons.settings_outlined,
                size: 20, color: _muted),
          ),
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white38,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentBorder),
      ),
      child: Text(name,
          style: const TextStyle(color: _accent, fontSize: 13)),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_outlined, color: Colors.white38, size: 40),
          const SizedBox(height: 12),
          const Text('Could not load profile.',
              style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
