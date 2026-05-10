import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:t_rider_services_app/controllers/driver_map_location_controller.dart';
import 'package:t_rider_services_app/data/firestore/firestore_active_order_mapper.dart';

/// Shared 7 km pickup radius for Firestore `active_rides` / `active_courier`.
class FirestoreNearbyHelper {
  FirestoreNearbyHelper._();

  static const double maxRangeKm = 7;
  static double get maxRangeMeters => maxRangeKm * 1000;

  static int? _parseUserId(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  /// Incoming map offers only: not terminal and **no** `accepted_by_user_id`.
  ///
  /// Once any driver accepts (`accepted_by_user_id` set), the offer must not surface.
  static bool isEligibleOpenOffer(Map<String, dynamic> data) {
    if (_isTerminalOrder(data)) return false;

    final acceptedRaw = data['accepted_by_user_id'];
    final acceptedBy = _parseUserId(acceptedRaw);
    return acceptedBy == null;
  }

  static bool _isTerminalOrder(Map<String, dynamic> data) {
    if (data['mark_as_completed'] == true) return true;

    final completion = data['completion_status'];
    if (completion is String) {
      final c = completion.trim().toLowerCase();
      if (c == 'completed' || c == 'done' || c == 'delivered') return true;
    }

    final status = data['status'];
    if (status is String) {
      final s = status.trim().toLowerCase().replaceAll(' ', '_');
      if (s == 'completed' ||
          s == 'done' ||
          s == 'delivered' ||
          s == 'cancelled' ||
          s == 'canceled') {
        return true;
      }
    }
    return false;
  }

  /// Prefers live [DriverMapLocationController] stream, then one-shot GPS.
  static Future<({double lat, double lng})?> tryDriverReferencePoint() async {
    try {
      if (Get.isRegistered<DriverMapLocationController>()) {
        final ll = DriverMapLocationController.ensure().currentLatLng.value;
        if (ll != null) {
          return (lat: ll.latitude, lng: ll.longitude);
        }
      }
    } catch (_) {}

    final p = await tryGetCurrentPosition();
    if (p == null) return null;
    return (lat: p.latitude, lng: p.longitude);
  }

  static Future<Position?> tryGetCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Distance from [me] to document's `pickup`, or null if pickup coords missing.
  static double? distanceMetersToPickup(
    Map<String, dynamic> data,
    Position me,
  ) {
    return distanceMetersToPickupFromCoords(data, me.latitude, me.longitude);
  }

  static double? distanceMetersToPickupFromCoords(
    Map<String, dynamic> data,
    double myLat,
    double myLng,
  ) {
    final pickup = FirestoreActiveOrderMapper.pickupCoordinates(data);
    if (pickup == null) return null;
    return Geolocator.distanceBetween(myLat, myLng, pickup.lat, pickup.lng);
  }

  static Future<bool> isPickupWithinRange(Map<String, dynamic> data) async {
    final pickup = FirestoreActiveOrderMapper.pickupCoordinates(data);
    if (pickup == null) return false;

    final me = await tryDriverReferencePoint();
    if (me == null) return false;

    final meters = Geolocator.distanceBetween(
      me.lat,
      me.lng,
      pickup.lat,
      pickup.lng,
    );
    return meters <= maxRangeMeters;
  }
}
