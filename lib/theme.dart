import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: Color(0xFF1E3A8A), // 짙은 네이비
      scaffoldBackgroundColor: Color(0xFF0F172A), // 다크 블루
      colorScheme: ColorScheme.dark(
        primary: Color(0xFFFFD700), // 골드
        secondary: Color(0xFFC0C0C0), // 실버
        error: Color(0xFFDC2626), // 레드
      ),
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.merriweather(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.roboto(
          fontSize: 16,
          color: Colors.white70,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF1E3A8A),
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFFFD700),
        foregroundColor: Colors.black,
      ),
      cardTheme: CardTheme(
        color: Color(0xFF1F2937),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: Color(0xFF3B82F6), // 밝은 블루
      scaffoldBackgroundColor: Color(0xFFF3F4F6), // 연한 그레이
      colorScheme: ColorScheme.light(
        primary: Color(0xFF1E40AF), // 진한 블루
        secondary: Color(0xFFD97706), // 골드
        error: Color(0xFFDC2626), // 레드
      ),
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.merriweather(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        bodyLarge: GoogleFonts.roboto(
          fontSize: 16,
          color: Colors.black87,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF3B82F6),
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF1E40AF),
        foregroundColor: Colors.white,
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}