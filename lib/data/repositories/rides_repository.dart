import 'dart:convert';

import 'package:t_rider_services_app/config/api_urls.dart';
import 'package:t_rider_services_app/data/local/secure_storage_service.dart';
import 'package:t_rider_services_app/data/models/order_active_status_model.dart';
import 'package:t_rider_services_app/data/network/api_client.dart';

class RidesRepository {
  RidesRepository({ApiClient? apiClient, SecureStorageService? storageService})
    : _apiClient = apiClient ?? ApiClient(),
      _storageService = storageService ?? SecureStorageService();

  final ApiClient _apiClient;
  final SecureStorageService _storageService;

  static const _defaultHeaders = {'Accept': 'application/json'};

  Future<Map<String, dynamic>> requestRide({
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String dropoffAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String paymentMethod,
    required num fare,
    required int driverId,
  }) async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw RidesRepositoryException(
        statusCode: 401,
        body: 'Missing auth token',
      );
    }

    final headers = {..._defaultHeaders, 'Authorization': 'Bearer $token'};

    final payload = {
      'pickup_address': pickupAddress,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'dropoff_address': dropoffAddress,
      'dropoff_lat': dropoffLat,
      'dropoff_lng': dropoffLng,
      'payment_method': paymentMethod,
      'fare': fare,
      'driver_id': driverId,
    };

    // ignore: avoid_print
    print('RidesRepository.requestRide payload: $payload');

    final response = await _apiClient.post(
      ApiUrls.ridesRequest,
      headers: headers,
      body: payload,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = RidesRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
      // ignore: avoid_print
      print('RidesRepository.requestRide error: $error');
      throw error;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded;
  }

  Future<Map<String, dynamic>> cancelRide({required int rideId}) async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw RidesRepositoryException(
        statusCode: 401,
        body: 'Missing auth token',
      );
    }

    final headers = {..._defaultHeaders, 'Authorization': 'Bearer $token'};

    final endpoint = ApiUrls.rideCancel(rideId);

    // ignore: avoid_print
    print('RidesRepository.cancelRide endpoint: $endpoint');

    final response = await _apiClient.post(endpoint, headers: headers);

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = RidesRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
      // ignore: avoid_print
      print('RidesRepository.cancelRide error: $error');
      throw error;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded;
  }

  /// `POST /api/app/driver/ride/{rideId}/status`
  Future<Map<String, dynamic>> completeRide({required int rideId}) async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw RidesRepositoryException(
        statusCode: 401,
        body: 'Missing auth token',
      );
    }

    final headers = {..._defaultHeaders, 'Authorization': 'Bearer $token'};
    final endpoint = ApiUrls.rideComplete(rideId);

    // ignore: avoid_print
    print('RidesRepository.completeRide endpoint: $endpoint');

    final response = await _apiClient.post(endpoint, headers: headers);

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = RidesRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
      // ignore: avoid_print
      print('RidesRepository.completeRide error: $error');
      throw error;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded;
  }

  /// `POST /api/app/courier/{courierId}/cancel`
  Future<Map<String, dynamic>> cancelCourierJob({required int courierId}) async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw RidesRepositoryException(
        statusCode: 401,
        body: 'Missing auth token',
      );
    }

    final headers = {..._defaultHeaders, 'Authorization': 'Bearer $token'};
    final endpoint = ApiUrls.courierCancel(courierId);

    // ignore: avoid_print
    print('RidesRepository.cancelCourierJob endpoint: $endpoint');

    final response = await _apiClient.post(endpoint, headers: headers);

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = RidesRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
      // ignore: avoid_print
      print('RidesRepository.cancelCourierJob error: $error');
      throw error;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded;
  }

  /// `POST /api/app/courier/{courierId}/complete`
  Future<Map<String, dynamic>> completeCourierJob({
    required int courierId,
  }) async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw RidesRepositoryException(
        statusCode: 401,
        body: 'Missing auth token',
      );
    }

    final headers = {..._defaultHeaders, 'Authorization': 'Bearer $token'};
    final endpoint = ApiUrls.courierComplete(courierId);

    // ignore: avoid_print
    print('RidesRepository.completeCourierJob endpoint: $endpoint');

    final response = await _apiClient.post(endpoint, headers: headers);

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = RidesRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
      // ignore: avoid_print
      print('RidesRepository.completeCourierJob error: $error');
      throw error;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded;
  }

  /// `POST /api/app/driver/ride/{rideId}/accept`
  Future<Map<String, dynamic>> acceptDriverRide({required int rideId}) async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw RidesRepositoryException(
        statusCode: 401,
        body: 'Missing auth token',
      );
    }

    final headers = {..._defaultHeaders, 'Authorization': 'Bearer $token'};
    final endpoint = ApiUrls.driverAcceptRide(rideId);

    // ignore: avoid_print
    print('RidesRepository.acceptDriverRide endpoint: $endpoint');

    final response = await _apiClient.post(endpoint, headers: headers);

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = RidesRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
      // ignore: avoid_print
      print('RidesRepository.acceptDriverRide error: $error');
      throw error;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded;
  }

  Future<Map<String, dynamic>> getActiveRide() async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw RidesRepositoryException(
        statusCode: 401,
        body: 'Missing auth token',
      );
    }

    final headers = {..._defaultHeaders, 'Authorization': 'Bearer $token'};

    final response = await _apiClient.get(
      ApiUrls.ridesActive,
      headers: headers,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = RidesRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
      // ignore: avoid_print
      print('RidesRepository.getActiveRide error: $error');
      throw error;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded;
  }

  /// `GET /api/app/rides/{rideId}` — single ride details.
  Future<Map<String, dynamic>> getRideDetails({required int rideId}) async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw RidesRepositoryException(
        statusCode: 401,
        body: 'Missing auth token',
      );
    }

    final headers = {..._defaultHeaders, 'Authorization': 'Bearer $token'};
    final endpoint = ApiUrls.rideDetails(rideId);

    // ignore: avoid_print
    print('RidesRepository.getRideDetails endpoint: $endpoint');

    final response = await _apiClient.get(endpoint, headers: headers);

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = RidesRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
      // ignore: avoid_print
      print('RidesRepository.getRideDetails error: $error');
      throw error;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded;
  }

  /// `GET /api/app/courier/{courierId}` — single courier details.
  Future<Map<String, dynamic>> getCourierDetails({
    required int courierId,
  }) async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw RidesRepositoryException(
        statusCode: 401,
        body: 'Missing auth token',
      );
    }

    final headers = {..._defaultHeaders, 'Authorization': 'Bearer $token'};
    final endpoint = ApiUrls.courierDetails(courierId);

    // ignore: avoid_print
    print('RidesRepository.getCourierDetails endpoint: $endpoint');

    final response = await _apiClient.get(endpoint, headers: headers);

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = RidesRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
      // ignore: avoid_print
      print('RidesRepository.getCourierDetails error: $error');
      throw error;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded;
  }

  /// `GET /api/app/rides/active` — all rides in `data` with `service_type` == `ride`.
  Future<List<ActiveRideCourierOrder>> getActiveRideOrders() async {
    final raw = await getActiveRide();
    return _ordersFromActiveData(
      raw,
      include: (r) => (r.serviceType ?? 'ride').toLowerCase() == 'ride',
    );
  }

  Future<Map<String, dynamic>> getActiveCourierResponse() async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw RidesRepositoryException(
        statusCode: 401,
        body: 'Missing auth token',
      );
    }

    final headers = {..._defaultHeaders, 'Authorization': 'Bearer $token'};

    final response = await _apiClient.get(
      ApiUrls.courierActive,
      headers: headers,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = RidesRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
      // ignore: avoid_print
      print('RidesRepository.getActiveCourierResponse error: $error');
      throw error;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded;
  }

  /// `GET /api/app/courier/active` — courier jobs in `data` with `service_type` == `courier`.
  Future<List<ActiveRideCourierOrder>> getActiveCourierOrders() async {
    final raw = await getActiveCourierResponse();
    return _ordersFromActiveData(
      raw,
      include: (r) => (r.serviceType ?? 'courier').toLowerCase() == 'courier',
    );
  }

  Future<Map<String, dynamic>> getActiveFoodOrdersResponse() async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw RidesRepositoryException(
        statusCode: 401,
        body: 'Missing auth token',
      );
    }

    final headers = {..._defaultHeaders, 'Authorization': 'Bearer $token'};

    final response = await _apiClient.get(
      ApiUrls.foodOrderActive,
      headers: headers,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = RidesRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
      // ignore: avoid_print
      print('RidesRepository.getActiveFoodOrdersResponse error: $error');
      throw error;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded;
  }

  /// `GET /api/app/food/order/active` — orders in `data` (list or single object).
  Future<List<ActiveFoodOrder>> getActiveFoodOrders() async {
    final raw = await getActiveFoodOrdersResponse();
    return _foodOrdersFromActiveJson(raw);
  }

  /// `POST /api/app/food/order/{orderId}/cancel`
  Future<Map<String, dynamic>> cancelFoodOrder({required int orderId}) async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw RidesRepositoryException(
        statusCode: 401,
        body: 'Missing auth token',
      );
    }

    final headers = {..._defaultHeaders, 'Authorization': 'Bearer $token'};
    final endpoint = ApiUrls.foodOrderCancel(orderId);

    // ignore: avoid_print
    print('RidesRepository.cancelFoodOrder endpoint: $endpoint');

    final response = await _apiClient.post(endpoint, headers: headers);

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = RidesRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
      // ignore: avoid_print
      print('RidesRepository.cancelFoodOrder error: $error');
      throw error;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded;
  }

  /// `POST /api/app/driver/food/{orderId}/accept`
  Future<Map<String, dynamic>> acceptFoodOrder({required int orderId}) async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw RidesRepositoryException(
        statusCode: 401,
        body: 'Missing auth token',
      );
    }

    final headers = {..._defaultHeaders, 'Authorization': 'Bearer $token'};
    final endpoint = ApiUrls.driverAcceptFoodOrder(orderId);

    // ignore: avoid_print
    print('RidesRepository.acceptFoodOrder endpoint: $endpoint');

    final response = await _apiClient.post(endpoint, headers: headers);

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = RidesRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
      // ignore: avoid_print
      print('RidesRepository.acceptFoodOrder error: $error');
      throw error;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded;
  }

  /// `POST /api/app/food/order/{orderId}/complete`
  Future<Map<String, dynamic>> completeFoodOrder({required int orderId}) async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw RidesRepositoryException(
        statusCode: 401,
        body: 'Missing auth token',
      );
    }

    final headers = {..._defaultHeaders, 'Authorization': 'Bearer $token'};
    final endpoint = ApiUrls.foodOrderComplete(orderId);

    // ignore: avoid_print
    print('RidesRepository.completeFoodOrder endpoint: $endpoint');

    final response = await _apiClient.post(endpoint, headers: headers);

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = RidesRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
      // ignore: avoid_print
      print('RidesRepository.completeFoodOrder error: $error');
      throw error;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded;
  }

  /// `POST /api/app/driver/courier/{id}/accept`
  Future<Map<String, dynamic>> acceptCourierJob({required int courierId}) async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw RidesRepositoryException(
        statusCode: 401,
        body: 'Missing auth token',
      );
    }

    final headers = {..._defaultHeaders, 'Authorization': 'Bearer $token'};
    final endpoint = ApiUrls.driverAcceptCourier(courierId);

    // ignore: avoid_print
    print('RidesRepository.acceptCourierJob endpoint: $endpoint');

    final response = await _apiClient.post(endpoint, headers: headers);

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = RidesRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
      // ignore: avoid_print
      print('RidesRepository.acceptCourierJob error: $error');
      throw error;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded;
  }

  Future<OrderActiveStatusResponse> getActiveOrderStatus() async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw RidesRepositoryException(
        statusCode: 401,
        body: 'Missing auth token',
      );
    }

    final headers = {..._defaultHeaders, 'Authorization': 'Bearer $token'};

    final response = await _apiClient.get(
      ApiUrls.ridesActiveStatus,
      headers: headers,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = RidesRepositoryException(
        statusCode: response.statusCode,
        body: response.body,
      );
      // ignore: avoid_print
      print('RidesRepository.getActiveOrderStatus error: $error');
      throw error;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return OrderActiveStatusResponse.fromJson(decoded);
  }
}

List<ActiveRideCourierOrder> _ordersFromActiveData(
  Map<String, dynamic> json, {
  required bool Function(ActiveRideCourierOrder r) include,
}) {
  final out = <ActiveRideCourierOrder>[];
  void consider(ActiveRideCourierOrder? r) {
    if (r == null || !include(r)) return;
    out.add(r);
  }

  final data = json['data'];
  if (data == null) return out;

  if (data is List) {
    for (final item in data) {
      consider(ActiveRideCourierOrder.maybeFrom(item));
    }
    return out;
  }

  if (data is Map) {
    final map = data is Map<String, dynamic>
        ? data
        : Map<String, dynamic>.from(data);
    consider(ActiveRideCourierOrder.fromJson(map));
  }

  return out;
}

List<ActiveFoodOrder> _foodOrdersFromActiveJson(Map<String, dynamic> json) {
  final out = <ActiveFoodOrder>[];
  final data = json['data'];
  if (data == null) return out;

  if (data is List) {
    for (final item in data) {
      final o = ActiveFoodOrder.maybeFrom(item);
      if (o != null) out.add(o);
    }
    return out;
  }

  final o = ActiveFoodOrder.maybeFrom(data);
  if (o != null) out.add(o);
  return out;
}

class RidesRepositoryException implements Exception {
  RidesRepositoryException({required this.statusCode, required this.body});

  final int statusCode;
  final String body;

  @override
  String toString() => 'RidesRepositoryException($statusCode): $body';
}
