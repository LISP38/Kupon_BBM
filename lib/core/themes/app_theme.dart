// lib/core/themes/app_theme.dart

import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.blue, // Warna dasar untuk generate palet M3
      brightness: Brightness.light,
      appBarTheme: const AppBarTheme(
        elevation: 1,
        centerTitle: true,
      ),
      // Anda bisa kustomisasi komponen lain di sini
      // seperti inputDecorationTheme, elevatedButtonTheme, dll.
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.blue,
      brightness: Brightness.dark,
      // Kustomisasi untuk dark theme
    );
  }
}