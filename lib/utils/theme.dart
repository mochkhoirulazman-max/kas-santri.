import 'package:flutter/material.dart';

class AppTheme {
  // Aurora Dark Premium Palette
  static const Color darkBackground = Color(0xFF060A12);
  static const Color darkSurface = Color(0xFF0E1626);
  static const Color darkCard = Color(0xFF0F172A);
  static const Color darkGlassBorder = Color(0x22FFFFFF);

  // Vibrant Accents
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldLight = Color(0xFF34D399);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color cyanLight = Color(0xFF38BDF8);
  static const Color fuchsia = Color(0xFFD946EF);
  static const Color purple = Color(0xFFA855F7);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberLight = Color(0xFFFBBF24);
  static const Color rose = Color(0xFFF43F5E);
  static const Color roseLight = Color(0xFFFB7185);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: emerald,
        secondary: cyan,
        surface: darkSurface,
        background: darkBackground,
        error: rose,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: Colors.white,
        onBackground: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: darkSurface.withOpacity(0.85),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: darkGlassBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF090E1A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkGlassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkGlassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: cyanLight, width: 1.5),
        ),
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emerald,
          foregroundColor: const Color(0xFF040914),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: darkGlassBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
