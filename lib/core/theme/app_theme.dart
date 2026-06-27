import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const _primaryColor = Color(0xFF6C63FF);
  static const _backgroundColor = Color(0xFF0F0F0F);
  static const _surfaceColor = Color(0xFF1C1C1E);
  static const _onSurfaceColor = Color(0xFFFFFFFF);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: _primaryColor,
          surface: _surfaceColor,
          onSurface: _onSurfaceColor,
        ),
        scaffoldBackgroundColor: _backgroundColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: _backgroundColor,
          foregroundColor: _onSurfaceColor,
          elevation: 0,
        ),
        fontFamily: 'SF Pro Display',
      );

  // Light theme reserved for future — dark-first product
  static ThemeData get light => dark;
}
