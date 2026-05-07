import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _keyAuthToken = 'auth_token';
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyLanguageCode = 'language_code';
  static const String _keyUserId = 'user_id';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyCarModel = 'car_model';
  static const String _keyCarPlateNumber = 'car_plate_number';
  static const String _keyCarColor = 'car_color';

  Future<void> saveAuthToken(String token) {
    return _storage.write(key: _keyAuthToken, value: token);
  }

  Future<String?> getAuthToken() {
    return _storage.read(key: _keyAuthToken);
  }

  Future<void> clearAuthToken() async {
    await _storage.delete(key: _keyAuthToken);
  }

  Future<void> saveUserId(int userId) {
    return _storage.write(key: _keyUserId, value: userId.toString());
  }

  Future<int?> getUserId() async {
    final raw = await _storage.read(key: _keyUserId);
    if (raw == null || raw.trim().isEmpty) return null;
    return int.tryParse(raw.trim());
  }

  Future<void> clearUserId() async {
    await _storage.delete(key: _keyUserId);
  }

  Future<void> setOnboardingCompleted() {
    return _storage.write(key: _keyOnboardingCompleted, value: 'true');
  }

  Future<bool> isOnboardingCompleted() async {
    final value = await _storage.read(key: _keyOnboardingCompleted);
    return value == 'true';
  }

  Future<void> saveLanguageCode(String languageCode) {
    return _storage.write(key: _keyLanguageCode, value: languageCode);
  }

  Future<String?> getLanguageCode() {
    return _storage.read(key: _keyLanguageCode);
  }

  /// Persisted app theme mode. Stored as `'dark'` or `'light'`.
  Future<void> saveThemeMode(String mode) {
    return _storage.write(key: _keyThemeMode, value: mode);
  }

  Future<String?> getThemeMode() {
    return _storage.read(key: _keyThemeMode);
  }

  Future<void> saveCarInfo({
    required String model,
    required String plateNumber,
    required String color,
  }) async {
    await _storage.write(key: _keyCarModel, value: model);
    await _storage.write(key: _keyCarPlateNumber, value: plateNumber);
    await _storage.write(key: _keyCarColor, value: color);
  }

  Future<Map<String, String>> getCarInfo() async {
    final model = await _storage.read(key: _keyCarModel) ?? '';
    final plateNumber = await _storage.read(key: _keyCarPlateNumber) ?? '';
    final color = await _storage.read(key: _keyCarColor) ?? '';
    return {
      'model': model,
      'plateNumber': plateNumber,
      'color': color,
    };
  }
}

