import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Dark palette ────────────────────────────────────────────────────────────
  static const _darkBackground     = Color(0xFF0F0F0F);
  static const _darkSurface        = Color(0xFF1C1C1E);
  static const _darkSurfaceVariant = Color(0xFF2C2C2E);
  static const _darkOutline        = Color(0xFF3A3A3C);
  static const _darkMuted          = Color(0xFF8A8A8E);
  static const _accent             = Color(0xFFC0FF00);

  // ── Light palette ───────────────────────────────────────────────────────────
  static const _lightBackground     = Color(0xFFFAFAFA);
  static const _lightSurface        = Color(0xFFFFFFFF);
  static const _lightSurfaceVariant = Color(0xFFF0F0F0);
  static const _lightOutline        = Color(0xFFD0D0D0);
  static const _lightMuted          = Color(0xFF6B6B6B);
  static const _lightOnBackground   = Color(0xFF1A1A1A);
  // #C0FF00 is too light on white; darken to meet contrast on light surfaces
  static const _accentDark          = Color(0xFF6E9400);

  // ── Dark theme ──────────────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: _accent,
          onPrimary: Color(0xFF0F0F0F),
          secondary: _accent,
          onSecondary: Color(0xFF0F0F0F),
          error: Color(0xFFCF6679),
          onError: Colors.white,
          surface: _darkSurface,
          onSurface: Colors.white,
          surfaceContainerHighest: _darkSurfaceVariant,
          onSurfaceVariant: _darkMuted,
          outline: _darkOutline,
          shadow: Colors.black,
          scrim: Colors.black,
          inverseSurface: Colors.white,
          onInverseSurface: Color(0xFF0F0F0F),
          inversePrimary: _accentDark,
          surfaceTint: Colors.transparent,
        ),
        scaffoldBackgroundColor: _darkBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: _darkSurface,
          foregroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        fontFamily: 'SF Pro Display',
      );

  // ── Light theme ─────────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: _accentDark,
          onPrimary: Colors.white,
          secondary: _accentDark,
          onSecondary: Colors.white,
          error: Color(0xFFB00020),
          onError: Colors.white,
          surface: _lightSurface,
          onSurface: _lightOnBackground,
          surfaceContainerHighest: _lightSurfaceVariant,
          onSurfaceVariant: _lightMuted,
          outline: _lightOutline,
          shadow: Colors.black,
          scrim: Colors.black,
          inverseSurface: Color(0xFF1C1C1E),
          onInverseSurface: Colors.white,
          inversePrimary: _accent,
          surfaceTint: Colors.transparent,
        ),
        scaffoldBackgroundColor: _lightBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: _lightSurface,
          foregroundColor: _lightOnBackground,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        fontFamily: 'SF Pro Display',
      );
}
