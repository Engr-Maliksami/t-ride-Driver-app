import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:t_rider_services_app/config/api_urls.dart';

class ApiClient {
  ApiClient({
    String? baseUrl,
    http.Client? httpClient,
    Duration? requestTimeout,
  }) : baseUrl = baseUrl ?? ApiUrls.baseUrl,
       _httpClient = httpClient ?? http.Client(),
       _requestTimeout = requestTimeout ?? defaultRequestTimeout;

  final String baseUrl;
  final http.Client _httpClient;
  final Duration _requestTimeout;

  /// Applied to every HTTP call (connect + read).
  static const Duration defaultRequestTimeout = Duration(seconds: 30);

  Future<http.Response> _withTimeout(Future<http.Response> future) {
    return future.timeout(
      _requestTimeout,
      onTimeout: () {
        throw TimeoutException(
          'Request timed out after ${_requestTimeout.inSeconds}s',
          _requestTimeout,
        );
      },
    );
  }

  Uri _buildUri(String endpoint, [Map<String, dynamic>? query]) {
    return Uri.parse('$baseUrl$endpoint').replace(
      queryParameters: query?.map((key, value) => MapEntry(key, '$value')),
    );
  }

  Future<http.Response> get(
    String endpoint, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) {
    final uri = _buildUri(endpoint, query);
    return _withTimeout(_httpClient.get(uri, headers: headers));
  }

  Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Object? body,
  }) {
    final uri = _buildUri(endpoint, query);
    return _withTimeout(
      _httpClient.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (headers != null) ...headers,
        },
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<http.Response> put(
    String endpoint, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Object? body,
  }) {
    final uri = _buildUri(endpoint, query);
    return _withTimeout(
      _httpClient.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (headers != null) ...headers,
        },
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<http.Response> delete(
    String endpoint, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Object? body,
  }) {
    final uri = _buildUri(endpoint, query);
    return _withTimeout(
      _httpClient.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (headers != null) ...headers,
        },
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }
}
