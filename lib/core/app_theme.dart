import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Identity Colors (Coffee Katta Warm Palette)
  static const Color espressoBrown = Color(0xFF4A2C11); // Deep Espresso
  static const Color warmCaramel   = Color(0xFF8C5835); // Warm Coffee/Caramel
  static const Color latteCream    = Color(0xFFF9F6F0); // Warm Latte Cream Background
  static const Color warmAmber     = Color(0xFFD4A373); // Amber Accent
  static const Color softGrey      = Color(0xFFE8ECEF);
  
  // Backwards-Compatible Aliases (Keeps existing screens compile-clean)
  static const Color maroon        = espressoBrown; // Remaps old maroon to espresso
  static const Color cream         = latteCream;
  static const Color deepGreen     = Color(0xFF2D6A4F); // Rich Emerald (Available)
  static const Color darkBg        = Color(0xFF1E1E1E);
  
  // Table Status Colors
  static const Color statusAvailable = Color(0xFF2D6A4F); // Green (रिकामे टेबल)
  static const Color statusOccupied  = Color(0xFFD97706); // Warm Amber (सुरू टेबल)
  static const Color statusBilling   = Color(0xFF78350F); // Deep Brown (बिलिंग)
  
  static const Color successGreen   = statusAvailable;
  static const Color occupiedOrange = statusOccupied;
  static const Color billingBlue    = Color(0xFF1E3A8A);
  static const Color primaryRed     = Color(0xFFDC2626);

  // Premium Button Style (Editorial look)
  static final _buttonStyle = ElevatedButton.styleFrom(
    backgroundColor: espressoBrown,
    foregroundColor: Colors.white,
    minimumSize: const Size(64, 56), 
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Sharper corners for editorial feel
    elevation: 0, // Flat design for "No-Line" rule
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    textStyle: GoogleFonts.epilogue(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: latteCream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: espressoBrown,
        primary: espressoBrown,
        secondary: warmCaramel,
        surface: Colors.white,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.epilogueTextTheme(),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _buttonStyle),
      cardTheme: CardThemeData(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide.none, // Explicitly no lines
        ),
        elevation: 1, // Minimalist elevation for separation
        margin: const EdgeInsets.all(8),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: latteCream,
        foregroundColor: espressoBrown,
        elevation: 0,
        titleTextStyle: GoogleFonts.epilogue(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: espressoBrown,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: espressoBrown,
        primary: espressoBrown,
        secondary: warmAmber,
        brightness: Brightness.dark,
        surface: darkBg,
      ),
      textTheme: GoogleFonts.epilogueTextTheme(ThemeData.dark().textTheme),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _buttonStyle),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 1,
      ),
    );
  }
}

