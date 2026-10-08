import 'package:flutter/material.dart';

/// Centralized brand tokens and theme definitions for Nomad.
///
/// Established in S0.0.7 per identity & branding specification.
/// Colors are derived directly from the authoritative Nomad mark.
abstract final class NomadBrand {
  // Brand Assets & Identifiers
  static const String logoAsset = 'assets/branding/nomad_logo.jpeg';
  static const String productName = 'Nomad';
  static const String tagline = 'Mobile-First Development Lab';
  static const String subTagline = 'Development. Everywhere You Go.';

  // Core Brand Colors (derived from authoritative mark)
  static const Color primary = Color(0xFFD97706); // Warm Amber / Desert Ochre
  static const Color primaryVariant = Color(0xFFB45309);
  static const Color accent = Color(0xFFF59E0B);
  static const Color earth = Color(0xFF462C1D); // Deep leather / warm earth
  static const Color sand = Color(0xFFDDD1C5); // Light sand tone

  // Neutral Surfaces
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color surfaceDark = Color(0xFF0B0F17);
  static const Color surfaceContainerDark = Color(0xFF161E2E);
  static const Color cardDark = Color(0xFF1E293B);

  // Spacing Tokens
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space48 = 48.0;

  // Radius Tokens
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;

  // Light Theme
  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primaryVariant,
      surface: surfaceLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surfaceLight,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: surfaceLight,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: BorderSide(color: Colors.black.withAlpha(20)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: space24,
            vertical: space12,
          ),
        ),
      ),
    );
  }

  // Dark Theme
  static ThemeData darkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: accent,
      surface: surfaceDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surfaceDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: BorderSide(color: Colors.white.withAlpha(20)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: space24,
            vertical: space12,
          ),
        ),
      ),
    );
  }
}
