import 'package:flutter/material.dart';

class AppTheme {
  static const primary     = Color(0xFF00897B);
  static const primaryDark = Color(0xFF00695C);
  static const accent      = Color(0xFF26C6DA);
  static const bg          = Color(0xFFF0FAF9);
  static const surface     = Color(0xFFFFFFFF);
  static const cardBg      = Color(0xFFF7FFFE);

  static const healthy     = Color(0xFF43A047);
  static const moderate    = Color(0xFFFFA726);
  static const danger      = Color(0xFFEF5350);
  static const info        = Color(0xFF42A5F5);

  static const textPrimary = Color(0xFF1A2E2C);
  static const textMuted   = Color(0xFF607D8B);
  static const divider     = Color(0xFFE0F2F1);

  // Dark
  static const bgDark      = Color(0xFF0D1F1E);
  static const surfaceDark = Color(0xFF1A2E2C);
  static const cardDark    = Color(0xFF1F3533);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: bg,
    fontFamily: 'Poppins',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
        fontSize: 18,
        color: textPrimary,
      ),
      iconTheme: IconThemeData(color: textPrimary),
    ),
    // ✅ FIX: Use CardThemeData instead of CardTheme
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: divider, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: bgDark,
    fontFamily: 'Poppins',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
        fontSize: 18,
        color: Colors.white,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    // ✅ FIX: Use CardThemeData instead of CardTheme
    cardTheme: CardThemeData(
      color: surfaceDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );

  static Color healthColor(String label) {
    switch (label) {
      case 'Healthy':  return healthy;
      case 'Moderate': return moderate;
      default:         return danger;
    }
  }

  static Color warningColor(dynamic level) {
    if (level.toString().contains('high'))     return danger;
    if (level.toString().contains('moderate')) return moderate;
    return info;
  }
}