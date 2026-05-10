import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Foreground GPS stream shared by dashboard and fullscreen maps.
///
/// Permanent controller: one [getPositionStream] keeps the driver's puck in sync.
class DriverMapLocationController extends GetxController {
  /// Translation keys for [.tr]; null when permission OK (or still resolving early).
  final Rxn<String> permissionIssueKey = Rxn<String>();

  final Rxn<LatLng> currentLatLng = Rxn<LatLng>();

  /// Degrees clockwise from north (see [Position.heading]).
  final Rx<double> headingDeg = 0.0.obs;

  StreamSubscription<Position>? _positionSubscription;

  static DriverMapLocationController ensure() {
    if (Get.isRegistered<DriverMapLocationController>()) {
      return Get.find<DriverMapLocationController>();
    }
    return Get.put(DriverMapLocationController(), permanent: true);
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(startOrRefresh());
  }

  /// Starts the stream (first time or after settings / permission retry).
  Future<void> startOrRefresh() async {
    permissionIssueKey.value = null;

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      permissionIssueKey.value = 'location_services_off';
      await _cancelStream();
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permissionIssueKey.value = 'location_permission_needed';
      await _cancelStream();
      return;
    }

    permissionIssueKey.value = null;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 3,
    );

    try {
      final first = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      _applyFix(first);
    } catch (_) {}

    await _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      _applyFix,
      onError: (_) {},
    );
  }

  void _applyFix(Position p) {
    currentLatLng.value = LatLng(p.latitude, p.longitude);
    final h = p.heading;
    if (h >= 0 && h <= 360) {
      headingDeg.value = h;
    }
  }

  Future<void> _cancelStream() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  @override
  void onClose() {
    unawaited(_cancelStream());
    super.onClose();
  }
}
