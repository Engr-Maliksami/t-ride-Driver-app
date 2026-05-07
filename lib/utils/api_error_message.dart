import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' show ClientException;

/// Extracts a short, user-facing message from API / network errors.
/// Never returns raw JSON dumps or [Exception.toString] blobs.
String apiErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is TimeoutException) {
    return 'Request timed out. Check your connection and try again.';
  }
  if (error is ClientException) {
    return 'Could not connect. Check your internet and try again.';
  }

  final fromRepo = _messageFromRepositoryStyleError(error, fallback);
  if (fromRepo != null) return fromRepo;

  return fallback;
}

/// Use when the API returned a decoded JSON map (e.g. login with `status: false`).
String messageFromApiMap(
  Map<String, dynamic> map, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  final fromFields = _messageFromJsonMap(map);
  if (fromFields != null && fromFields.isNotEmpty) return fromFields;
  return fallback;
}

/// Any repository exception with [statusCode] and [body] (JSON or short plain text).
String? _messageFromRepositoryStyleError(Object error, String fallback) {
  try {
    final dynamic e = error;
    final code = e.statusCode;
    final body = e.body;
    if (code is! int || body is! String) return null;
    final fromBody = _messageFromResponseBody(body);
    if (fromBody != null && fromBody.isNotEmpty) return fromBody;
    return _messageForStatusCode(code, fallback);
  } catch (_) {
    return null;
  }
}

String? _messageFromResponseBody(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('<')) return null;

  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) {
      final fromMap = _messageFromJsonMap(decoded);
      if (fromMap != null && fromMap.isNotEmpty) return fromMap;
    }
  } catch (_) {
    // Not JSON — may be a short plain-text error body.
  }

  if (trimmed.length <= 280 &&
      !trimmed.startsWith('{') &&
      !trimmed.startsWith('[')) {
    final line = trimmed.split('\n').first.trim();
    if (line.isNotEmpty) return line;
  }
  return null;
}

String? _messageFromJsonMap(Map<String, dynamic> map) {
  final message = map['message'];
  if (message is String && message.trim().isNotEmpty) return message.trim();
  if (message is List && message.isNotEmpty) {
    final first = message.first;
    if (first is String && first.trim().isNotEmpty) return first.trim();
  }

  final err = map['error'];
  if (err is String && err.trim().isNotEmpty) return err.trim();
  if (err is List && err.isNotEmpty) {
    final first = err.first;
    if (first is String && first.trim().isNotEmpty) return first.trim();
  }

  final errors = map['errors'];
  if (errors is Map) {
    for (final value in errors.values) {
      if (value is List && value.isNotEmpty) {
        final first = value.first;
        if (first is String && first.trim().isNotEmpty) return first.trim();
      } else if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
  }

  return null;
}

String _messageForStatusCode(int code, String fallback) {
  return switch (code) {
    400 => 'Invalid request. Please check your input.',
    401 => 'Session expired. Please sign in again.',
    403 => 'You don\'t have permission to do that.',
    404 => 'Service not found. Please try again later.',
    422 => 'Please check your information and try again.',
    429 => 'Too many attempts. Please wait and try again.',
    >= 500 => 'Server error. Please try again later.',
    _ => fallback,
  };
}
