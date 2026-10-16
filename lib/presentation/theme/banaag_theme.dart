import 'package:flutter/material.dart';

class BanaagTheme {
  // Brand Colors: Electric Amber & Industrial Slate
  static const Color primaryAmber = Color(0xFFFFB300);
  static const Color accentElectric = Color(0xFFFF8F00);
  static const Color darkBackground = Color(0xFF121418);
  static const Color surfaceCard = Color(0xFF1E222B);
  static const Color surfaceCardBorder = Color(0xFF2C3240);
  static const Color textHighEmphasis = Color(0xFFF0F2F5);
  static const Color textMuted = Color(0xFF9AA4B2);
  static const Color successGreen = Color(0xFF00E676);
  static const Color alertRed = Color(0xFFFF5252);
  static const Color warningOrange = Color(0xFFFF9100);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryAmber,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryAmber,
        secondary: accentElectric,
        surface: surfaceCard,
        error: alertRed,
        onPrimary: Colors.black,
        onSurface: textHighEmphasis,
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: surfaceCardBorder, width: 1.0),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textHighEmphasis,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAmber,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
