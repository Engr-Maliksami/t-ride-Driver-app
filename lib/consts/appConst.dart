import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:t_rider_services_app/controllers/app_theme_controller.dart';

class AppConst {
  static const String appName = 'T Ride';
  static const String logoBlack = 'assets/T 1.png';
  static const String NewLogo =
      'assets/WhatsApp_Image_2025-12-31_at_2.44.07_AM-removebg-preview.png';
  static const Color primaryColor = Color(0xffFDC700);
  static const Color transparent = Colors.transparent;
  /// Surface (card) color in the default Yellow Theme.
  static const Color _lightBackground = Color(0xffffffff);

  /// Surface (card) color in the alternate White Theme — light grey card.
  static const Color _darkBackground = Color(0xffEFEFEF);

  /// Foreground (text/icons) — black in both themes for readability.
  static const Color _lightForeground = Color(0xff000000);
  static const Color _darkForeground = Color(0xff000000);

  /// Secondary muted grey, same in both themes.
  static const Color _lightGrey = Color(0xff808080);
  static const Color _darkGrey = Color(0xff808080);

  /// Pure white scaffold used by the alternate White Theme.
  static const Color _whiteThemeScaffold = Color(0xffffffff);
  // Brownish-yellow for continue button
  static const Color continueButtonColor = Color(0xffD4A574);
  // Blue for selected language border
  static const Color selectedBorderColor = Color(0xff2196F3);

  static bool get isDarkMode {
    if (Get.isRegistered<AppThemeController>()) {
      return Get.find<AppThemeController>().isDarkMode;
    }
    return Get.isDarkMode;
  }

  static Color get white => isDarkMode ? _darkBackground : _lightBackground;
  static Color get black => isDarkMode ? _darkForeground : _lightForeground;
  static Color get grey => isDarkMode ? _darkGrey : _lightGrey;

  /// Scaffold background. Yellow in default theme, white in alternate theme.
  static Color get scaffoldBackground =>
      isDarkMode ? _whiteThemeScaffold : primaryColor;

  /// Always-dark "branded" header background (top bars). Stays black in both modes.
  static const Color brandedHeader = Color(0xff000000);

  /// White text/icons for the branded header (always white).
  static const Color brandedHeaderForeground = Color(0xffffffff);

  // Helper methods for colors with opacity
  static Color blackWithOpacity(double opacity) {
    final base = black;
    return base.withValues(alpha: opacity);
  }

  static Color primaryColorWithOpacity(double opacity) {
    return Color.fromRGBO(253, 199, 0, opacity);
  }

  static BorderRadius get borderRadius => BorderRadius.only(
    topRight: Radius.circular(20.r),
    bottomLeft: Radius.circular(20.r),
  );
}
