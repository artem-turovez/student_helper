import 'package:flutter/material.dart';

class AppTheme {
  static const Color backgroud = Color(0xFF07142B);
  static const Color primaryBlue = Color(0xFF2B7FFF);
  static const Color secondaryText = Color(0xFFB6C5E0);

  static ThemeData get darkTheme {
    return ThemeData (
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroud,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.dark,
        ),
    );
  }
}