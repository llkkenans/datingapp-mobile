import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../features/onboarding/models/interest.dart';
import '../../../features/onboarding/providers/onboarding_providers.dart';
import '../providers/profile_notifier.dart';

const _primary = Color(0xFF6C63FF);
const _maxBio = 500;
const _maxInterests = 10;

const _genderOptions = [
  ('MALE', 'Man', '👨'),
  ('FEMALE', 'Woman', '👩'),
  ('OTHER', 'Non-binary / Other', '🧑'),
];

const _prefGenderOptions = [
  ('MALE', 'Men', '👨'),
  ('FEMALE', 'Women', '👩'),
  ('OTHER', 'Non-binary / Other people', '🧑'),
  ('ANY', 'Everyone', '🌈'),
];

// ─── Username check status (local widget state) ───────────────────────────────

enum _UsernameStatus { idle, checking, available, taken, invalid }

final _usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');

// ─── Screen ───────────────────────────────────────────────────────────────────

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _cityCtrl;
  late final String _originalUsername;

  _UsernameStatus _usernameStatus = _UsernameStatus.available;
  String? _usernameError;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(editProfileNotifierProvider);
    _originalUsername = draft.username;
    _usernameCtrl = TextEditingController(text: draft.username);
    _bioCtrl = TextEditingController(text: draft.bio);
    _cityCtrl = TextEditingController(text: draft.city);
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    _cityCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ─── Username validation ──────────────────────────────────────────────────

  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    ref.read(editProfileNotifierProvider.notifier).updateUsername(trimmed);

    if (trimmed == _originalUsername) {
      setState(() {
        _usernameStatus = _UsernameStatus.available;
        _usernameError = null;
      });
      return;
    }

    if (trimmed.isEmpty) {
      setState(() {
        _usernameStatus = _UsernameStatus.idle;
        _usernameError = null;
      });
      return;
    }

    if (trimmed.length < 3 || trimmed.length > 20) {
      setState(() {
        _usernameStatus = _UsernameStatus.invalid;
        _usernameError = 'Must be 3–20 characters.';
      });
      return;
    }

    if (!_usernameRegex.hasMatch(trimmed)) {
      setState(() {
        _usernameStatus = _UsernameStatus.invalid;
        _usernameError = 'Only letters, numbers and underscores allowed.';
      });
      return;
    }

    setState(() {
      _usernameStatus = _UsernameStatus.checking;
      _usernameError = null;
    });
    _debounce =
        Timer(const Duration(milliseconds: 500), () => _checkUsername(trimmed));
  }

  Future<void> _checkUsername(String username) async {
    if (!mounted) return;
    setState(() => _usernameStatus = _UsernameStatus.checking);
    try {
      final available =
          await ref.read(profileRepositoryProvider).checkUsernameAvailable(username);
      if (!mounted) return;
      setState(() {
        _usernameStatus =
            available ? _UsernameStatus.available : _UsernameStatus.taken;
        _usernameError =
            available ? null : 'This username is already taken.';
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _usernameStatus = _UsernameStatus.idle;
        _usernameError =
            'Could not check username (${e.response?.statusCode ?? e.type.name}).';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _usernameStatus = _UsernameStatus.idle;
        _usernameError = 'Something went wrong. Please try again.';
      });
    }
  }

  Widget? get _usernameSuffix => switch (_usernameStatus) {
        _UsernameStatus.checking => const SizedBox(
            width: 16,
            height: 16,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        _UsernameStatus.available => const Icon(Icons.check_circle_outline,
            color: Color(0xFF4CAF50)),
        _UsernameStatus.taken ||
        _UsernameStatus.invalid =>
          const Icon(Icons.cancel_outlined, color: Color(0xFFEF5350)),
        _UsernameStatus.idle => null,
      };

  bool get _usernameValid =>
      _usernameStatus == _UsernameStatus.available;

  // ─── Save ─────────────────────────────────────────────────────────────────

  bool get _canSave {
    final draft = ref.read(editProfileNotifierProvider);
    return _usernameValid &&
        _cityCtrl.text.trim().length >= 2 &&
        !(_bioCtrl.text.length > _maxBio) &&
        draft.gender != null &&
        draft.preferredGender != null &&
        draft.interestIds.isNotEmpty;
  }

  Future<void> _save() async {
    ref.read(editProfileNotifierProvider.notifier)
      ..updateBio(_bioCtrl.text.trim())
      ..updateCity(_cityCtrl.text.trim());
    await ref
        .read(editProfileNotifierProvider.notifier)
        .save(_originalUsername);
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(editProfileNotifierProvider);

    // Pop when save completes
    ref.listen(editProfileNotifierProvider, (_, next) {
      if (next.saved && context.canPop()) context.pop();
    });

    final submitting = draft.submitting;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Edit Profile',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (draft.error != null)
                  _ErrorBanner(message: draft.error!),

                // ── Username ─────────────────────────────────────────────
                _SectionLabel(label: 'Username'),
                TextField(
                  controller: _usernameCtrl,
                  onChanged: _onUsernameChanged,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'e.g. alex_johnson',
                    hintStyle: const TextStyle(color: Colors.white30),
                    prefixText: '@',
                    prefixStyle:
                        const TextStyle(color: _primary, fontSize: 16),
                    suffixIcon: _usernameSuffix,
                    errorText: _usernameError,
                    errorStyle:
                        const TextStyle(color: Color(0xFFEF5350)),
                    filled: true,
                    fillColor: const Color(0xFF1C1C1E),
                    border: _inputBorder(),
                    focusedBorder: _focusedBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                if (_usernameStatus == _UsernameStatus.available &&
                    _usernameCtrl.text.trim() != _originalUsername)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 14, color: Color(0xFF4CAF50)),
                        const SizedBox(width: 4),
                        Text(
                          '@${_usernameCtrl.text.trim()} is available!',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF4CAF50)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // ── Bio ──────────────────────────────────────────────────
                _SectionLabel(label: 'Bio'),
                TextField(
                  controller: _bioCtrl,
                  maxLines: 4,
                  maxLength: _maxBio,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, height: 1.5),
                  decoration: InputDecoration(
                    hintText: 'Tell others a bit about yourself…',
                    hintStyle: const TextStyle(
                        color: Colors.white30, fontSize: 15, height: 1.5),
                    filled: true,
                    fillColor: const Color(0xFF1C1C1E),
                    border: _inputBorder(),
                    focusedBorder: _focusedBorder(),
                    counterStyle: TextStyle(
                      color: _bioCtrl.text.length > _maxBio
                          ? const Color(0xFFEF5350)
                          : Colors.white38,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 24),

                // ── City ─────────────────────────────────────────────────
                _SectionLabel(label: 'City'),
                TextField(
                  controller: _cityCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'e.g. Istanbul, New York, London',
                    hintStyle: const TextStyle(color: Colors.white30),
                    prefixIcon: const Icon(Icons.location_city_outlined,
                        color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF1C1C1E),
                    border: _inputBorder(),
                    focusedBorder: _focusedBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Gender ───────────────────────────────────────────────
                _SectionLabel(label: 'I identify as'),
                for (final (value, label, emoji) in _genderOptions) ...[
                  _SelectionCard(
                    label: label,
                    emoji: emoji,
                    selected: draft.gender == value,
                    onTap: () => ref
                        .read(editProfileNotifierProvider.notifier)
                        .updateGender(value),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 14),

                // ── Preferred gender ─────────────────────────────────────
                _SectionLabel(label: "I'm interested in"),
                for (final (value, label, emoji) in _prefGenderOptions) ...[
                  _SelectionCard(
                    label: label,
                    emoji: emoji,
                    selected: draft.preferredGender == value,
                    onTap: () => ref
                        .read(editProfileNotifierProvider.notifier)
                        .updatePreferredGender(value),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 14),

                // ── Interests ────────────────────────────────────────────
                _SectionLabel(label: 'Interests'),
                _InterestsPicker(
                  selectedIds: draft.interestIds,
                  onChanged: (ids) => ref
                      .read(editProfileNotifierProvider.notifier)
                      .updateInterestIds(ids),
                ),
              ],
            ),
          ),

          // ── Sticky Save button ────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: const Color(0xFF0F0F0F),
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
              child: FilledButton(
                onPressed: submitting || !_canSave ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  disabledBackgroundColor: _primary.withValues(alpha: 0.3),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Changes',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Interests picker ─────────────────────────────────────────────────────────

class _InterestsPicker extends ConsumerWidget {
  const _InterestsPicker({
    required this.selectedIds,
    required this.onChanged,
  });

  final List<String> selectedIds;
  final void Function(List<String>) onChanged;

  void _toggle(String id, List<Interest> all) {
    final current = List<String>.from(selectedIds);
    if (current.contains(id)) {
      current.remove(id);
    } else if (current.length < _maxInterests) {
      current.add(id);
    }
    onChanged(current);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interestsAsync = ref.watch(interestsProvider);
    return interestsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Column(
        children: [
          const Text('Could not load interests.',
              style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => ref.invalidate(interestsProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
      data: (interests) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${selectedIds.length}/$_maxInterests selected',
              style: const TextStyle(fontSize: 13, color: Colors.white38),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: interests.map((interest) {
                final selected = selectedIds.contains(interest.id);
                final atMax =
                    selectedIds.length >= _maxInterests && !selected;
                return FilterChip(
                  label: Text(interest.name),
                  selected: selected,
                  onSelected: atMax ? null : (_) => _toggle(interest.id, interests),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  backgroundColor: const Color(0xFF1C1C1E),
                  selectedColor: _primary.withValues(alpha: 0.25),
                  checkmarkColor: _primary,
                  side: BorderSide(
                    color: selected ? _primary : Colors.white12,
                    width: selected ? 1.5 : 1,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white38,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? _primary.withValues(alpha: 0.12)
              : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _primary : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? Colors.white : Colors.white70,
              ),
            ),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_circle,
                  color: _primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF5350).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFFEF5350).withValues(alpha: 0.3)),
      ),
      child: Text(message,
          style: const TextStyle(color: Color(0xFFEF5350), fontSize: 14)),
    );
  }
}

OutlineInputBorder _inputBorder() => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );

OutlineInputBorder _focusedBorder() => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _primary, width: 1.5),
    );
