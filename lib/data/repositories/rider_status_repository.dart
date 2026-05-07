import 'dart:convert';
import 'dart:developer' as developer;

import 'package:t_rider_services_app/config/api_urls.dart';
import 'package:t_rider_services_app/data/local/secure_storage_service.dart';
import 'package:t_rider_services_app/data/models/driver_dashboard_model.dart';
import 'package:t_rider_services_app/data/network/api_client.dart';

class RiderStatusRepository {
  RiderStatusRepository({
    ApiClient? apiClient,
    SecureStorageService? storageService,
  })  : _apiClient = apiClient ?? ApiClient(),
        _storageService = storageService ?? SecureStorageService();

  final ApiClient _apiClient;
  final SecureStorageService _storageService;

  static const _defaultHeaders = {'Accept': 'application/json'};

  /// `GET /api/app/driver/dashboard` — source of truth for online status (not cached locally).
  Future<DriverDashboardData> fetchDriverDashboard() async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw RiderStatusRepositoryException(
        statusCode: 401,
        body: 'Missing auth token',
      );
    }

    final response = await _apiClient.get(
      ApiUrls.driverDashboard,
      headers: {..._defaultHeaders, 'Authorization': 'Bearer $token'},
    );

    developer.log(
      'GET ${ApiUrls.driverDashboard} → ${response.statusCode}\n${response.body}',
      name: 'RiderStatusRepository',
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw RiderStatusRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw RiderStatusRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final status = decoded['status'];
    final ok = status == true || status == 1;
    if (!ok) {
      throw RiderStatusRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final data = decoded['data'];
    if (data is! Map) {
      throw RiderStatusRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    return DriverDashboardData.fromJson(Map<String, dynamic>.from(data));
  }

  /// Returns the raw response body (JSON string) for logging or parsing.
  Future<String> updateOnlineStatus({required bool isOnline}) async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw RiderStatusRepositoryException(
        statusCode: 401,
        body: 'Missing auth token',
      );
    }

    final response = await _apiClient.post(
      ApiUrls.updateOnlineStatus,
      headers: {..._defaultHeaders, 'Authorization': 'Bearer $token'},
      body: {'is_online': isOnline},
    );

    developer.log(
      'POST ${ApiUrls.updateOnlineStatus} → ${response.statusCode}\n${response.body}',
      name: 'RiderStatusRepository',
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw RiderStatusRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    return response.body;
  }
}

class RiderStatusRepositoryException implements Exception {
  RiderStatusRepositoryException({required this.statusCode, required this.body});

  final int statusCode;
  final String body;

  @override
  String toString() => 'RiderStatusRepositoryException($statusCode): $body';
}
