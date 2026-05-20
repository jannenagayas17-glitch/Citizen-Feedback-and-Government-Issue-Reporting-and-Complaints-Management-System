import 'package:flutter/material.dart';

import 'citizen_theme_colors.dart';

class CitizenAppTheme {
  static ThemeData light() {
    final scheme = const ColorScheme(
      brightness: Brightness.light,
      primary: CitizenAppPalette.navy,
      onPrimary: Colors.white,
      secondary: CitizenAppPalette.slate,
      onSecondary: Colors.white,
      tertiary: CitizenAppPalette.mauve,
      onTertiary: Colors.white,
      error: CitizenAppPalette.error,
      onError: Colors.white,
      surface: Color(0xFFF8F4EE),
      onSurface: CitizenAppPalette.navy,
    );

    return _themeFromScheme(
      scheme,
      scaffoldColor: const Color(0xFFF8F4EE),
      cardColor: Colors.white,
      inputColor: const Color(0xFFF4EEE6),
      borderColor: CitizenAppPalette.taupe.withValues(alpha: 0.34),
      shadowColor: CitizenAppPalette.navy.withValues(alpha: 0.08),
    );
  }

  static ThemeData dark() {
    final scheme = const ColorScheme(
      brightness: Brightness.dark,
      primary: CitizenAppPalette.sand,
      onPrimary: CitizenAppPalette.navy,
      secondary: CitizenAppPalette.taupe,
      onSecondary: CitizenAppPalette.navy,
      tertiary: CitizenAppPalette.mauve,
      onTertiary: CitizenAppPalette.navy,
      error: CitizenAppPalette.error,
      onError: Colors.white,
      surface: Color(0xFF121A30),
      onSurface: Color(0xFFF8F2E8),
    );

    return _themeFromScheme(
      scheme,
      scaffoldColor: const Color(0xFF0F1730),
      cardColor: const Color(0xFF1A223B),
      inputColor: const Color(0xFF202A46),
      borderColor: CitizenAppPalette.taupe.withValues(alpha: 0.18),
      shadowColor: Colors.black.withValues(alpha: 0.26),
    );
  }

  static ThemeData _themeFromScheme(
    ColorScheme scheme, {
    required Color scaffoldColor,
    required Color cardColor,
    required Color inputColor,
    required Color borderColor,
    required Color shadowColor,
  }) {
    final titleColor = scheme.onSurface;
    final bodyColor = scheme.brightness == Brightness.dark
        ? CitizenAppPalette.sand.withValues(alpha: 0.78)
        : Color.lerp(CitizenAppPalette.navy, CitizenAppPalette.slate, 0.58)!;

    final textTheme = Typography.material2021().black.apply(
      bodyColor: bodyColor,
      displayColor: titleColor,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldColor,
      cardColor: cardColor,
      shadowColor: shadowColor,
      dividerColor: borderColor,
      textTheme: textTheme.copyWith(
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: titleColor,
          letterSpacing: -0.4,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: titleColor,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: titleColor,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: bodyColor,
          height: 1.45,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: bodyColor,
          height: 1.45,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldColor,
        foregroundColor: titleColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: titleColor,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.brightness == Brightness.dark
            ? CitizenAppPalette.sand
            : CitizenAppPalette.navy,
        contentTextStyle: TextStyle(
          color: scheme.brightness == Brightness.dark
              ? CitizenAppPalette.navy
              : Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: borderColor, thickness: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      bottomAppBarTheme: BottomAppBarThemeData(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: scheme.brightness == Brightness.dark ? 0 : 10,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputColor,
        hintStyle: TextStyle(color: bodyColor.withValues(alpha: 0.80)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        errorMaxLines: 2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: CitizenAppPalette.error,
            width: 1.2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: CitizenAppPalette.error,
            width: 1.3,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.primary.withValues(alpha: 0.45),
          disabledForegroundColor: scheme.onPrimary.withValues(alpha: 0.70),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.primary.withValues(alpha: 0.45),
          disabledForegroundColor: scheme.onPrimary.withValues(alpha: 0.70),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: titleColor,
          side: BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.brightness == Brightness.dark
              ? CitizenAppPalette.sand
              : CitizenAppPalette.navy,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: borderColor, width: 1.4),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
      ),
    );
  }
}
