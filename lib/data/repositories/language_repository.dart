import 'dart:convert';

import 'package:t_rider_services_app/config/api_urls.dart';
import 'package:t_rider_services_app/data/local/secure_storage_service.dart';
import 'package:t_rider_services_app/data/models/language_model.dart';
import 'package:t_rider_services_app/data/network/api_client.dart';

class LanguageRepository {
  LanguageRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  static const _acceptJson = {'Accept': 'application/json'};

  /// Fetches languages from {{baseUrl}}/api/languages.
  Future<List<LanguageModel>> getLanguages() async {
    final response = await _apiClient.get(
      ApiUrls.languages,
      headers: _acceptJson,
    );
    if (response.statusCode != 200) {
      throw LanguageRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    final decoded = jsonDecode(response.body) as dynamic;
    // Support both { "data": [...] } and raw [...]
    final list = decoded is List
        ? decoded
        : (decoded is Map && decoded['data'] != null)
        ? decoded['data'] as List
        : <dynamic>[];
    return LanguageModel.fromJsonList(list);
  }
}

class LanguageRepositoryException implements Exception {
  LanguageRepositoryException({required this.statusCode, required this.body});

  final int statusCode;
  final String body;

  @override
  String toString() => 'LanguageRepositoryException($statusCode): $body';
}
