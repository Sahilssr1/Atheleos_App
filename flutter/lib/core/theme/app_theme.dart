import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Premium Gold Accent for Atheleos branding
  static const Color primaryColor = Color(0xFFE5A93B); // Elegant Athletic Gold
  static const Color secondaryColor = Color(0xFF1E1E1E); // Matte Dark Gray
  static const Color backgroundColor = Color(0xFF000000); // Pure Black Background
  static const Color surfaceColor = Color(0xFF121212); // Dark Charcoal Card Surface
  
  static const Color textPrimary = Colors.white; // Pure White for classic matching and aesthetic
  static const Color textSecondary = Color(0xFF94A3B8); // Tailwind slate-400
  static const Color highlightColor = Color(0xFF10B981); // Tailwind emerald-500
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF10B981); // Emerald-500 for success/verification

  // Modern Light Theme (Slate focused)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF121212),
        secondary: primaryColor,
        surface: Colors.white,
        error: errorColor,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: GoogleFonts.spaceGrotesk(fontSize: 36, fontWeight: FontWeight.bold, color: const Color(0xFF121212)),
        displayMedium: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w600, color: const Color(0xFF121212)),
        titleLarge: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w600, color: const Color(0xFF121212)),
        bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.normal, color: const Color(0xFF121212)),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF475569)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF121212)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF121212),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  // Modern Sports-Centric Dark Theme (Pure Black Background & Premium Gold Accents)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: primaryColor,
        surface: surfaceColor,
        error: errorColor,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.spaceGrotesk(fontSize: 36, fontWeight: FontWeight.bold, color: textPrimary),
        displayMedium: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.normal, color: textPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
        bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.normal, color: textSecondary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 1,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF222222), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF121212),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF222222)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF222222)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        floatingLabelStyle: const TextStyle(color: primaryColor),
      ),
    );
  }
}
