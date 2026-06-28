import '../../onboarding/models/interest.dart';

class Profile {
  const Profile({
    required this.id,
    required this.username,
    required this.gender,
    required this.preferredGender,
    required this.city,
    required this.interests,
    this.bio,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String gender;
  final String preferredGender;
  final String city;
  final List<Interest> interests;
  final String? bio;
  final String? avatarUrl;

  List<String> get interestIds => interests.map((i) => i.id).toList();

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        username: j['username'] as String,
        gender: j['gender'] as String,
        preferredGender: j['preferredGender'] as String,
        city: j['city'] as String,
        interests: (j['interests'] as List? ?? [])
            .map((e) {
              final wrapper = e as Map<String, dynamic>;
              // GET /profiles/me returns [{userId, interestId, interest: {id, name}}]
              final inner = wrapper['interest'] as Map<String, dynamic>?;
              return Interest.fromJson(inner ?? wrapper);
            })
            .toList(),
        bio: j['bio'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
      );
}
