// ////Block One//////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const background = Color(0xFF07111F);
  static const surface = Color(0xFF0D1A2B);
  static const elevated = Color(0xFF14243A);
  static const text = Color(0xFFF4F7FF);
  static const secondaryText = Color(0xFFA9B7CC);
  static const vibrantGreen = Color(0xFF52F28A);
  static const darkRed = Color(0xFF65151D);
  static const frogYellow = Color(0xFFFFDC45);
  static const cosmicPurple = Color(0xFFB46CFF);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.vibrantGreen,
    brightness: Brightness.dark,
    surface: AppColors.surface,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme.copyWith(
      primary: AppColors.vibrantGreen,
      onPrimary: AppColors.background,
      secondary: AppColors.cosmicPurple,
      surface: AppColors.surface,
      onSurface: AppColors.text,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: AppColors.frogYellow,
        backgroundColor: const Color(0xFF16452B),
        disabledForegroundColor: AppColors.frogYellow.withValues(alpha: 0.45),
        side: const BorderSide(color: AppColors.vibrantGreen),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: AppColors.frogYellow),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.frogYellow),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      textStyle: TextStyle(color: AppColors.frogYellow),
    ),
    scaffoldBackgroundColor: AppColors.background,
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFF203653)),
        borderRadius: BorderRadius.circular(22),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.elevated,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.elevated,
      contentTextStyle: TextStyle(color: AppColors.text),
      actionTextColor: AppColors.frogYellow,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
