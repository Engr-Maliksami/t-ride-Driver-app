import 'dart:convert';

import 'package:t_rider_services_app/config/api_urls.dart';
import 'package:t_rider_services_app/data/local/secure_storage_service.dart';
import 'package:t_rider_services_app/data/models/roles_model.dart';
import 'package:t_rider_services_app/data/network/api_client.dart';

class RolesRepository {
  RolesRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  static const _acceptJson = {'Accept': 'application/json'};

  Future<List<Role>> getRoles() async {
    final response = await _apiClient.get(ApiUrls.roles, headers: _acceptJson);

    if (response.statusCode != 200) {
      throw RolesRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final roles = Roles.fromJson(decoded);
    return roles.roles ?? <Role>[];
  }
}

class RolesRepositoryException implements Exception {
  RolesRepositoryException({required this.statusCode, required this.body});

  final int statusCode;
  final String body;

  @override
  String toString() => 'RolesRepositoryException($statusCode): $body';
}
