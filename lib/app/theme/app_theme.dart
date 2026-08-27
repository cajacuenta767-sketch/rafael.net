import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seedColor = Color(0xFFB3261E);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF7F7F8),
      appBarTheme: const AppBarTheme(centerTitle: false),
      cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}
