class OnboardingForm {
  const OnboardingForm({
    this.username = '',
    this.birthDate,
    this.gender,
    this.preferredGender,
    this.city = '',
    this.avatarUrl,
    this.interestIds = const [],
    this.bio = '',
    this.termsAccepted = false,
  });

  final String username;
  final DateTime? birthDate;
  final String? gender;
  final String? preferredGender;
  final String city;
  final String? avatarUrl;
  final List<String> interestIds;
  final String bio;
  final bool termsAccepted;

  OnboardingForm copyWith({
    String? username,
    DateTime? birthDate,
    String? gender,
    String? preferredGender,
    String? city,
    String? avatarUrl,
    List<String>? interestIds,
    String? bio,
    bool? termsAccepted,
  }) =>
      OnboardingForm(
        username: username ?? this.username,
        birthDate: birthDate ?? this.birthDate,
        gender: gender ?? this.gender,
        preferredGender: preferredGender ?? this.preferredGender,
        city: city ?? this.city,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        interestIds: interestIds ?? this.interestIds,
        bio: bio ?? this.bio,
        termsAccepted: termsAccepted ?? this.termsAccepted,
      );
}
