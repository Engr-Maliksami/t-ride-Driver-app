import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';
import 'package:t_rider_services_app/consts/appConst.dart';
import 'package:t_rider_services_app/data/local/secure_storage_service.dart';
import 'package:t_rider_services_app/data/directions/google_directions_service.dart';
import 'package:t_rider_services_app/data/models/order_active_status_model.dart';
import 'package:t_rider_services_app/data/repositories/rides_repository.dart';
import 'package:t_rider_services_app/views/home/setting/setting_screen.dart';
import 'package:t_rider_services_app/views/widgets/app_snackbar.dart';

class FindingRideRequestsScreen extends StatefulWidget {
  const FindingRideRequestsScreen({
    super.key,
    this.ride,
    this.preferAcceptAction = false,
    this.firestoreDocId,
    this.firestoreCollection,
  });

  /// When set, details come from [GET /api/app/rides/active] (searching ride).
  final ActiveRideCourierOrder? ride;

  /// When true (e.g. Firestore available orders), show **Accept** for any
  /// non-terminal status instead of only `searching` / `pending`.
  final bool preferAcceptAction;
  final String? firestoreDocId;
  final String? firestoreCollection;

  static ({String kind, int? orderId, String? docId})? currentlyViewingOrder;

  @override
  State<FindingRideRequestsScreen> createState() =>
      _FindingRideRequestsScreenState();
}

class _FindingRideRequestsScreenState extends State<FindingRideRequestsScreen> {
  final RidesRepository _ridesRepository = RidesRepository();
  final SecureStorageService _storageService = SecureStorageService();
  GoogleMapController? _mapController;
  bool _rideActionInProgress = false;
  bool _detailsLoading = false;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  /// Road-following points from Directions API; `null` until loaded or if fetch fails.
  List<LatLng>? _drivingPolylinePoints;
  LatLng? _driverLatLng;

  /// True while requesting driving directions (no placeholder straight line yet).
  bool _routeLoading = false;
  bool _driverLocationSyncing = false;
  Timer? _driverLocationTimer;
  BitmapDescriptor _driverMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
    BitmapDescriptor.hueAzure,
  );

  /// After a successful accept API call; switches primary action from Accept → Cancel.
  bool _acceptedThisSession = false;
  ActiveRideCourierOrder? _rideData;

  ActiveRideCourierOrder? get _ride => _rideData;

  bool get _isCourier =>
      (_ride?.serviceType ?? '').trim().toLowerCase() == 'courier';

  static const LatLng _fallbackMapCenter = LatLng(24.8607, 67.0011);

  /// Set to [false] to remove the dev-only "Firestore only" complete control.
  static const bool kShowFirestoreOnlyCompleteButton = true;

  LatLng? get _pickupLatLng => _parseLatLng(_ride?.pickupLat, _ride?.pickupLng);

  LatLng? get _dropLatLng => _parseLatLng(_ride?.dropoffLat, _ride?.dropoffLng);

  LatLng? _parseLatLng(String? lat, String? lng) {
    final la = double.tryParse(lat ?? '');
    final lo = double.tryParse(lng ?? '');
    if (la == null || lo == null) return null;
    return LatLng(la, lo);
  }

  CameraPosition get _initialCamera {
    final p = _pickupLatLng;
    final d = _dropLatLng;
    if (p != null && d != null) {
      return CameraPosition(
        target: LatLng(
          (p.latitude + d.latitude) / 2,
          (p.longitude + d.longitude) / 2,
        ),
        zoom: 12,
      );
    }
    return CameraPosition(target: p ?? d ?? _fallbackMapCenter, zoom: 13);
  }

  /// When [awaitDirections] is true, markers are set but no polyline until the
  /// API returns (or fails — then a straight fallback is drawn).
  void _populateMapOverlays({bool awaitDirections = false}) {
    final r = _ride;
    final pickup = _pickupLatLng;
    final drop = _dropLatLng;
    _markers.clear();
    _polylines.clear();
    if (pickup != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: 'pickup'.tr,
            snippet: _shortSnippet(r?.pickupAddress),
          ),
        ),
      );
    }
    if (drop != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: drop,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'destination'.tr,
            snippet: _shortSnippet(r?.dropoffAddress),
          ),
        ),
      );
    }
    final driver = _driverLatLng;
    if (driver != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: driver,
          icon: _driverMarkerIcon,
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(title: 'driver'.tr),
        ),
      );
    }
    if (pickup != null && drop != null && !awaitDirections) {
      _setPrimaryRoutePolylinePoints([pickup, drop], geodesic: true);
    }
    if (driver != null && pickup != null && !awaitDirections) {
      final fallbackPoints = <LatLng>[driver, pickup];
      if (drop != null) fallbackPoints.add(drop);
      _setDriverToDestinationPolylinePoints(fallbackPoints, geodesic: true);
    }
  }

  Future<void> _initDriverMarkerIcon() async {
    final customIcon = await _buildDriverMarkerIcon();
    if (!mounted || customIcon == null) return;
    setState(() => _driverMarkerIcon = customIcon);
    _refreshDriverMarker();
  }

  Future<BitmapDescriptor?> _buildDriverMarkerIcon() async {
    const double canvasSize = 80;
    const double circleRadius = 28;
    const double iconSize = 34;
    const Color backgroundColor = Colors.blueAccent;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = const Offset(canvasSize / 2, canvasSize / 2);

    final circlePaint = Paint()..color = backgroundColor;
    canvas.drawCircle(center, circleRadius, circlePaint);

    final iconPainter = TextPainter(textDirection: TextDirection.ltr);
    iconPainter.text = TextSpan(
      text: String.fromCharCode(Icons.directions_car.codePoint),
      style: TextStyle(
        fontSize: iconSize,
        fontFamily: Icons.directions_car.fontFamily,
        package: Icons.directions_car.fontPackage,
        color: Colors.black,
      ),
    );
    iconPainter.layout();
    final iconOffset = Offset(
      center.dx - (iconPainter.width / 2),
      center.dy - (iconPainter.height / 2),
    );
    iconPainter.paint(canvas, iconOffset);

    final image = await recorder.endRecording().toImage(
      canvasSize.toInt(),
      canvasSize.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();
    if (bytes == null) return null;
    return BitmapDescriptor.bytes(bytes);
  }

  void _refreshDriverMarker() {
    final driver = _driverLatLng;
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'driver');
      if (driver != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('driver'),
            position: driver,
            icon: _driverMarkerIcon,
            anchor: const Offset(0.5, 0.5),
            infoWindow: InfoWindow(title: 'driver'.tr),
          ),
        );
      }
    });
  }

  void _setPrimaryRoutePolylinePoints(
    List<LatLng> points, {
    required bool geodesic,
  }) {
    _polylines.removeWhere((p) => p.polylineId.value == 'route');
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: AppConst.black,
        width: 5,
        geodesic: geodesic,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    );
  }

  void _setDriverToDestinationPolylinePoints(
    List<LatLng> points, {
    required bool geodesic,
  }) {
    _polylines.removeWhere((p) => p.polylineId.value == 'driver_to_drop');
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('driver_to_drop'),
        points: points,
        color: Colors.blueAccent,
        width: 5,
        geodesic: geodesic,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    );
  }

  Future<void> _loadDrivingRoute() async {
    final pickup = _pickupLatLng;
    final drop = _dropLatLng;
    if (pickup == null || drop == null) {
      if (mounted) setState(() => _routeLoading = false);
      return;
    }

    final pts = await GoogleDirectionsService.fetchDrivingPolyline(
      origin: pickup,
      destination: drop,
    );

    if (!mounted) return;

    if (pts != null && pts.length >= 2) {
      setState(() {
        _routeLoading = false;
        _drivingPolylinePoints = pts;
        _setPrimaryRoutePolylinePoints(pts, geodesic: false);
      });
      await _fitCameraToRoute();
    } else {
      setState(() {
        _routeLoading = false;
        _drivingPolylinePoints = null;
        _setPrimaryRoutePolylinePoints([pickup, drop], geodesic: true);
      });
      await _fitCameraToRoute();
    }
  }

  Future<void> _loadDriverToDestinationRoute() async {
    final driver = _driverLatLng;
    final pickup = _pickupLatLng;
    final drop = _dropLatLng;
    if (driver == null || pickup == null) {
      if (mounted) {
        setState(() {
          _polylines.removeWhere((p) => p.polylineId.value == 'driver_to_drop');
        });
      }
      return;
    }

    // Segment 1: driver -> pickup
    final driverToPickup = await GoogleDirectionsService.fetchDrivingPolyline(
      origin: driver,
      destination: pickup,
    );

    // Segment 2: pickup -> destination (optional when destination exists)
    List<LatLng>? pickupToDrop;
    if (drop != null) {
      pickupToDrop = await GoogleDirectionsService.fetchDrivingPolyline(
        origin: pickup,
        destination: drop,
      );
    }

    if (!mounted) return;
    setState(() {
      final fallbackPoints = <LatLng>[driver, pickup];
      if (drop != null) fallbackPoints.add(drop);

      if (driverToPickup == null || driverToPickup.length < 2) {
        _setDriverToDestinationPolylinePoints(fallbackPoints, geodesic: true);
        return;
      }

      final merged = <LatLng>[...driverToPickup];
      if (pickupToDrop != null && pickupToDrop.length >= 2) {
        // Avoid duplicating pickup point if segment2 starts where segment1 ends.
        merged.addAll(pickupToDrop.skip(1));
      } else if (drop != null) {
        merged.add(drop);
      }
      _setDriverToDestinationPolylinePoints(merged, geodesic: false);
    });
  }

  Future<void> _refreshDriverLocationAndRoute({
    required bool writeToFirestore,
  }) async {
    if (_driverLocationSyncing) return;
    setState(() => _driverLocationSyncing = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final nextDriver = LatLng(position.latitude, position.longitude);
      if (mounted) {
        _driverLatLng = nextDriver;
        _refreshDriverMarker();
      }

      if (writeToFirestore &&
          widget.firestoreDocId != null &&
          widget.firestoreDocId!.isNotEmpty) {
        final collection =
            widget.firestoreCollection ??
            (_isCourier ? 'active_courier' : 'active_rides');
        await FirebaseFirestore.instance
            .collection(collection)
            .doc(widget.firestoreDocId)
            .set({
              'driver_location': {
                'latitude': nextDriver.latitude,
                'longitude': nextDriver.longitude,
                'updated_at': FieldValue.serverTimestamp(),
              },
            }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[FindingRideRequestsScreen][driver_location] error: $e');
    } finally {
      if (mounted) {
        setState(() => _driverLocationSyncing = false);
      }
    }
  }

  void _startDriverLiveLocationUpdates() {
    if (_driverLocationTimer?.isActive ?? false) return;
    _driverLocationTimer?.cancel();
    _driverLocationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _refreshDriverLocationAndRoute(writeToFirestore: true);
    });
  }

  void _stopDriverLiveLocationUpdates() {
    _driverLocationTimer?.cancel();
    _driverLocationTimer = null;
  }

  bool get _shouldTrackDriverLiveLocation {
    if (_isTerminalJobStatus) return false;
    if (_acceptedThisSession) return true;
    if (_ride?.driverId != null) return true;
    return false;
  }

  Future<void> _ensureDriverLiveLocationTracking() async {
    if (_shouldTrackDriverLiveLocation) {
      await _refreshDriverLocationAndRoute(writeToFirestore: true);
      _startDriverLiveLocationUpdates();
      return;
    }
    _stopDriverLiveLocationUpdates();
  }

  Future<void> _loadDriverLocationFromFirestoreIfAny() async {
    if (widget.firestoreDocId == null || widget.firestoreDocId!.isEmpty) return;
    try {
      final collection =
          widget.firestoreCollection ??
          (_isCourier ? 'active_courier' : 'active_rides');
      final snap = await FirebaseFirestore.instance
          .collection(collection)
          .doc(widget.firestoreDocId)
          .get();
      final data = snap.data();
      if (data == null) return;
      final loc = data['driver_location'];
      if (loc is! Map) return;
      final latRaw = loc['latitude'];
      final lngRaw = loc['longitude'];
      final lat = latRaw is num
          ? latRaw.toDouble()
          : double.tryParse('$latRaw');
      final lng = lngRaw is num
          ? lngRaw.toDouble()
          : double.tryParse('$lngRaw');
      if (lat == null || lng == null) return;
      if (!mounted) return;
      setState(() {
        _driverLatLng = LatLng(lat, lng);
        _populateMapOverlays(awaitDirections: true);
      });
      await _loadDriverToDestinationRoute();
    } catch (e) {
      debugPrint('[FindingRideRequestsScreen][driver_location_read] error: $e');
    }
  }

  String? _shortSnippet(String? text) {
    if (text == null || text.isEmpty) return null;
    if (text.length <= 64) return text;
    return '${text.substring(0, 61)}…';
  }

  Future<void> _fitCameraToRoute() async {
    final c = _mapController;
    if (c == null || !mounted) return;

    final path = _drivingPolylinePoints;
    if (path != null && path.length >= 2) {
      await _fitCameraToPoints(c, path);
      return;
    }

    final a = _pickupLatLng;
    final b = _dropLatLng;
    if (a != null && b != null) {
      await _fitCameraToPoints(c, [a, b]);
      return;
    }

    final single = a ?? b;
    if (single != null) {
      await c.animateCamera(CameraUpdate.newLatLngZoom(single, 14));
    }
  }

  Future<void> _fitCameraToPoints(
    GoogleMapController c,
    List<LatLng> points,
  ) async {
    if (points.length < 2) return;

    var minLat = points.first.latitude;
    var maxLat = minLat;
    var minLng = points.first.longitude;
    var maxLng = minLng;

    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    final latSpan = (maxLat - minLat).abs();
    final lngSpan = (maxLng - minLng).abs();
    if (latSpan < 1e-6 && lngSpan < 1e-6) {
      await c.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
      return;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    await c.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
  }

  String get _passengerLine {
    final r = _ride;
    if (r?.rideCustomId != null && r!.rideCustomId!.isNotEmpty) {
      return '${'request'.tr} ${r.rideCustomId}';
    }
    return '${'passenger'.tr}: John Doe';
  }

  String get _pickupLine {
    final a = _ride?.pickupAddress;
    if (a != null && a.isNotEmpty) return '${'pickup'.tr}: $a';
    return '${'pickup_location'.tr}: ~Plot 504';
  }

  String get _dropLine {
    final a = _ride?.dropoffAddress;
    if (a != null && a.isNotEmpty) return '${'drop'.tr}: $a';
    return '${'drop_location'.tr}: ~Street 2';
  }

  String get _fareLine {
    final f = _ride?.fare;
    if (f != null && f.isNotEmpty) {
      final p = _ride?.paymentMethod;
      if (p != null && p.isNotEmpty) return '${'fare'.tr}: $f • $p';
      return '${'fare'.tr}: $f';
    }
    return '${'distance_to_pickup'.tr}: ~24mins';
  }

  /// For rides fetched from `GET /api/app/rides/{id}`:
  /// - if `driver_id` is missing -> show Accept
  /// - otherwise -> show Mark as complete
  bool get _showAcceptButton {
    if (_detailsLoading) return false;
    if (_ride == null) return false;
    if (_acceptedThisSession) return false;
    if (!_isCourier) {
      if (_isTerminalJobStatus) return false;
      return _ride?.driverId == null;
    }
    if (widget.preferAcceptAction) return !_isTerminalJobStatus;
    final s = (_ride?.status ?? '').trim().toLowerCase();
    return s == 'searching' || s == 'pending';
  }

  bool get _isTerminalJobStatus {
    final s = (_ride?.status ?? '').trim().toLowerCase().replaceAll(' ', '_');
    return s == 'completed' ||
        s == 'cancelled' ||
        s == 'canceled' ||
        s == 'done' ||
        s == 'delivered';
  }

  /// After accept (or server-side accepted), offer complete + cancel unless already terminal.
  bool get _showMarkCompleteButton {
    if (_detailsLoading) return false;
    if (_ride == null || _isTerminalJobStatus) return false;
    if (!_isCourier) {
      return _ride?.driverId != null;
    }
    return !_showAcceptButton;
  }

  Future<void> _fetchOrderDetailsIfNeeded() async {
    final id = _ride?.id;
    if (id == null) return;
    setState(() => _detailsLoading = true);
    try {
      final response = _isCourier
          ? await _ridesRepository.getCourierDetails(courierId: id)
          : await _ridesRepository.getRideDetails(rideId: id);
      final data = response['data'];
      final dataMap = data is Map<String, dynamic>
          ? data
          : (data is Map ? Map<String, dynamic>.from(data) : null);
      final apiStatus = dataMap?['status'];
      debugPrint(
        '[FindingRideRequestsScreen][${_isCourier ? 'courier_details' : 'ride_details'}] response.status=${response['status']}, data.status=$apiStatus',
      );
      debugPrint(
        '[FindingRideRequestsScreen][${_isCourier ? 'courier_details' : 'ride_details'}] full response: $response',
      );
      if (dataMap != null) {
        debugPrint(
          '[FindingRideRequestsScreen][${_isCourier ? 'courier_details' : 'ride_details'}] details data: $dataMap',
        );
      }
      if (dataMap != null && mounted) {
        setState(() {
          _rideData = ActiveRideCourierOrder.fromJson(dataMap);
          _detailsLoading = false;
        });
        _syncViewingOrderMarker();
        final awaitsRoute = _pickupLatLng != null && _dropLatLng != null;
        if (mounted) {
          setState(() => _routeLoading = awaitsRoute);
          _populateMapOverlays(awaitDirections: awaitsRoute);
        }
        _loadDrivingRoute();
        await _ensureDriverLiveLocationTracking();
        return;
      }
    } catch (e) {
      debugPrint(
        '[FindingRideRequestsScreen][${_isCourier ? 'courier_details' : 'ride_details'}] error: $e',
      );
    }
    if (mounted) {
      setState(() => _detailsLoading = false);
    }
  }

  void _logApiStatus({
    required String action,
    required Map<String, dynamic> response,
  }) {
    final rootStatus = response['status'];
    final data = response['data'];
    dynamic nestedStatus;
    if (data is Map<String, dynamic>) {
      nestedStatus = data['status'];
    } else if (data is Map) {
      nestedStatus = data['status'];
    }
    debugPrint(
      '[FindingRideRequestsScreen][$action] response.status=$rootStatus, data.status=$nestedStatus',
    );
  }

  void _syncViewingOrderMarker() {
    FindingRideRequestsScreen.currentlyViewingOrder = (
      kind: _isCourier ? 'courier' : 'ride',
      orderId: _ride?.id,
      docId: widget.firestoreDocId,
    );
  }

  /// Resolves the Firestore doc for this order (by [firestoreDocId] or
  /// [ride_id] / [courier_id] query).
  Future<DocumentReference<Map<String, dynamic>>?>
  _getFirestoreOrderRef() async {
    final id = _ride?.id;
    if (id == null) return null;
    final collection =
        widget.firestoreCollection ??
        (_isCourier ? 'active_courier' : 'active_rides');
    if (widget.firestoreDocId != null && widget.firestoreDocId!.isNotEmpty) {
      return FirebaseFirestore.instance
          .collection(collection)
          .doc(widget.firestoreDocId);
    }
    final idField = _isCourier ? 'courier_id' : 'ride_id';
    final query = await FirebaseFirestore.instance
        .collection(collection)
        .where(idField, isEqualTo: id)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      return query.docs.first.reference;
    }
    return null;
  }

  Future<void> _markAcceptedInFirestore() async {
    final id = _ride?.id;
    if (id == null) return;
    final userId = await _storageService.getUserId();
    if (userId == null) return;

    try {
      final targetRef = await _getFirestoreOrderRef();
      if (targetRef == null) return;
      await targetRef.set({
        'accepted_by_user_id': userId,
        'accepted_at': FieldValue.serverTimestamp(),
        'accepted_service_type': _isCourier ? 'courier' : 'ride',
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint(
        '[FindingRideRequestsScreen][mark_accept_firestore] error: $e',
      );
    }
  }

  Future<bool> _markCompletedInFirestore() async {
    try {
      final targetRef = await _getFirestoreOrderRef();
      if (targetRef == null) {
        debugPrint(
          '[FindingRideRequestsScreen][mark_complete_firestore] no ref',
        );
        return false;
      }
      await targetRef.set({
        'mark_as_completed': true,
        'completion_status': 'completed',
        'completed_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint(
        '[FindingRideRequestsScreen][mark_complete_firestore] error: $e',
      );
      return false;
    }
  }

  Future<void> _onMarkCompletePressed() async {
    final id = _ride?.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          'mark_as_completed_question'.tr,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: AppConst.black,
          ),
        ),
        content: Text(
          _isCourier
              ? 'mark_courier_completed_question'.tr
              : 'mark_ride_completed_question'.tr,
          style: TextStyle(fontSize: 14.sp, color: AppConst.black),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'not_now'.tr,
              style: TextStyle(
                color: AppConst.blackWithOpacity(0.65),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'complete'.tr,
              style: TextStyle(
                color: AppConst.black,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _rideActionInProgress = true);
    try {
      Map<String, dynamic> response;
      if (_isCourier) {
        response = await _ridesRepository.completeCourierJob(courierId: id);
      } else {
        response = await _ridesRepository.completeRide(rideId: id);
      }
      _logApiStatus(
        action: _isCourier ? 'complete_courier' : 'complete_ride',
        response: response,
      );
      _driverLocationTimer?.cancel();
      _stopDriverLiveLocationUpdates();
      await _markCompletedInFirestore();
      if (!mounted) return;
      setState(() => _rideActionInProgress = false);
      Get.back();
      AppSnackbar.showSuccess(
        title: _isCourier ? 'courier_completed'.tr : 'ride_completed'.tr,
        message: _isCourier
            ? 'courier_job_marked_completed'.tr
            : 'ride_marked_completed'.tr,
        duration: const Duration(seconds: 2),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _rideActionInProgress = false);
      AppSnackbar.showError(
        title: 'complete_failed'.tr,
        message: 'could_not_complete_try_again'.tr,
      );
    }
  }

  Future<void> _onMarkCompleteFirestoreOnlyPressed() async {
    final id = _ride?.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          'mark_as_completed_question'.tr,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: AppConst.black,
          ),
        ),
        content: Text(
          _isCourier
              ? 'mark_courier_completed_question'.tr
              : 'mark_ride_completed_question'.tr,
          style: TextStyle(fontSize: 14.sp, color: AppConst.black),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'not_now'.tr,
              style: TextStyle(
                color: AppConst.blackWithOpacity(0.65),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'complete'.tr,
              style: TextStyle(
                color: AppConst.black,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _rideActionInProgress = true);
    _driverLocationTimer?.cancel();
    _stopDriverLiveLocationUpdates();
    final ok = await _markCompletedInFirestore();
    if (!mounted) return;
    setState(() => _rideActionInProgress = false);
    if (!ok) {
      AppSnackbar.showError(
        title: 'complete_failed'.tr,
        message: 'firestore_mark_complete_failed'.tr,
      );
      return;
    }
    Get.back();
    AppSnackbar.showSuccess(
      title: _isCourier ? 'courier_completed'.tr : 'ride_completed'.tr,
      message: 'order_marked_firestore_only'.tr,
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> _onAcceptRide() async {
    final id = _ride?.id;
    if (id == null) {
      AppSnackbar.show(title: 'accept'.tr, message: 'missing_request_id'.tr);
      return;
    }
    setState(() => _rideActionInProgress = true);
    try {
      Map<String, dynamic> response;
      if (_isCourier) {
        response = await _ridesRepository.acceptCourierJob(courierId: id);
      } else {
        response = await _ridesRepository.acceptDriverRide(rideId: id);
      }
      _logApiStatus(
        action: _isCourier ? 'accept_courier' : 'accept_ride',
        response: response,
      );
      if (!mounted) return;
      setState(() {
        _rideActionInProgress = false;
        _acceptedThisSession = true;
      });
      await _markAcceptedInFirestore();
      await _ensureDriverLiveLocationTracking();
      await _fetchOrderDetailsIfNeeded();
      AppSnackbar.showSuccess(
        title: _isCourier ? 'courier_accepted'.tr : 'ride_accepted'.tr,
        message: 'you_can_cancel_from_here'.tr,
        duration: const Duration(seconds: 2),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _rideActionInProgress = false);
      AppSnackbar.showError(
        title: 'accept_failed'.tr,
        message: _isCourier
            ? 'could_not_accept_courier_try_again'.tr
            : 'could_not_accept_ride_try_again'.tr,
      );
    }
  }

  Future<void> _onCancelRide() async {
    final id = _ride?.id;
    if (id == null) {
      Get.back();
      return;
    }
    setState(() => _rideActionInProgress = true);
    try {
      Map<String, dynamic> response;
      if (_isCourier) {
        response = await _ridesRepository.cancelCourierJob(courierId: id);
      } else {
        response = await _ridesRepository.cancelRide(rideId: id);
      }
      _logApiStatus(
        action: _isCourier ? 'cancel_courier' : 'cancel_ride',
        response: response,
      );
      if (!mounted) return;
      setState(() => _rideActionInProgress = false);
      _stopDriverLiveLocationUpdates();
      Get.back();
    } catch (_) {
      if (!mounted) return;
      setState(() => _rideActionInProgress = false);
      AppSnackbar.showError(
        title: 'cancel_failed'.tr,
        message: 'could_not_cancel_try_again'.tr,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _rideData = widget.ride;
    _syncViewingOrderMarker();
    debugPrint(
      '[FindingRideRequestsScreen] initial incoming ride.status=${_ride?.status}',
    );
    final awaitsRoute = _pickupLatLng != null && _dropLatLng != null;
    _routeLoading = awaitsRoute;
    _populateMapOverlays(awaitDirections: awaitsRoute);
    _initDriverMarkerIcon();
    _loadDrivingRoute();
    _loadDriverLocationFromFirestoreIfAny();
    _fetchOrderDetailsIfNeeded();
    _ensureDriverLiveLocationTracking();
  }

  @override
  void dispose() {
    _stopDriverLiveLocationUpdates();
    final current = FindingRideRequestsScreen.currentlyViewingOrder;
    if (current?.orderId == _ride?.id &&
        current?.docId == widget.firestoreDocId &&
        current?.kind == (_isCourier ? 'courier' : 'ride')) {
      FindingRideRequestsScreen.currentlyViewingOrder = null;
    }
    super.dispose();
  }

  Widget _detailChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppConst.blackWithOpacity(0.07),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: AppConst.blackWithOpacity(0.75)),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: AppConst.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map — pickup, destination, route polyline
          Positioned.fill(
            child: _pickupLatLng == null && _dropLatLng == null
                ? ColoredBox(
                    color: Colors.grey[300]!,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map_outlined,
                            size: 64.sp,
                            color: AppConst.blackWithOpacity(0.35),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'no_coordinates_for_request'.tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppConst.blackWithOpacity(0.5),
                              fontSize: 14.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      GoogleMap(
                        initialCameraPosition: _initialCamera,
                        markers: _markers,
                        polylines: _polylines,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        compassEnabled: false,
                        padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top + 72.h,
                          bottom: MediaQuery.of(context).size.height * 0.42,
                        ),
                        onMapCreated: (controller) {
                          _mapController = controller;
                          _fitCameraToRoute();
                        },
                        gestureRecognizers:
                            <Factory<OneSequenceGestureRecognizer>>{
                              Factory<EagerGestureRecognizer>(
                                EagerGestureRecognizer.new,
                              ),
                            },
                      ),
                      if (_routeLoading)
                        Positioned(
                          left: 24.w,
                          right: 24.w,
                          top: MediaQuery.of(context).padding.top + 88.h,
                          child: Material(
                            elevation: 6,
                            borderRadius: BorderRadius.circular(16.r),
                            color: AppConst.white,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 18.w,
                                vertical: 14.h,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 22.w,
                                    height: 22.w,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppConst.black,
                                    ),
                                  ),
                                  SizedBox(width: 14.w),
                                  Text(
                                    'finding_route'.tr,
                                    style: TextStyle(
                                      color: AppConst.black,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          // Top Header - Black
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppConst.brandedHeader,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20.r),
                  bottomRight: Radius.circular(20.r),
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 0.h),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: AppConst.brandedHeaderForeground,
                          size: 24.sp,
                        ),
                        onPressed: () => Get.back(),
                      ),
                    ),
                    Text(
                      _isCourier
                          ? 'courier_request'.tr
                          : 'finding_ride_requests'.tr,
                      style: TextStyle(
                        color: AppConst.brandedHeaderForeground,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.settings,
                        color: AppConst.brandedHeaderForeground,
                        size: 24.sp,
                      ),
                      onPressed: () {
                        Get.to(() => const SettingScreen());
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          // if (_pickupLatLng != null || _dropLatLng != null)
          //   // Fit pickup + destination in view (only when map is shown)
          //   Positioned(
          //     right: 20.w,
          //     bottom: MediaQuery.of(context).size.height * 0.46,
          //     child: Material(
          //       color: AppConst.black,
          //       borderRadius: BorderRadius.circular(8.r),
          //       child: InkWell(
          //         onTap: _fitCameraToRoute,
          //         borderRadius: BorderRadius.circular(8.r),
          //         child: SizedBox(
          //           width: 48.w,
          //           height: 48.w,
          //           child: Icon(
          //             Icons.fit_screen,
          //             color: AppConst.white,
          //             size: 22.sp,
          //           ),
          //         ),
          //       ),
          //     ),
          //   ),
          // Draggable Bottom Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.25,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: AppConst.primaryColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20.r),
                    topRight: Radius.circular(20.r),
                  ),
                ),
                child: Column(
                  children: [
                    // Drag Handle
                    Container(
                      margin: EdgeInsets.only(top: 12.h),
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: AppConst.white,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                    // Scrollable Content
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 20.h,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Ride Request Details Card
                            Container(
                              padding: EdgeInsets.all(20.w),
                              decoration: BoxDecoration(
                                color: AppConst.white,
                                borderRadius: AppConst.borderRadius,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppConst.blackWithOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Request / passenger line
                                  Text(
                                    _passengerLine,
                                    style: TextStyle(
                                      color: AppConst.black,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                  // Pickup Location
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: AppConst.black,
                                        size: 20.sp,
                                      ),
                                      SizedBox(width: 8.w),
                                      Expanded(
                                        child: Text(
                                          _pickupLine,
                                          style: TextStyle(
                                            color: AppConst.black,
                                            fontSize: 14.sp,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8.h),
                                  // Drop Location
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: AppConst.black,
                                        size: 20.sp,
                                      ),
                                      SizedBox(width: 8.w),
                                      Expanded(
                                        child: Text(
                                          _dropLine,
                                          style: TextStyle(
                                            color: AppConst.black,
                                            fontSize: 14.sp,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8.h),
                                  // Fare / ETA placeholder
                                  Row(
                                    children: [
                                      Icon(
                                        _ride != null
                                            ? Icons.payments_outlined
                                            : Icons.access_time,
                                        color: AppConst.black,
                                        size: 20.sp,
                                      ),
                                      SizedBox(width: 8.w),
                                      Expanded(
                                        child: Text(
                                          _fareLine,
                                          style: TextStyle(
                                            color: AppConst.black,
                                            fontSize: 14.sp,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_ride != null) ...[
                                    SizedBox(height: 12.h),
                                    Builder(
                                      builder: (context) {
                                        final ride = _ride!;
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              spacing: 8.w,
                                              runSpacing: 6.h,
                                              children: [
                                                // if ((ride.status ?? '')
                                                //     .isNotEmpty)
                                                //   _detailChip(
                                                //     Icons.flag_outlined,
                                                //     'Status ${ride.status}',
                                                //   ),
                                                if ((ride.paymentStatus ?? '')
                                                    .isNotEmpty)
                                                  _detailChip(
                                                    Icons.receipt_long_outlined,
                                                    '${'payment'.tr} ${ride.paymentStatus}',
                                                  ),
                                              ],
                                            ),
                                            if ((ride.pickupInstructions ?? '')
                                                    .isNotEmpty ||
                                                (ride.dropoffInstructions ?? '')
                                                    .isNotEmpty) ...[
                                              SizedBox(height: 10.h),
                                              if ((ride.pickupInstructions ??
                                                      '')
                                                  .isNotEmpty)
                                                Text(
                                                  '${'pickup_note'.tr}: ${ride.pickupInstructions}',
                                                  style: TextStyle(
                                                    color:
                                                        AppConst.blackWithOpacity(
                                                          0.7,
                                                        ),
                                                    fontSize: 12.sp,
                                                  ),
                                                ),
                                              if ((ride.dropoffInstructions ??
                                                      '')
                                                  .isNotEmpty) ...[
                                                SizedBox(height: 4.h),
                                                Text(
                                                  '${'dropoff_note'.tr}: ${ride.dropoffInstructions}',
                                                  style: TextStyle(
                                                    color:
                                                        AppConst.blackWithOpacity(
                                                          0.7,
                                                        ),
                                                    fontSize: 12.sp,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            SizedBox(height: 20.h),
                            if (_showAcceptButton)
                              SizedBox(
                                width: double.infinity,
                                height: 50.h,
                                child: ElevatedButton(
                                  onPressed: _rideActionInProgress
                                      ? null
                                      : _onAcceptRide,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppConst.black,
                                    disabledBackgroundColor:
                                        AppConst.blackWithOpacity(0.4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                  ),
                                  child: _rideActionInProgress
                                      ? SizedBox(
                                          width: 22.w,
                                          height: 22.w,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppConst.white,
                                          ),
                                        )
                                      : Text(
                                          'accept'.tr,
                                          style: TextStyle(
                                            color: AppConst.white,
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              )
                            else if (_showMarkCompleteButton)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50.h,
                                    child: ElevatedButton(
                                      onPressed: _rideActionInProgress
                                          ? null
                                          : _onMarkCompletePressed,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppConst.black,
                                        disabledBackgroundColor:
                                            AppConst.blackWithOpacity(0.4),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12.r,
                                          ),
                                        ),
                                      ),
                                      child: _rideActionInProgress
                                          ? SizedBox(
                                              width: 22.w,
                                              height: 22.w,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppConst.white,
                                              ),
                                            )
                                          : Text(
                                              'mark_as_completed'.tr,
                                              style: TextStyle(
                                                color: AppConst.white,
                                                fontSize: 16.sp,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                    ),
                                  ),
                                  // if (kShowFirestoreOnlyCompleteButton) ...[
                                  //   SizedBox(height: 12.h),
                                  //   SizedBox(
                                  //     width: double.infinity,
                                  //     height: 50.h,
                                  //     child: OutlinedButton(
                                  //       onPressed: _rideActionInProgress
                                  //           ? null
                                  //           : _onMarkCompleteFirestoreOnlyPressed,
                                  //       style: OutlinedButton.styleFrom(
                                  //         side: const BorderSide(
                                  //           color: Colors.deepOrange,
                                  //           width: 1.5,
                                  //         ),
                                  //         shape: RoundedRectangleBorder(
                                  //           borderRadius: BorderRadius.circular(
                                  //             12.r,
                                  //           ),
                                  //         ),
                                  //       ),
                                  //       child: Text(
                                  //         'mark_as_completed_firestore_only'.tr,
                                  //         textAlign: TextAlign.center,
                                  //         style: TextStyle(
                                  //           color: Colors.deepOrange.shade800,
                                  //           fontSize: 14.sp,
                                  //           fontWeight: FontWeight.w600,
                                  //         ),
                                  //       ),
                                  //     ),
                                  //   ),
                                  // ],
                                  SizedBox(height: 12.h),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50.h,
                                    child: ElevatedButton(
                                      onPressed: _rideActionInProgress
                                          ? null
                                          : _onCancelRide,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppConst.grey,
                                        disabledBackgroundColor: AppConst.grey
                                            .withValues(alpha: 0.5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12.r,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'cancel'.tr,
                                        style: TextStyle(
                                          color: AppConst.white,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              SizedBox(
                                width: double.infinity,
                                height: 50.h,
                                child: ElevatedButton(
                                  onPressed: _rideActionInProgress
                                      ? null
                                      : _onCancelRide,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppConst.grey,
                                    disabledBackgroundColor: AppConst.grey
                                        .withValues(alpha: 0.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                  ),
                                  child: _rideActionInProgress
                                      ? SizedBox(
                                          width: 22.w,
                                          height: 22.w,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppConst.white,
                                          ),
                                        )
                                      : Text(
                                          'cancel'.tr,
                                          style: TextStyle(
                                            color: AppConst.white,
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            SizedBox(height: 12.h),
                            if (_ride == null)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 12.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppConst.white,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'go_to_high_demand_area'.tr,
                                        style: TextStyle(
                                          color: AppConst.black,
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.send,
                                      color: AppConst.black,
                                      size: 20.sp,
                                    ),
                                  ],
                                ),
                              ),
                            if (_ride == null) SizedBox(height: 20.h),
                            if (_ride != null) SizedBox(height: 8.h),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
