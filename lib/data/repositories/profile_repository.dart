import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:t_rider_services_app/config/api_urls.dart';
import 'package:t_rider_services_app/data/local/secure_storage_service.dart';
import 'package:t_rider_services_app/data/models/user_profile_model.dart';
import 'package:t_rider_services_app/data/network/api_client.dart';

class ProfileRepository {
  ProfileRepository({
    ApiClient? apiClient,
    SecureStorageService? storageService,
  }) : _apiClient = apiClient ?? ApiClient(),
       _storageService = storageService ?? SecureStorageService();

  final ApiClient _apiClient;
  final SecureStorageService _storageService;

  static const _defaultHeaders = {'Accept': 'application/json'};

  Future<UserProfile> getProfile() async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw ProfileRepositoryException(
        statusCode: 401,
        body: 'Missing auth token',
      );
    }

    final headers = {..._defaultHeaders, 'Authorization': 'Bearer $token'};

    final response = await _apiClient.get(ApiUrls.getProfile, headers: headers);

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = ProfileRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
      // ignore: avoid_print
      print('ProfileRepository.getProfile error: $error');
      throw error;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final profileResponse = UserProfileResponse.fromJson(decoded);

    if (profileResponse.user == null) {
      throw ProfileRepositoryException(
        statusCode: response.statusCode,
        body: 'Missing user in profile response',
      );
    }

    // ignore: avoid_print
    print('ProfileRepository.getProfile user: ${profileResponse.user}');

    return profileResponse.user!;
  }

  /// Updates the user profile.
  ///
  /// Payload (form-data):
  /// {
  ///   "name": "test",
  ///   "address": "test",
  ///   "region": "test",
  ///   "city": "test",
  ///   "role": "customer",
  ///   "photo": "test.jpg"
  /// }
  Future<UserProfile> updateProfile({
    required String name,
    required String address,
    required String region,
    required String city,
    required String role,
    File? photoFile,
  }) async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw ProfileRepositoryException(
        statusCode: 401,
        body: 'Missing auth token',
      );
    }

    final uri = Uri.parse('${ApiUrls.baseUrl}${ApiUrls.updateProfile}');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({..._defaultHeaders, 'Authorization': 'Bearer $token'})
      ..fields['name'] = name
      ..fields['address'] = address
      ..fields['region'] = region
      ..fields['city'] = city
      ..fields['role'] = role;

    if (photoFile != null) {
      final fileName = photoFile.path.split('/').last;
      request.files.add(
        await http.MultipartFile.fromPath(
          'photo',
          photoFile.path,
          filename: fileName,
        ),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = ProfileRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
      // ignore: avoid_print
      print('ProfileRepository.updateProfile error: $error');
      throw error;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final profileResponse = UserProfileResponse.fromJson(decoded);

    if (profileResponse.user == null) {
      throw ProfileRepositoryException(
        statusCode: response.statusCode,
        body: 'Missing user in update-profile response',
      );
    }

    return profileResponse.user!;
  }
}

class ProfileRepositoryException implements Exception {
  ProfileRepositoryException({required this.statusCode, required this.body});

  final int statusCode;
  final String body;

  @override
  String toString() => 'ProfileRepositoryException($statusCode): $body';
}
