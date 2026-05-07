import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:t_rider_services_app/data/local/secure_storage_service.dart';

class AppLanguageController extends GetxController {
  AppLanguageController({SecureStorageService? storageService})
    : _storageService = storageService ?? SecureStorageService();

  final SecureStorageService _storageService;
  final Rx<Locale> locale = const Locale('en').obs;

  @override
  void onInit() {
    super.onInit();
    _loadSavedLocale();
  }

  static const _supportedCodes = {'en', 'ar', 'es', 'fr', 'zh'};

  Future<void> _loadSavedLocale() async {
    final savedLanguageCode = await _storageService.getLanguageCode();
    if (savedLanguageCode != null &&
        _supportedCodes.contains(savedLanguageCode)) {
      locale.value = Locale(savedLanguageCode);
      Get.updateLocale(locale.value);
      return;
    }
    locale.value = const Locale('en');
    Get.updateLocale(locale.value);
  }

  Future<void> changeLanguage(String languageCode) async {
    final code = _supportedCodes.contains(languageCode) ? languageCode : 'en';
    final nextLocale = Locale(code);
    locale.value = nextLocale;
    await _storageService.saveLanguageCode(nextLocale.languageCode);
    Get.updateLocale(nextLocale);
  }
}
