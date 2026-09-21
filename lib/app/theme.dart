import 'package:flutter/material.dart';

class AppTheme {
  // Основные цвета
  static const Color background = Color(0xFF07142B);
  static const Color primaryBlue = Color(0xFF2B7FFF);
  static const Color card = Color(0xFF10213D);
  static const Color cardSecondary = Color(0xFF0D1D36);

  static const Color primaryText = Colors.white;
  static const Color secondaryText = Color(0xFFB6C5E0);

  static const Color success = Color(0xFF63D6A3);
  static const Color personalEvent = Color(0xFFB18CFF);
  static const Color danger = Color(0xFFFF6B6B);

  // Размеры
  static const double screenPadding = 20;
  static const double cardRadius = 16;
  static const double smallRadius = 12;

  // Текст
  static const TextStyle pageTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: primaryText,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: primaryText,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: primaryText,
  );

  static const TextStyle bodyText = TextStyle(
    fontSize: 15,
    color: primaryText,
  );

  static const TextStyle secondaryBodyText = TextStyle(
    fontSize: 14,
    height: 1.4,
    color: secondaryText,
  );

  static const TextStyle labelText = TextStyle(
    fontSize: 13,
    color: secondaryText,
  );

  static ThemeData get darkTheme {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primaryBlue,
      surface: card,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      scaffoldBackgroundColor: background,

      colorScheme: colorScheme,

      // ---------------------------
      // APP BAR
      // ---------------------------

      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: primaryText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: primaryText,
        ),
      ),

      // ---------------------------
      // INPUT
      // ---------------------------

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        hintStyle: const TextStyle(
          color: secondaryText,
          fontSize: 15,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          borderSide: const BorderSide(
            color: primaryBlue,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          borderSide: const BorderSide(
            color: danger,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          borderSide: const BorderSide(
            color: danger,
            width: 1.5,
          ),
        ),
      ),

      // ---------------------------
      // FILLED BUTTON
      // ---------------------------

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(
            double.infinity,
            52,
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius),
          ),
        ),
      ),

      // ---------------------------
      // TEXT BUTTON
      // ---------------------------

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
        ),
      ),

      // ---------------------------
      // NAVIGATION BAR
      // ---------------------------

      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: const Color(0xFF171820),
        indicatorColor: const Color(0xFF42516F),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) {
            return TextStyle(
              fontSize: 11,
              color: states.contains(
                WidgetState.selected,
              )
                  ? Colors.white
                  : secondaryText,
            );
          },
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) {
            return IconThemeData(
              size: 23,
              color: states.contains(
                WidgetState.selected,
              )
                  ? Colors.white
                  : secondaryText,
            );
          },
        ),
      ),

      // ---------------------------
      // DIALOG
      // ---------------------------

      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // ---------------------------
      // POPUP MENU
      // ---------------------------

      popupMenuTheme: PopupMenuThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),

      // ---------------------------
      // SNACKBAR
      // ---------------------------

      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: const TextStyle(
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),

      // ---------------------------
      // DATE PICKER
      // ---------------------------

      datePickerTheme: DatePickerThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: card,
        headerForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // ---------------------------
      // PROGRESS INDICATOR
      // ---------------------------

      progressIndicatorTheme:
          const ProgressIndicatorThemeData(
        color: primaryBlue,
      ),

      // ---------------------------
      // DIVIDER
      // ---------------------------

      dividerTheme: const DividerThemeData(
        color: Color(0xFF1C3152),
      ),
    );
  }
}