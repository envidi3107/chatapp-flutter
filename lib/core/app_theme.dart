import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  // Primary brand blue
  static const primary = Color(0xFF3B82F6);
  static const primaryLight = Color(0xFF60A5FA);
  static const primaryDark = Color(0xFF2563EB);

  // Dark backgrounds
  static const bgDark = Color(0xFF0F1117);
  static const bgCard = Color(0xFF1A1D27);
  static const bgInput = Color(0xFF1E2130);
  static const bgSurface = Color(0xFF252836);

  // Text colors
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF9BA3BC);
  static const textHint = Color(0xFF5C6480);

  // Borders
  static const border = Color(0xFF2A2E42);
  static const borderFocused = Color(0xFF3B82F6);

  // Status
  static const online = Color(0xFF22C55E);
  static const badge = Color(0xFF22C55E);
  static const unread = Color(0xFF3B82F6);

  // Bottom nav
  static const navSelected = Color(0xFF3B82F6);
  static const navUnselected = Color(0xFF6B7280);
}

class AppTheme {
  static const appFontFamily = 'Times New Roman';

  static ThemeData get dark {
    final baseTextTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
    ).textTheme;

    final appTextTheme = baseTextTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
      fontFamily: appFontFamily,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: appFontFamily,
      textTheme: appTextTheme,
      primaryTextTheme: appTextTheme,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primaryLight,
        surface: AppColors.bgCard,
        onSurface: AppColors.textPrimary,
        onPrimary: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.bgDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgDark,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgInput,
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.borderFocused, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.bgCard,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.navSelected);
          }
          return const IconThemeData(color: AppColors.navUnselected);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: AppColors.navSelected,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            color: AppColors.navUnselected,
            fontSize: 11,
          );
        }),
        height: 64,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.3),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 0.5,
        space: 0,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.textPrimary,
        iconColor: AppColors.textSecondary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bgSurface,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Keep light alias pointing to dark for backward compat
  static ThemeData get light => dark;
}
