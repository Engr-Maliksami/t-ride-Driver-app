import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:t_rider_services_app/consts/appConst.dart';
import 'package:t_rider_services_app/config/home_map_styles.dart';
import 'package:t_rider_services_app/data/local/secure_storage_service.dart';
import 'package:t_rider_services_app/data/directions/google_directions_service.dart';
import 'package:t_rider_services_app/data/models/order_active_status_model.dart';
import 'package:t_rider_services_app/data/repositories/rides_repository.dart';
import 'package:t_rider_services_app/utils/driver_location_marker_bitmap.dart';
import 'package:t_rider_services_app/utils/order_route_markers_bitmap.dart';
import 'package:t_rider_services_app/views/home/setting/setting_screen.dart';
import 'package:t_rider_services_app/views/home/widgets/order_trip_timeline.dart';
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
  double _driverHeadingDeg = 0;

  DrivingRouteSummary? _pickupDropRouteSummary;

  BitmapDescriptor? _pickupRouteIcon;
  BitmapDescriptor? _dropRouteIcon;
  BitmapDescriptor? _driverMarkerIcon;

  /// True while requesting driving directions (no placeholder straight line yet).
  bool _routeLoading = false;
  bool _driverLocationSyncing = false;
  Timer? _driverLocationTimer;

  /// After a successful accept API call; switches primary action from Accept → Cancel.
  bool _acceptedThisSession = false;

  /// Shown until [ActiveRideCourierOrder.acceptedAt] or Firestore `accepted_at` is available.
  DateTime? _acceptedAtFallback;
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

  String? get _mapStyleJson => AppConst.isDarkMode
      ? HomeMapStyles.darkUberLike
      : HomeMapStyles.lightUberLike;

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
          icon:
              _pickupRouteIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 2,
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
          icon:
              _dropRouteIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 2,
          infoWindow: InfoWindow(
            title: 'destination'.tr,
            snippet: _shortSnippet(r?.dropoffAddress),
          ),
        ),
      );
    }
    final driver = _driverLatLng;
    if (driver != null && _driverMarkerIcon != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: driver,
          icon: _driverMarkerIcon!,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          rotation: _driverHeadingDeg,
          zIndexInt: 3,
          infoWindow: InfoWindow(title: 'driver'.tr),
        ),
      );
    }
    if (pickup != null && drop != null && !awaitDirections) {
      _setPrimaryRoutePolylinePoints([pickup, drop], geodesic: true);
    }
  }

  Future<void> _loadUberStyleMarkerBitmaps() async {
    try {
      final p = await pickupRouteMarkerBitmap();
      final d = await destinationRouteMarkerBitmap();
      final drv = await buildDriverLocationMarkerBitmap(
        darkVariant: AppConst.isDarkMode,
      );
      if (!mounted) return;
      setState(() {
        _pickupRouteIcon = p;
        _dropRouteIcon = d;
        _driverMarkerIcon = drv;
      });
      _populateMapOverlays(
        awaitDirections:
            _routeLoading && _pickupLatLng != null && _dropLatLng != null,
      );
      _refreshDriverMarker();
    } catch (_) {}
  }

  void _refreshDriverMarker() {
    final driver = _driverLatLng;
    final icon = _driverMarkerIcon;
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'driver');
      if (driver != null && icon != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('driver'),
            position: driver,
            icon: icon,
            anchor: const Offset(0.5, 0.5),
            flat: true,
            rotation: _driverHeadingDeg,
            zIndexInt: 3,
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
        color: kOrderRoutePurple,
        width: 8,
        geodesic: geodesic,
        jointType: JointType.round,
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

    final summary = await GoogleDirectionsService.fetchDrivingRoute(
      origin: pickup,
      destination: drop,
    );

    if (!mounted) return;

    if (summary != null && summary.points.length >= 2) {
      setState(() {
        _routeLoading = false;
        _drivingPolylinePoints = summary.points;
        _pickupDropRouteSummary = summary;
        _setPrimaryRoutePolylinePoints(summary.points, geodesic: false);
      });
      await _fitCameraToRoute();
    } else {
      setState(() {
        _routeLoading = false;
        _drivingPolylinePoints = null;
        _pickupDropRouteSummary = null;
        _setPrimaryRoutePolylinePoints([pickup, drop], geodesic: true);
      });
      await _fitCameraToRoute();
    }
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
      final h = position.heading;
      if (h >= 0 && h <= 360) {
        _driverHeadingDeg = h.toDouble();
      }
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

  String get _pickupAddressPlain {
    final a = _ride?.pickupAddress?.trim();
    if (a != null && a.isNotEmpty) return a;
    return '—';
  }

  String get _dropAddressPlain {
    final a = _ride?.dropoffAddress?.trim();
    if (a != null && a.isNotEmpty) return a;
    return '—';
  }

  String get _scheduleDisplayLine {
    final accepted = _acceptedThisSession || (_ride?.driverId != null);
    if (!accepted) {
      return 'map_order_schedule_unknown'.tr;
    }
    final at = _ride?.acceptedAt ?? _acceptedAtFallback;
    if (at != null) {
      final localeTag = Get.locale?.toLanguageTag() ?? 'en_US';
      final fmt = DateFormat('EEE, MMM d · h:mm a', localeTag).format(at);
      return 'order_accepted_at_line'.tr.replaceAll('@time', fmt);
    }
    return 'order_accepted_time_pending'.tr;
  }

  Future<void> _refreshAcceptedAtFromFirestore() async {
    try {
      final ref = await _getFirestoreOrderRef();
      if (ref == null || !mounted) return;
      final snap = await ref.get();
      final data = snap.data();
      if (data == null || !mounted) return;
      final v = data['accepted_at'];
      DateTime? dt;
      if (v is Timestamp) {
        dt = v.toDate().toLocal();
      } else if (v is String) {
        dt = DateTime.tryParse(v)?.toLocal();
      } else if (v is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(v, isUtc: true).toLocal();
      } else if (v is num) {
        dt = DateTime.fromMillisecondsSinceEpoch(
          v.round(),
          isUtc: true,
        ).toLocal();
      }
      if (dt != null && mounted) {
        setState(() => _acceptedAtFallback = dt);
      }
    } catch (e) {
      debugPrint('[FindingRideRequestsScreen][accepted_at] error: $e');
    }
  }

  String _formatDurationForTripStats(Duration d) {
    if (d.inHours >= 1) {
      final m = d.inMinutes.remainder(60);
      if (m <= 0) return '${d.inHours} hr';
      return '${d.inHours} hr $m min';
    }
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    return '${d.inMinutes} min';
  }

  String get _tripStatsDisplayLine {
    final s = _pickupDropRouteSummary;
    if (s == null) return 'map_order_route_fallback'.tr;
    final durStr = _formatDurationForTripStats(s.duration);
    final mi = s.distanceMeters / 1609.344;
    return '$durStr · ${mi.toStringAsFixed(1)} mi';
  }

  String get _formattedFareLarge {
    final f = _ride?.fare?.trim();
    if (f == null || f.isEmpty) return '—';
    if (f.startsWith(r'$')) return f;
    final n = double.tryParse(f.replaceAll(',', ''));
    if (n != null) return '\$${n.toStringAsFixed(2)}';
    return '\$$f';
  }

  String get _riderDisplayLabel {
    final n = _ride?.receiverName?.trim();
    if (n != null && n.isNotEmpty) {
      final parts = n.split(RegExp(r'\s+'));
      return parts.first;
    }
    final id = _ride?.rideCustomId?.trim();
    if (id != null && id.isNotEmpty) return '${'request'.tr} $id';
    return 'passenger'.tr;
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
        final merged = ActiveRideCourierOrder.fromJson(dataMap);
        setState(() {
          _rideData = merged;
          if (merged.acceptedAt != null) {
            _acceptedAtFallback = null;
          }
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
        _acceptedAtFallback = DateTime.now();
      });
      await _markAcceptedInFirestore();
      await _refreshAcceptedAtFromFirestore();
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
    unawaited(_loadUberStyleMarkerBitmaps());
    _loadDrivingRoute();
    _loadDriverLocationFromFirestoreIfAny();
    _fetchOrderDetailsIfNeeded();
    _ensureDriverLiveLocationTracking();
    if (_ride?.driverId != null && _ride?.acceptedAt == null) {
      unawaited(_refreshAcceptedAtFromFirestore());
    }
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
                        style: _mapStyleJson,
                        markers: _markers,
                        polylines: _polylines,
                        myLocationEnabled: false,
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
              return Material(
                color: Colors.white,
                elevation: 16,
                shadowColor: Colors.black.withValues(alpha: 0.16),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: 10.h),
                      width: 42.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(22.w, 16.h, 22.w, 20.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Text(
                                    _formattedFareLarge,
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 31.sp,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.9,
                                      height: 1.05,
                                    ),
                                  ),
                                ),
                                if (_ride?.paymentMethod != null &&
                                    _ride!.paymentMethod!.trim().isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(bottom: 4.h),
                                    child: Text(
                                      _ride!.paymentMethod!.trim(),
                                      style: TextStyle(
                                        color: Colors.black.withValues(
                                          alpha: 0.55,
                                        ),
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Divider(
                              height: 28.h,
                              thickness: 1,
                              color: Colors.black.withValues(alpha: 0.07),
                            ),
                            OrderTripTimelineRows(
                              pickupTimeLine: _scheduleDisplayLine,
                              pickupAddress: _pickupAddressPlain,
                              tripStatsLine: _tripStatsDisplayLine,
                              destinationTitle: _dropAddressPlain.isEmpty
                                  ? 'map_order_destination_fallback'.tr
                                  : _dropAddressPlain,
                            ),
                            Divider(
                              height: 28.h,
                              thickness: 1,
                              color: Colors.black.withValues(alpha: 0.07),
                            ),
                            Text(
                              _riderDisplayLabel,
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            // Row(
                            //   children: [
                            //     Icon(
                            //       Icons.star_rounded,
                            //       color: Colors.black87,
                            //       size: 19.sp,
                            //     ),
                            //     SizedBox(width: 4.w),
                            //     Text(
                            //       'map_order_rating_unknown'.tr,
                            //       style: TextStyle(
                            //         color: Colors.black87,
                            //         fontSize: 15.sp,
                            //         fontWeight: FontWeight.w600,
                            //       ),
                            //     ),
                            //   ],
                            // ),
                            if (_ride != null) ...[
                              Builder(
                                builder: (context) {
                                  final ride = _ride!;
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if ((ride.paymentStatus ?? '')
                                          .isNotEmpty) ...[
                                        SizedBox(height: 14.h),
                                        Wrap(
                                          spacing: 8.w,
                                          runSpacing: 6.h,
                                          children: [
                                            _detailChip(
                                              Icons.receipt_long_outlined,
                                              '${'payment'.tr} ${ride.paymentStatus}',
                                            ),
                                          ],
                                        ),
                                      ],
                                      if ((ride.pickupInstructions ?? '')
                                              .isNotEmpty ||
                                          (ride.dropoffInstructions ?? '')
                                              .isNotEmpty) ...[
                                        SizedBox(height: 12.h),
                                        if ((ride.pickupInstructions ?? '')
                                            .isNotEmpty)
                                          Text(
                                            '${'pickup_note'.tr}: ${ride.pickupInstructions}',
                                            style: TextStyle(
                                              color: AppConst.blackWithOpacity(
                                                0.7,
                                              ),
                                              fontSize: 12.sp,
                                            ),
                                          ),
                                        if ((ride.dropoffInstructions ?? '')
                                            .isNotEmpty) ...[
                                          SizedBox(height: 4.h),
                                          Text(
                                            '${'dropoff_note'.tr}: ${ride.dropoffInstructions}',
                                            style: TextStyle(
                                              color: AppConst.blackWithOpacity(
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
                            SizedBox(height: 22.h),
                            if (_showAcceptButton)
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 14.h,
                                        ),
                                        side: BorderSide(
                                          color: Colors.black.withValues(
                                            alpha: 0.12,
                                          ),
                                        ),
                                        foregroundColor: Colors.black87,
                                      ),
                                      onPressed: _rideActionInProgress
                                          ? null
                                          : () => Get.back<void>(),
                                      child: Text('cancel'.tr),
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: FilledButton(
                                      style: FilledButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 14.h,
                                        ),
                                        backgroundColor: kOrderRoutePurple,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: _rideActionInProgress
                                          ? null
                                          : _onAcceptRide,
                                      child: _rideActionInProgress
                                          ? SizedBox(
                                              width: 22.w,
                                              height: 22.w,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text('accept'.tr),
                                    ),
                                  ),
                                ],
                              )
                            else if (_showMarkCompleteButton)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50.h,
                                    child: FilledButton(
                                      onPressed: _rideActionInProgress
                                          ? null
                                          : _onMarkCompletePressed,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: kOrderRoutePurple,
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor:
                                            kOrderRoutePurple.withValues(
                                              alpha: 0.45,
                                            ),
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
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              'mark_as_completed'.tr,
                                              style: TextStyle(
                                                color: Colors.white,
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
                                    child: OutlinedButton(
                                      onPressed: _rideActionInProgress
                                          ? null
                                          : _onCancelRide,
                                      style: OutlinedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 14.h,
                                        ),
                                        side: BorderSide(
                                          color: Colors.black.withValues(
                                            alpha: 0.12,
                                          ),
                                        ),
                                        foregroundColor: Colors.black87,
                                      ),
                                      child: Text(
                                        'cancel'.tr,
                                        style: TextStyle(
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
                                child: OutlinedButton(
                                  onPressed: _rideActionInProgress
                                      ? null
                                      : _onCancelRide,
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 14.h,
                                    ),
                                    side: BorderSide(
                                      color: Colors.black.withValues(
                                        alpha: 0.12,
                                      ),
                                    ),
                                    foregroundColor: Colors.black87,
                                  ),
                                  child: _rideActionInProgress
                                      ? SizedBox(
                                          width: 22.w,
                                          height: 22.w,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppConst.black,
                                          ),
                                        )
                                      : Text(
                                          'cancel'.tr,
                                          style: TextStyle(
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
