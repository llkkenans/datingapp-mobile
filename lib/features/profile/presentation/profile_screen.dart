import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/profile.dart';
import '../providers/profile_notifier.dart';

const _primary = Color(0xFF6C63FF);

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

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(onRetry: () =>
            ref.read(profileNotifierProvider.notifier).load()),
        data: (profile) => _ProfileBody(profile: profile),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: const Color(0xFF0F0F0F),
          expandedHeight: 220,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: _AvatarHeader(profile: profile),
          ),
          actions: [
            TextButton(
              onPressed: () => context.push('/profile/edit'),
              child: const Text(
                'Edit',
                style: TextStyle(color: _primary, fontSize: 16),
              ),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                  _Section(
                    label: 'About',
                    child: Text(
                      profile.bio!,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 15, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                _Section(
                  label: 'Location',
                  child: Row(
                    children: [
                      const Icon(Icons.location_city_outlined,
                          size: 16, color: Colors.white38),
                      const SizedBox(width: 6),
                      Text(profile.city,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 15)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _Section(
                        label: 'I am',
                        child: Text(_genderLabel(profile.gender),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 15)),
                      ),
                    ),
                    Expanded(
                      child: _Section(
                        label: 'Interested in',
                        child: Text(_prefGenderLabel(profile.preferredGender),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
                if (profile.interests.isNotEmpty) ...[
                  const SizedBox(height: 20),
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
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/profile/edit'),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Profile'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      side: const BorderSide(color: _primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarHeader extends StatelessWidget {
  const _AvatarHeader({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F0F0F),
      alignment: Alignment.center,
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: const Color(0xFF2C2C2E),
            backgroundImage: profile.avatarUrl != null
                ? NetworkImage(profile.avatarUrl!)
                : null,
            child: profile.avatarUrl == null
                ? Text(
                    profile.username.isNotEmpty
                        ? profile.username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontSize: 32,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            '@${profile.username}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

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

class _InterestChip extends StatelessWidget {
  const _InterestChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primary.withValues(alpha: 0.4)),
      ),
      child: Text(name,
          style: const TextStyle(color: Colors.white70, fontSize: 13)),
    );
  }
}

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
