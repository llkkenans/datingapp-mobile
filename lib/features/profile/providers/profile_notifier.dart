import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../data/profile_repository.dart';
import '../models/profile.dart';

// ─── Repository provider ──────────────────────────────────────────────────────

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(dioClientProvider).dio);
});

// ─── Profile loader ───────────────────────────────────────────────────────────

class ProfileNotifier extends StateNotifier<AsyncValue<Profile>> {
  ProfileNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  final ProfileRepository _repo;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final profile = await _repo.getMyProfile();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void update(Profile profile) => state = AsyncValue.data(profile);
}

final profileNotifierProvider =
    StateNotifierProvider<ProfileNotifier, AsyncValue<Profile>>((ref) {
  return ProfileNotifier(ref.read(profileRepositoryProvider));
});

// ─── Edit profile state ───────────────────────────────────────────────────────

class EditProfileState {
  const EditProfileState({
    required this.username,
    required this.bio,
    required this.city,
    required this.gender,
    required this.preferredGender,
    required this.interestIds,
    this.submitting = false,
    this.error,
    this.saved = false,
  });

  final String username;
  final String bio;
  final String city;
  final String? gender;
  final String? preferredGender;
  final List<String> interestIds;
  final bool submitting;
  final String? error;
  final bool saved;

  EditProfileState copyWith({
    String? username,
    String? bio,
    String? city,
    String? gender,
    String? preferredGender,
    List<String>? interestIds,
    bool? submitting,
    String? error,
    bool clearError = false,
    bool? saved,
  }) =>
      EditProfileState(
        username: username ?? this.username,
        bio: bio ?? this.bio,
        city: city ?? this.city,
        gender: gender ?? this.gender,
        preferredGender: preferredGender ?? this.preferredGender,
        interestIds: interestIds ?? this.interestIds,
        submitting: submitting ?? this.submitting,
        error: clearError ? null : (error ?? this.error),
        saved: saved ?? this.saved,
      );
}

// ─── Edit profile notifier ────────────────────────────────────────────────────

class EditProfileNotifier extends StateNotifier<EditProfileState> {
  EditProfileNotifier(Profile initial, this._repo, this._profileNotifier)
      : super(EditProfileState(
          username: initial.username,
          bio: initial.bio ?? '',
          city: initial.city,
          gender: initial.gender,
          preferredGender: initial.preferredGender,
          interestIds: List.of(initial.interestIds),
        ));

  final ProfileRepository _repo;
  final ProfileNotifier _profileNotifier;

  void updateUsername(String v) => state = state.copyWith(username: v);
  void updateBio(String v) => state = state.copyWith(bio: v);
  void updateCity(String v) => state = state.copyWith(city: v);
  void updateGender(String v) => state = state.copyWith(gender: v);
  void updatePreferredGender(String v) =>
      state = state.copyWith(preferredGender: v);
  void updateInterestIds(List<String> ids) =>
      state = state.copyWith(interestIds: ids);

  Future<void> save(String originalUsername) async {
    state = state.copyWith(submitting: true, clearError: true);
    try {
      final updated = await _repo.updateProfile(
        // Only send username if it actually changed (backend still accepts it
        // even unchanged, but skipping it avoids a spurious uniqueness check).
        username:
            state.username != originalUsername ? state.username : null,
        bio: state.bio,
        city: state.city,
        gender: state.gender,
        preferredGender: state.preferredGender,
        interestIds: state.interestIds,
      );
      _profileNotifier.update(updated);
      state = state.copyWith(submitting: false, saved: true);
    } catch (e) {
      final msg = e.toString();
      final display = msg.contains('409') || msg.contains('username')
          ? 'That username is already taken.'
          : 'Could not save changes. Please try again.';
      state = state.copyWith(submitting: false, error: display);
    }
  }
}

final editProfileNotifierProvider = StateNotifierProvider.autoDispose<
    EditProfileNotifier, EditProfileState>((ref) {
  final profile = ref.read(profileNotifierProvider).requireValue;
  return EditProfileNotifier(
    profile,
    ref.read(profileRepositoryProvider),
    ref.read(profileNotifierProvider.notifier),
  );
});
