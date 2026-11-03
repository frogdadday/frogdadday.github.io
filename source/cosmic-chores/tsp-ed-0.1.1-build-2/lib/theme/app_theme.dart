// /////Block One/////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/cosmic_copy.dart';

abstract final class AppColors {
  static const orange = Color(0xFFFF7518);
  static const orangeSoft = Color(0xFFFFA052);
  static const ink = Color(0xFF18212B);
  static const cream = Color(0xFFFFF8ED);
  static const surface = Color(0xFFFFFCF7);
  static const green = Color(0xFF2F7D5B);
}

// /////Block Two/////////////////////////////////////////////////////////////
ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.orange,
        brightness: Brightness.light,
        surface: AppColors.surface,
      ).copyWith(
        primary: AppColors.orange,
        onPrimary: AppColors.ink,
        secondary: AppColors.green,
        onSecondary: Colors.white,
      );
  return ThemeData(
    extensions: const <ThemeExtension<dynamic>>[AppModeTheme(cosmic: false)],
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.cream,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: AppColors.cream,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0x1F18212B)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0x2418212B)),
      ),
    ),
  );
}

// /////Block Three///////////////////////////////////////////////////////////
ThemeData buildCosmicTheme() {
  const scheme = ColorScheme.dark(
    primary: Color(0xFFFF8A3D),
    onPrimary: Color(0xFF1B120D),
    secondary: Color(0xFF9CCBFF),
    onSecondary: Color(0xFF071020),
    surface: Color(0xE6182540),
    onSurface: Color(0xFFF4F8FF),
    error: Color(0xFFFFB4AB),
  );
  return ThemeData(
    extensions: const <ThemeExtension<dynamic>>[AppModeTheme(cosmic: true)],
    colorScheme: scheme,
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: const Color(0xF20B1427),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Color(0xCC071020),
      foregroundColor: Color(0xFFF4F8FF),
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xE6182540),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0x669CCBFF)),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Color(0xF20B1427),
      indicatorColor: Color(0x66FF8A3D),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Color(0xE6071020),
      indicatorColor: Color(0x66FF8A3D),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xE6121D33),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0x669CCBFF)),
      ),
    ),
  );
}
