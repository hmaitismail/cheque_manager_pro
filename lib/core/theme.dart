import 'package:flutter/material.dart';

class AppColors {
  AppColors._();
  static const bleuNuit = Color(0xFF0B1F3A);
  static const bleuNuitClair = Color(0xFF16325C);
  static const vert = Color(0xFF16A34A);
  static const vertClair = Color(0xFFDCFCE7);
  static const fondClair = Color(0xFFF4F6FA);
  static const fondSombre = Color(0xFF0A1424);
  static const carteSombre = Color(0xFF12223A);
}

class AppTheme {
  AppTheme._();

  static ThemeData clair() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.bleuNuit,
      primary: AppColors.bleuNuit,
      secondary: AppColors.vert,
      surface: Colors.white,
      brightness: Brightness.light,
    );
    return _base(scheme).copyWith(scaffoldBackgroundColor: AppColors.fondClair);
  }

  static ThemeData sombre() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.bleuNuit,
      primary: const Color(0xFF8DB4FF),
      secondary: const Color(0xFF4ADE80),
      surface: AppColors.carteSombre,
      brightness: Brightness.dark,
    );
    return _base(
      scheme,
    ).copyWith(scaffoldBackgroundColor: AppColors.fondSombre);
  }

  static ThemeData _base(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? AppColors.fondSombre : AppColors.bleuNuit,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: dark ? Colors.white10 : const Color(0xFFE3E8F0),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.vert,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.vert,
        foregroundColor: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: dark ? AppColors.bleuNuitClair : AppColors.vertClair,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
