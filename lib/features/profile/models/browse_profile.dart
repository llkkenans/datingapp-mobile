class BrowseProfile {
  const BrowseProfile({
    required this.userId,
    required this.username,
    required this.city,
    required this.birthDate,
    required this.gender,
    this.avatarUrl,
    this.bio,
  });

  final String userId;
  final String username;
  final String? avatarUrl;
  final String? bio;
  final String city;
  final String birthDate;
  final String gender;

  int get age {
    final dob = DateTime.parse(birthDate).toUtc();
    final now = DateTime.now().toUtc();
    int a = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      a--;
    }
    return a;
  }

  factory BrowseProfile.fromJson(Map<String, dynamic> j) => BrowseProfile(
        userId: j['userId'] as String,
        username: j['username'] as String,
        avatarUrl: j['avatarUrl'] as String?,
        bio: j['bio'] as String?,
        city: j['city'] as String,
        birthDate: j['birthDate'] as String,
        gender: j['gender'] as String,
      );
}
