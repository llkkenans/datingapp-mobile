import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kThemeModeKey = 'theme_mode';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier(this._storage) : super(ThemeMode.dark) {
    _load();
  }

  final FlutterSecureStorage _storage;

  Future<void> _load() async {
    final saved = await _storage.read(key: _kThemeModeKey);
    if (saved == 'light') state = ThemeMode.light;
    if (saved == 'system') state = ThemeMode.system;
    // 'dark' and null both leave state as ThemeMode.dark
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _storage.write(key: _kThemeModeKey, value: mode.name);
  }

  Future<void> toggleDarkLight() async {
    final next =
        state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }
}

final _storageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

final themeNotifierProvider =
    StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier(ref.watch(_storageProvider));
});
