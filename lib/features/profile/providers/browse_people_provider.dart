import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/browse_profile.dart';
import 'profile_notifier.dart';

final browsePeopleProvider = FutureProvider.autoDispose<List<BrowseProfile>>((ref) {
  return ref.read(profileRepositoryProvider).browsePeople();
});
