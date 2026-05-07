import 'package:geolocator/geolocator.dart';
import 'package:t_rider_services_app/data/firestore/firestore_active_order_mapper.dart';

/// Shared 7 km pickup radius for Firestore `active_rides` / `active_courier`.
class FirestoreNearbyHelper {
  FirestoreNearbyHelper._();

  static const double maxRangeKm = 7;
  static double get maxRangeMeters => maxRangeKm * 1000;

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
    final pickup = FirestoreActiveOrderMapper.pickupCoordinates(data);
    if (pickup == null) return null;
    return Geolocator.distanceBetween(
      me.latitude,
      me.longitude,
      pickup.lat,
      pickup.lng,
    );
  }

  static Future<bool> isPickupWithinRange(Map<String, dynamic> data) async {
    final pickup = FirestoreActiveOrderMapper.pickupCoordinates(data);
    if (pickup == null) return false;

    final me = await tryGetCurrentPosition();
    if (me == null) return false;

    final meters = Geolocator.distanceBetween(
      me.latitude,
      me.longitude,
      pickup.lat,
      pickup.lng,
    );
    return meters <= maxRangeMeters;
  }
}
