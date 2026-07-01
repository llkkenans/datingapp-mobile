import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile_detail.dart';
import 'profile_notifier.dart';

final profileDetailProvider =
    FutureProvider.family.autoDispose<ProfileDetail, String>((ref, userId) {
  return ref.read(profileRepositoryProvider).getProfileDetail(userId);
});
