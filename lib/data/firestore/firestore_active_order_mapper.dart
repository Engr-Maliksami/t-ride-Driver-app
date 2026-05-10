import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:t_rider_services_app/data/models/order_active_status_model.dart';

/// Maps Firestore `active_rides` / `active_courier` documents to
/// [ActiveRideCourierOrder] for navigation (same as active order cards).
class FirestoreActiveOrderMapper {
  FirestoreActiveOrderMapper._();

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static String? _string(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  static String _latString(dynamic v) {
    if (v == null) return '—';
    if (v is GeoPoint) return v.latitude.toString();
    return v.toString();
  }

  static String _lngString(dynamic v) {
    if (v == null) return '—';
    if (v is GeoPoint) return v.longitude.toString();
    return v.toString();
  }

  static ActiveDriverSummary? _driverFromAssignedId(dynamic assigned) {
    if (assigned == null) return null;
    return ActiveDriverSummary.fromJson({'driver_id': assigned});
  }

  static DateTime? _acceptedAtFromData(Map<String, dynamic> data) {
    final v = data['accepted_at'];
    if (v == null) return null;
    if (v is Timestamp) return v.toDate().toLocal();
    if (v is String) return DateTime.tryParse(v)?.toLocal();
    if (v is int) {
      return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true).toLocal();
    }
    if (v is num) {
      return DateTime.fromMillisecondsSinceEpoch(v.round(), isUtc: true)
          .toLocal();
    }
    return null;
  }

  /// `active_rides` collection document.
  static ActiveRideCourierOrder activeRideToModel(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final pickup = _asMap(data['pickup']);
    final dropoff = _asMap(data['dropoff']);
    final rider = _asMap(data['rider']);
    final rideIdRaw = data['ride_id'];
    final id = _parseInt(rideIdRaw) ?? _parseInt(documentId);

    return ActiveRideCourierOrder(
      id: id,
      serviceType: _string(data['service_type']),
      rideCustomId: _string(rideIdRaw) ?? documentId,
      riderId: _parseInt(rider?['id']),
      driverId: _parseInt(data['assigned_driver_id']),
      acceptedAt: _acceptedAtFromData(data),
      pickupAddress: _string(pickup?['address']),
      pickupLat: _latString(pickup?['latitude']),
      pickupLng: _lngString(pickup?['longitude']),
      dropoffAddress: _string(dropoff?['address']),
      dropoffLat: _latString(dropoff?['latitude']),
      dropoffLng: _lngString(dropoff?['longitude']),
      fare: data['fare']?.toString(),
      paymentMethod: _string(data['payment_method']),
      status: _string(data['status']),
      driver: _driverFromAssignedId(data['assigned_driver_id']),
    );
  }

  /// `active_courier` collection document.
  static ActiveRideCourierOrder activeCourierToModel(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final pickup = _asMap(data['pickup']);
    final dropoff = _asMap(data['dropoff']);
    final rider = _asMap(data['rider']);
    final pkg = _asMap(data['package']);

    final courierId = _parseInt(data['courier_id']);
    final docIdLabel = _string(data['doc_id']) ?? documentId;

    return ActiveRideCourierOrder(
      id: courierId,
      serviceType: _string(data['service_type']) ?? 'courier',
      rideCustomId: docIdLabel,
      riderId: _parseInt(rider?['id']),
      driverId: _parseInt(data['assigned_driver_id']),
      acceptedAt: _acceptedAtFromData(data),
      receiverName: _string(dropoff?['receiver_name']),
      receiverPhone: _string(dropoff?['receiver_phone']),
      packageSize: pkg?['size']?.toString(),
      packageWeight: pkg?['weight']?.toString(),
      pickupAddress: _string(pickup?['address']),
      pickupInstructions: _string(pickup?['instructions']),
      pickupLat: _latString(pickup?['latitude']),
      pickupLng: _lngString(pickup?['longitude']),
      dropoffAddress: _string(dropoff?['address']),
      dropoffInstructions: _string(dropoff?['instructions']),
      dropoffLat: _latString(dropoff?['latitude']),
      dropoffLng: _lngString(dropoff?['longitude']),
      fare: data['estimated_fare']?.toString(),
      paymentMethod: _string(data['payment_method']),
      status: _string(data['status']),
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  /// Pickup [latitude] / [longitude] in degrees (from nested `pickup`), or null.
  static ({double lat, double lng})? pickupCoordinates(
    Map<String, dynamic> data,
  ) {
    final pickup = _asMap(data['pickup']);
    if (pickup != null) {
      final lat =
          _parseCoordLat(pickup['latitude']) ?? _parseCoordLat(pickup['lat']);
      final lng =
          _parseCoordLng(pickup['longitude']) ?? _parseCoordLng(pickup['lng']);
      if (lat != null && lng != null) return (lat: lat, lng: lng);
    }
    final lat = _parseCoordLat(data['pickup_lat']) ??
        _parseCoordLat(data['pickup_latitude']);
    final lng = _parseCoordLng(data['pickup_lng']) ??
        _parseCoordLng(data['pickup_longitude']);
    if (lat != null && lng != null) return (lat: lat, lng: lng);
    return null;
  }

  /// Dropoff [latitude] / [longitude] in degrees (from nested `dropoff`), or null.
  static ({double lat, double lng})? dropoffCoordinates(
    Map<String, dynamic> data,
  ) {
    final dropoff = _asMap(data['dropoff']);
    if (dropoff != null) {
      final lat =
          _parseCoordLat(dropoff['latitude']) ?? _parseCoordLat(dropoff['lat']);
      final lng = _parseCoordLng(dropoff['longitude']) ??
          _parseCoordLng(dropoff['lng']);
      if (lat != null && lng != null) return (lat: lat, lng: lng);
    }
    final lat = _parseCoordLat(data['dropoff_lat']) ??
        _parseCoordLat(data['dropoff_latitude']);
    final lng = _parseCoordLng(data['dropoff_lng']) ??
        _parseCoordLng(data['dropoff_longitude']);
    if (lat != null && lng != null) return (lat: lat, lng: lng);
    return null;
  }

  static double? _parseCoordLat(dynamic v) {
    if (v == null) return null;
    if (v is GeoPoint) return v.latitude;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static double? _parseCoordLng(dynamic v) {
    if (v == null) return null;
    if (v is GeoPoint) return v.longitude;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
