import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:t_rider_services_app/data/local/secure_storage_service.dart';

class AppThemeController extends GetxController {
  AppThemeController({SecureStorageService? storageService})
    : _storageService = storageService ?? SecureStorageService();

  final SecureStorageService _storageService;

  static const String _darkValue = 'dark';
  static const String _lightValue = 'light';

  final Rx<ThemeMode> themeMode = ThemeMode.light.obs;

  bool get isDarkMode => themeMode.value == ThemeMode.dark;

  @override
  void onInit() {
    super.onInit();
    _loadPersistedThemeMode();
  }

  Future<void> _loadPersistedThemeMode() async {
    try {
      final saved = await _storageService.getThemeMode();
      if (saved == _darkValue) {
        themeMode.value = ThemeMode.dark;
        Get.changeThemeMode(ThemeMode.dark);
      } else {
        themeMode.value = ThemeMode.light;
        Get.changeThemeMode(ThemeMode.light);
      }
    } catch (_) {
      // Silently fall back to light mode on any storage read failure.
    }
  }

  Future<void> setDarkMode(bool isDarkModeEnabled) async {
    final newMode = isDarkModeEnabled ? ThemeMode.dark : ThemeMode.light;
    themeMode.value = newMode;
    Get.changeThemeMode(newMode);
    try {
      await _storageService.saveThemeMode(
        isDarkModeEnabled ? _darkValue : _lightValue,
      );
    } catch (_) {
      // Persistence failure shouldn't break runtime mode switch.
    }
  }
}
