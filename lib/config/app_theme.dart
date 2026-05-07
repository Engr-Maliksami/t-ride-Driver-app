import 'package:flutter/material.dart';
import 'package:t_rider_services_app/consts/appConst.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppConst.primaryColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      primaryColor: AppConst.primaryColor,
      scaffoldBackgroundColor: const Color(0xfff5f5f5),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
    );
  }

  /// Alternate "White Theme" — white scaffold, light grey cards, black text.
  /// Kept under `darkTheme` so existing `themeMode` switching keeps working.
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppConst.primaryColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      primaryColor: AppConst.primaryColor,
      scaffoldBackgroundColor: const Color(0xffffffff),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
    );
  }
}
