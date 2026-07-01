import '../../onboarding/models/interest.dart';

enum MessageRequestStatus {
  pendingSent,
  pendingReceived,
  accepted,
  declinedByMe,
  declinedByThem;

  static MessageRequestStatus? fromJson(String? value) => switch (value) {
        'PENDING_SENT' => pendingSent,
        'PENDING_RECEIVED' => pendingReceived,
        'ACCEPTED' => accepted,
        'DECLINED_BY_ME' => declinedByMe,
        'DECLINED_BY_THEM' => declinedByThem,
        _ => null,
      };
}

class ProfileDetail {
  const ProfileDetail({
    required this.userId,
    required this.username,
    required this.city,
    required this.birthDate,
    required this.gender,
    required this.interests,
    this.avatarUrl,
    this.bio,
    this.messageRequestStatus,
    this.conversationId,
  });

  final String userId;
  final String username;
  final String? avatarUrl;
  final String? bio;
  final String city;
  final String birthDate;
  final String gender;
  final List<Interest> interests;
  final MessageRequestStatus? messageRequestStatus;
  final String? conversationId;

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

  factory ProfileDetail.fromJson(Map<String, dynamic> j) => ProfileDetail(
        userId: j['userId'] as String,
        username: j['username'] as String,
        avatarUrl: j['avatarUrl'] as String?,
        bio: j['bio'] as String?,
        city: j['city'] as String,
        birthDate: j['birthDate'] as String,
        gender: j['gender'] as String,
        interests: (j['interests'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(Interest.fromJson)
            .toList(),
        messageRequestStatus:
            MessageRequestStatus.fromJson(j['messageRequestStatus'] as String?),
        conversationId: j['conversationId'] as String?,
      );
}
