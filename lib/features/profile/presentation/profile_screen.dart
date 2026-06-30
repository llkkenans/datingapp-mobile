import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../discover/presentation/widgets/post_card.dart';
import '../../discover/providers/feed_notifier.dart';
import '../../discover/providers/profile_posts_notifier.dart';
import '../models/profile.dart';
import '../providers/profile_notifier.dart';

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

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    // Surface like-errors from profile posts as a SnackBar, then clear them.
    ref.listen<FeedState>(
      profilePostsNotifierProvider(profile.id),
      (_, next) {
        if (next is FeedLoaded && next.likeError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.likeError!),
              backgroundColor: cs.surfaceContainerHighest,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
          ref
              .read(profilePostsNotifierProvider(profile.id).notifier)
              .clearLikeError();
        }
      },
    );

    final postsState = ref.watch(profilePostsNotifierProvider(profile.id));

    // Resolve the posts sliver before building the widget tree.
    final Widget postsSliver = switch (postsState) {
      FeedLoading() => SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(
                  color: cs.primary, strokeWidth: 2),
            ),
          ),
        ),
      FeedError() => SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Text(
              'Could not load posts.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            ),
          ),
        ),
      FeedLoaded(:final posts) when posts.isEmpty => SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Text(
              'No posts yet.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            ),
          ),
        ),
      FeedLoaded(:final posts) => SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => PostCard(
              post: posts[i],
              onLikeTap: () => ref
                  .read(profilePostsNotifierProvider(profile.id).notifier)
                  .toggleLike(posts[i].id),
            ),
            childCount: posts.length,
          ),
        ),
    };

    return CustomScrollView(
      slivers: [
        // Profile info — padded 20px each side
        SliverSafeArea(
          bottom: false,
          sliver: SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _Header(profile: profile),
                const SizedBox(height: 28),
                if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                  _Section(
                    label: 'About',
                    child: Text(
                      profile.bio!,
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 15,
                          height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                _Section(
                  label: 'Location',
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 15, color: cs.onSurfaceVariant),
                      const SizedBox(width: 5),
                      Text(profile.city,
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 15)),
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
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 15),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _Section(
                        label: 'Interested in',
                        child: Text(
                          _prefGenderLabel(profile.preferredGender),
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 15),
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
                const SizedBox(height: 28),
                // Section label only — post cards follow in the next sliver.
                _Section(
                  label: 'Posts',
                  child: const SizedBox.shrink(),
                ),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ),

        // Post cards — edge-to-edge so PostCard's own 16px padding isn't doubled.
        postsSliver,

        // Bottom safe-area padding.
        const SliverSafeArea(
          top: false,
          sliver: SliverPadding(padding: EdgeInsets.only(bottom: 32)),
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
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            profile.username,
            style: GoogleFonts.playfairDisplay(
              fontSize: 38,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(width: 16),
        CircleAvatar(
          radius: 32,
          backgroundColor: cs.surfaceContainerHighest,
          backgroundImage: profile.avatarUrl != null
              ? NetworkImage(profile.avatarUrl!)
              : null,
          child: profile.avatarUrl == null
              ? Text(
                  profile.username.isNotEmpty
                      ? profile.username[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      fontSize: 24,
                      color: cs.onSurfaceVariant,
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
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.push('/profile/edit'),
            icon: const Icon(Icons.edit_outlined, size: 17),
            label: const Text('Edit profile'),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.onSurface,
              side: BorderSide(color: cs.outline),
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
            onPressed: () => context.push('/profile/settings'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: BorderSide(color: cs.outline),
              shape: const CircleBorder(),
            ),
            child: Icon(Icons.settings_outlined,
                size: 20, color: cs.onSurfaceVariant),
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

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_outlined,
              color: cs.onSurfaceVariant, size: 40),
          const SizedBox(height: 12),
          Text('Could not load profile.',
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
