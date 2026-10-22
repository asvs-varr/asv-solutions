import 'package:flutter/material.dart';

enum BanaagThemeMode {
  obsidianThermal, // Bagong theme: Matte Obsidian Charcoal + Thermal Arc Flash
  industrialAmber, // Dati/Classic theme: Industrial Slate & Amber
}

class BanaagTheme {
  // Global ValueNotifier for dynamic runtime theme switching
  static final ValueNotifier<BanaagThemeMode> currentThemeMode =
      ValueNotifier<BanaagThemeMode>(BanaagThemeMode.obsidianThermal);

  // ==========================================
  // 1. OBSIDIAN THERMAL (New - Matches BANAAG Icon)
  // ==========================================
  static const Color obsidianBg = Color(0xFF0C0A09); // Deepest obsidian ember
  static const Color obsidianSurface = Color(0xFF181412); // Warm charcoal card
  static const Color obsidianBorder = Color(0xFF2C221C); // Subtle bronze ember border
  static const Color thermalSparkLemon = Color(0xFFFFEE55); // Peak spark lemon-white
  static const Color thermalGold = Color(0xFFFFB300); // Arc flash gold
  static const Color thermalBronze = Color(0xFFC95B12); // Deep thermal bronze
  static const Color thermalEmber = Color(0xFF80350A); // Ember undertone

  // ==========================================
  // 2. INDUSTRIAL AMBER (Classic/Dati)
  // ==========================================
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

  // Getter for Theme based on selection
  static ThemeData getTheme(BanaagThemeMode mode) {
    switch (mode) {
      case BanaagThemeMode.obsidianThermal:
        return obsidianThermalTheme;
      case BanaagThemeMode.industrialAmber:
        return industrialAmberTheme;
    }
  }

  // Backward compatible default
  static ThemeData get darkTheme => getTheme(currentThemeMode.value);

  // --- THEME 1: Obsidian Thermal Theme (Icon Aligned) ---
  static ThemeData get obsidianThermalTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: thermalGold,
      scaffoldBackgroundColor: obsidianBg,
      colorScheme: const ColorScheme.dark(
        primary: thermalGold,
        secondary: thermalBronze,
        surface: obsidianSurface,
        error: alertRed,
        onPrimary: Colors.black,
        onSurface: textHighEmphasis,
      ),
      cardTheme: CardThemeData(
        color: obsidianSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: obsidianBorder, width: 1.0),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: obsidianBg,
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
          backgroundColor: thermalGold,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  // --- THEME 2: Industrial Amber Theme (Classic/Dati) ---
  static ThemeData get industrialAmberTheme {
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
