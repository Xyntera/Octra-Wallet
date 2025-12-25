import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0B0E11),
      primaryColor: const Color(0xFF2E6BFF),
      cardColor: const Color(0xFF12161C),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0B0E11),
        elevation: 0,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white70),
        titleMedium: TextStyle(color: Colors.white),
      ),
    );
  }
}
