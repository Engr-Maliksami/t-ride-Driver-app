import 'dart:convert';

import 'package:t_rider_services_app/config/api_urls.dart';
import 'package:t_rider_services_app/data/local/secure_storage_service.dart';
import 'package:t_rider_services_app/data/network/api_client.dart';

class FeedbackRepository {
  FeedbackRepository({
    ApiClient? apiClient,
    SecureStorageService? storageService,
  }) : _apiClient = apiClient ?? ApiClient(),
       _storageService = storageService ?? SecureStorageService();

  final ApiClient _apiClient;
  final SecureStorageService _storageService;

  static const _defaultHeaders = {'Accept': 'application/json'};

  Future<bool> submitFeedback({
    required String name,
    required String email,
    required String role,
    required String city,
    required String comments,
  }) async {
    final token = await _storageService.getAuthToken();

    final headers = {
      ..._defaultHeaders,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final response = await _apiClient.post(
      ApiUrls.submitFeedback,
      headers: headers,
      body: {
        'name': name,
        'email': email,
        'role': role,
        'city': city,
        'comments': comments,
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = FeedbackRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
      // ignore: avoid_print
      print('FeedbackRepository.submitFeedback error: $error');
      throw error;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final status = decoded['status'];

    if (status is bool) return status;
    if (status is num) return status == 1;

    return true;
  }
}

class FeedbackRepositoryException implements Exception {
  FeedbackRepositoryException({required this.statusCode, required this.body});

  final int statusCode;
  final String body;

  @override
  String toString() => 'FeedbackRepositoryException($statusCode): $body';
}
