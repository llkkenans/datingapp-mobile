import 'dart:async';
import 'package:flutter/foundation.dart';

/// Wraps a [Stream] as a [ChangeNotifier] so GoRouter can use it as a
/// [refreshListenable]. GoRouter re-evaluates its redirect whenever the
/// stream emits a new event.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
