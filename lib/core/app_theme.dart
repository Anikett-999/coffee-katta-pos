import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Identity Colors (Coffee Katta Refined Warm Palette)
  static const Color backgroundWarm   = Color(0xFFF7F4EF); // Main background #F7F4EF
  static const Color cardWhite        = Color(0xFFFFFFFF); // Cards #FFFFFF
  static const Color borderWarm       = Color(0xFFE8E1D8); // Borders #E8E1D8
  static const Color primaryCoffee    = Color(0xFF5A3825); // Primary coffee brown #5A3825
  static const Color accentCaramel    = Color(0xFFB77945); // Accent #B77945
  static const Color successGreenPrice= Color(0xFF287A55); // Success/price green #287A55
  static const Color textDark         = Color(0xFF29231F); // Text #29231F

  // Semantic Aliases
  static const Color espressoBrown    = primaryCoffee; // #5A3825
  static const Color warmCaramel      = accentCaramel; // #B77945
  static const Color latteCream       = backgroundWarm; // #F7F4EF
  static const Color warmAmber        = accentCaramel; // #B77945
  static const Color softGrey         = borderWarm;

  // Backwards-Compatible Aliases
  static const Color maroon           = primaryCoffee; // #5A3825
  static const Color cream            = backgroundWarm; // #F7F4EF
  static const Color deepGreen        = successGreenPrice; // #287A55
  static const Color darkBg           = Color(0xFF1E1E1E);

  // Table Status Colors
  static const Color statusAvailable  = Color(0xFF287A55); // Green #287A55 (रिकामे टेबल)
  static const Color statusOccupied   = Color(0xFFD97706); // Warm Amber (सुरू टेबल)
  static const Color statusBilling    = Color(0xFF5A3825); // Deep Brown #5A3825 (बिलिंग)

  static const Color successGreen     = statusAvailable;
  static const Color occupiedOrange   = statusOccupied;
  static const Color billingBlue      = Color(0xFF1E3A8A);
  static const Color primaryRed       = Color(0xFFDC2626);

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
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: TextStyle(
          color: textDark.withValues(alpha: 0.45),
          fontSize: 13,
        ),
        labelStyle: const TextStyle(color: textDark),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderWarm, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderWarm, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: espressoBrown, width: 1.5),
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

