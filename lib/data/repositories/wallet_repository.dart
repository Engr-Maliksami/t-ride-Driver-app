import 'dart:convert';

import 'package:t_rider_services_app/config/api_urls.dart';
import 'package:t_rider_services_app/data/local/secure_storage_service.dart';
import 'package:t_rider_services_app/data/models/wallet_model.dart';
import 'package:t_rider_services_app/data/network/api_client.dart';

class WalletRepository {
  WalletRepository({ApiClient? apiClient, SecureStorageService? storageService})
    : _apiClient = apiClient ?? ApiClient(),
      _storageService = storageService ?? SecureStorageService();

  final ApiClient _apiClient;
  final SecureStorageService _storageService;

  static const _defaultHeaders = {'Accept': 'application/json'};

  Future<WalletData> getWallet() async {
    final token = await _storageService.getAuthToken();

    final headers = {
      ..._defaultHeaders,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final response = await _apiClient.get(
      'api/app/wallet/data',
      headers: headers,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = WalletRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
      // ignore: avoid_print
      print('WalletRepository.getWallet error: $error');
      throw error;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return WalletData.fromJson(decoded);
  }

  /// Adds money to wallet and returns raw decoded response.
  ///
  /// Payload:
  /// {
  ///   "amount": 50.00,
  ///   "payment_method": "Card"
  /// }
  Future<Map<String, dynamic>> addMoney({
    required double amount,
    required String paymentMethod,
  }) async {
    final token = await _storageService.getAuthToken();

    final headers = {
      ..._defaultHeaders,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final response = await _apiClient.post(
      'api/app/wallet/add-money',
      headers: headers,
      body: {'amount': amount, 'payment_method': paymentMethod},
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = WalletRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
      // ignore: avoid_print
      print('WalletRepository.addMoney error: $error');
      throw error;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded;
  }

  /// Creates a withdraw request.
  ///
  /// Payload:
  /// {
  ///   "amount": 20.00,
  ///   "payment_method": "Bank Transfer",
  ///   "account_number": "1234567890",
  ///   "iban": "PK12BANK0000001234567890"
  /// }
  Future<Map<String, dynamic>> withdraw({
    required double amount,
    required String paymentMethod,
    required String accountNumber,
    required String iban,
  }) async {
    final token = await _storageService.getAuthToken();

    final headers = {
      ..._defaultHeaders,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final response = await _apiClient.post(
      'api/app/wallet/withdraw',
      headers: headers,
      body: {
        'amount': amount,
        'payment_method': paymentMethod,
        'account_number': accountNumber,
        'iban': iban,
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = WalletRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
      // ignore: avoid_print
      print('WalletRepository.withdraw error: $error');
      throw error;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded;
  }
}

class WalletRepositoryException implements Exception {
  WalletRepositoryException({required this.statusCode, required this.body});

  final int statusCode;
  final String body;

  @override
  String toString() => 'WalletRepositoryException($statusCode): $body';
}
