import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:t_rider_services_app/controllers/app_theme_controller.dart';
import 'package:t_rider_services_app/controllers/driver_map_location_controller.dart';
import 'package:t_rider_services_app/controllers/firestore_active_orders_listener.dart';
import 'package:t_rider_services_app/consts/appConst.dart';
import 'package:t_rider_services_app/config/home_map_styles.dart';
import 'package:t_rider_services_app/data/directions/google_directions_service.dart';
import 'package:t_rider_services_app/data/firestore/firestore_active_order_mapper.dart';
import 'package:t_rider_services_app/models/nearby_order_map_offer.dart';
import 'package:t_rider_services_app/utils/driver_location_marker_bitmap.dart';
import 'package:t_rider_services_app/utils/order_route_markers_bitmap.dart';
import 'package:t_rider_services_app/views/home/finding_ride_requests_screen.dart';
import 'package:t_rider_services_app/views/home/widgets/nearby_order_offer_sheet.dart';

/// Full-screen dashboard map — live puck, routed offers from Firestore-only UI.
class FullScreenDashboardMapScreen extends StatefulWidget {
  const FullScreenDashboardMapScreen({
    super.key,
    this.seedLatLng,
    this.seedHeading,
    this.seedMapType,
  });

  final LatLng? seedLatLng;
  final double? seedHeading;
  final MapType? seedMapType;

  static const LatLng defaultCenter = LatLng(6.5244, 3.3792);

  @override
  State<FullScreenDashboardMapScreen> createState() =>
      _FullScreenDashboardMapScreenState();
}

class _FullScreenDashboardMapScreenState
    extends State<FullScreenDashboardMapScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  Worker? _mapThemeWorker;
  Worker? _driverLatLngWorker;
  Worker? _driverHeadingWorker;
  Worker? _driverPermissionWorker;
  Worker? _firestoreOfferWorker;

  late AnimationController _sheetReveal;
  late Animation<Offset> _sheetSlide;

  LatLng? _userLatLng;
  double _userHeading = 0;
  MapType _mapType = MapType.normal;
  BitmapDescriptor? _driverLocationIcon;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropoffIcon;

  NearbyOrderMapOffer? _activeOffer;
  DrivingRouteSummary? _activeRoute;
  List<LatLng> _routePoints = const [];

  PolylineId get _polyId => const PolylineId('order_route_preview');

  bool get _isDarkMode => AppConst.isDarkMode;

  LatLng get _mapTarget =>
      _userLatLng ?? FullScreenDashboardMapScreen.defaultCenter;

  String? get _mapStyleJson {
    final styled = _mapType != MapType.satellite && _mapType != MapType.hybrid;
    if (!styled) return null;
    return AppConst.isDarkMode
        ? HomeMapStyles.darkUberLike
        : HomeMapStyles.lightUberLike;
  }

  Set<Polyline> get _polylines {
    if (_routePoints.length >= 2) {
      return {
        Polyline(
          polylineId: _polyId,
          points: _routePoints,
          color: kOrderRoutePurple,
          width: 8,
          geodesic: true,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      };
    }
    return {};
  }

  Set<Marker> _markers() {
    final out = <Marker>{};
    if (_userLatLng != null && _driverLocationIcon != null) {
      out.add(
        Marker(
          markerId: const MarkerId('driver_location'),
          position: _userLatLng!,
          icon: _driverLocationIcon!,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          rotation: _userHeading,
          zIndexInt: 3,
        ),
      );
    }
    final offer = _activeOffer;
    if (offer != null && _pickupIcon != null && _dropoffIcon != null) {
      final picked = FirestoreActiveOrderMapper.pickupCoordinates(offer.raw);
      final dropped = FirestoreActiveOrderMapper.dropoffCoordinates(offer.raw);
      if (picked != null) {
        out.add(
          Marker(
            markerId: const MarkerId('order_pickup'),
            position: LatLng(picked.lat, picked.lng),
            icon: _pickupIcon!,
            anchor: const Offset(0.5, 0.5),
            zIndexInt: 2,
          ),
        );
      }
      if (dropped != null) {
        out.add(
          Marker(
            markerId: const MarkerId('order_dropoff'),
            position: LatLng(dropped.lat, dropped.lng),
            icon: _dropoffIcon!,
            anchor: const Offset(0.5, 0.5),
            zIndexInt: 2,
          ),
        );
      }
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _sheetReveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _sheetSlide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _sheetReveal, curve: Curves.fastOutSlowIn),
        );

    _userLatLng = widget.seedLatLng;
    final h = widget.seedHeading;
    if (h != null && h >= 0 && h <= 360) _userHeading = h;
    if (widget.seedMapType != null) _mapType = widget.seedMapType!;
    if (Get.isRegistered<AppThemeController>()) {
      _mapThemeWorker = ever(Get.find<AppThemeController>().themeMode, (
        _,
      ) async {
        if (!mounted) return;
        setState(() {});
        await _refreshDriverIcon();
      });
    }
    unawaited(_ensureRouteGlyphs());
    unawaited(_refreshDriverIcon());
    _bindDriverLocationStream();
    _bindFirestoreOffer();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _pullFirestoreOffersForMap();
    });
  }

  Future<void> _ensureRouteGlyphs() async {
    if (_pickupIcon != null && _dropoffIcon != null) return;
    try {
      final p = await pickupRouteMarkerBitmap();
      final d = await destinationRouteMarkerBitmap();
      if (!mounted) return;
      setState(() {
        _pickupIcon ??= p;
        _dropoffIcon ??= d;
      });
    } catch (_) {}
  }

  void _bindFirestoreOffer() {
    if (!Get.isRegistered<FirestoreActiveOrdersListener>()) return;
    final fs = Get.find<FirestoreActiveOrdersListener>();
    void onChange() =>
        unawaited(_syncOfferFromFirestore(fs.foregroundMapOffer.value));
    _firestoreOfferWorker = ever(fs.foregroundMapOffer, (_) => onChange());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncOfferFromFirestore(fs.foregroundMapOffer.value));
    });
  }

  /// Reconciles queued Firestore rides (stream can miss coords / GPS mismatches until map opens).
  Future<void> _pullFirestoreOffersForMap() async {
    if (!Get.isRegistered<FirestoreActiveOrdersListener>()) return;
    final fs = Get.find<FirestoreActiveOrdersListener>();
    await fs.syncPendingNearbyOffers();
    if (!mounted) return;
    await _syncOfferFromFirestore(fs.foregroundMapOffer.value);
  }

  Future<void> _syncOfferFromFirestore(NearbyOrderMapOffer? offer) async {
    if (!mounted) return;
    if (offer == null) {
      await _teardownOfferPresentation();
      return;
    }
    if (_activeOffer?.docKey == offer.docKey &&
        _routePoints.length >= 2 &&
        _sheetReveal.status == AnimationStatus.completed) {
      return;
    }

    await _ensureRouteGlyphs();
    final pu = FirestoreActiveOrderMapper.pickupCoordinates(offer.raw);
    final du = FirestoreActiveOrderMapper.dropoffCoordinates(offer.raw);
    if (pu == null || du == null) {
      if (mounted) {
        setState(() {
          _activeOffer = offer;
          _routePoints = [];
          _activeRoute = null;
        });
      }
      unawaited(_sheetReveal.forward());
      return;
    }

    final origin = LatLng(pu.lat, pu.lng);
    final dest = LatLng(du.lat, du.lng);

    DrivingRouteSummary? route =
        await GoogleDirectionsService.fetchDrivingRoute(
          origin: origin,
          destination: dest,
        );

    List<LatLng> pts;
    DrivingRouteSummary? effectiveRoute = route;
    if (route == null || route.points.length < 2) {
      pts = [origin, dest];
      effectiveRoute = null;
    } else {
      pts = route.points;
    }

    if (!mounted) return;
    setState(() {
      _activeOffer = offer;
      _routePoints = pts;
      _activeRoute = effectiveRoute;
    });
    await _sheetReveal.forward();
    unawaited(_fitCameraToRoute());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_fitCameraToRoute());
    });
  }

  Future<void> _teardownOfferPresentation() async {
    if (_sheetReveal.status == AnimationStatus.dismissed ||
        _sheetReveal.value == 0) {
      _applyTeardownClear();
      return;
    }
    await _sheetReveal.reverse();
    if (!mounted) return;
    _applyTeardownClear();
  }

  void _applyTeardownClear() {
    setState(() {
      _activeOffer = null;
      _routePoints = [];
      _activeRoute = null;
    });
  }

  LatLngBounds? _boundsForPoints(Iterable<LatLng> pts) {
    double? minLat, maxLat, minLng, maxLng;
    for (final p in pts) {
      minLat = minLat == null
          ? p.latitude
          : (p.latitude < minLat ? p.latitude : minLat);
      maxLat = maxLat == null
          ? p.latitude
          : (p.latitude > maxLat ? p.latitude : maxLat);
      minLng = minLng == null
          ? p.longitude
          : (p.longitude < minLng ? p.longitude : minLng);
      maxLng = maxLng == null
          ? p.longitude
          : (p.longitude > maxLng ? p.longitude : maxLng);
    }
    if (minLat == null || maxLat == null || minLng == null || maxLng == null) {
      return null;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Future<void> _fitCameraToRoute() async {
    final ctrl = _mapController;
    if (ctrl == null || _routePoints.length < 2) return;

    final all = [..._routePoints];
    if (_userLatLng != null) all.add(_userLatLng!);
    final b = _boundsForPoints(all);
    if (b == null) return;

    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    try {
      await ctrl.animateCamera(CameraUpdate.newLatLngBounds(b, 64));
    } catch (_) {}
  }

  void _bindDriverLocationStream() {
    final loc = DriverMapLocationController.ensure();
    void sync() => _syncFromDriverLocationController(loc);

    _driverLatLngWorker = ever(loc.currentLatLng, (_) => sync());
    _driverHeadingWorker = ever(loc.headingDeg, (_) => sync());
    _driverPermissionWorker = ever(loc.permissionIssueKey, (_) => sync());

    WidgetsBinding.instance.addPostFrameCallback((_) => sync());
  }

  void _syncFromDriverLocationController(DriverMapLocationController loc) {
    if (!mounted) return;
    final issue = loc.permissionIssueKey.value?.trim();
    if (issue != null && issue.isNotEmpty) {
      return;
    }
    final latLng = loc.currentLatLng.value;
    if (latLng == null) return;
    setState(() {
      _userLatLng = latLng;
      _userHeading = loc.headingDeg.value;
    });
  }

  Future<void> _refreshDriverIcon() async {
    try {
      _driverLocationIcon = await buildDriverLocationMarkerBitmap(
        darkVariant: AppConst.isDarkMode,
      );
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _setMapType(MapType type) => setState(() => _mapType = type);

  Future<void> _onMapCreated(GoogleMapController c) async {
    _mapController = c;
    await _refreshDriverIcon();
    if (!mounted) return;
    setState(() {});
    if (_routePoints.length >= 2) {
      await _fitCameraToRoute();
    } else if (_userLatLng != null) {
      await c.animateCamera(CameraUpdate.newLatLngZoom(_userLatLng!, 14));
    }
  }

  void _onDismissSheet() {
    if (Get.isRegistered<FirestoreActiveOrdersListener>()) {
      Get.find<FirestoreActiveOrdersListener>().dismissCurrentForegroundOffer();
    } else {
      unawaited(_teardownOfferPresentation());
    }
  }

  void _onViewTap() {
    final offer = Get.isRegistered<FirestoreActiveOrdersListener>()
        ? Get.find<FirestoreActiveOrdersListener>().foregroundMapOffer.value
        : _activeOffer;
    if (offer == null) return;

    final nav = Get.to<void>(
      () => FindingRideRequestsScreen(
        ride: offer.mapped,
        preferAcceptAction: true,
        firestoreDocId: offer.docId,
        firestoreCollection: offer.collection,
      ),
    );
    unawaited(
      nav?.then((_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Get.isRegistered<FirestoreActiveOrdersListener>()) {
                Get.find<FirestoreActiveOrdersListener>().removeOffersForDocKey(
                  offer.docKey,
                );
              }
            });
          }) ??
          Future<void>.value(),
    );
  }

  @override
  void dispose() {
    _sheetReveal.dispose();
    _mapThemeWorker?.dispose();
    _driverLatLngWorker?.dispose();
    _driverHeadingWorker?.dispose();
    _driverPermissionWorker?.dispose();
    _firestoreOfferWorker?.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Color get _bannerBg =>
      (_isDarkMode ? AppConst.grey : Colors.white).withValues(alpha: 0.94);

  Color get _bannerText => AppConst.black;

  Color get _layersFabBg =>
      (_isDarkMode ? const Color(0xFF2C2C2C) : Colors.white).withValues(
        alpha: 0.95,
      );

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppConst.scaffoldBackground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _bannerBg,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: _isDarkMode ? 0.35 : 0.08,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(8.w, topInset + 6.h, 12.w, 12.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => Get.back<void>(),
                  icon: Icon(Icons.arrow_back_rounded, color: _bannerText),
                  splashRadius: 24,
                ),
                Expanded(
                  child: Text(
                    'full_map_realtime_orders_hint'.tr,
                    style: TextStyle(
                      color: _bannerText.withValues(alpha: 0.9),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _mapTarget,
                    zoom: 13.8,
                  ),
                  style: _mapStyleJson,
                  mapType: _mapType,
                  markers: _markers(),
                  polylines: _polylines,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  padding: EdgeInsets.only(
                    top: 8,
                    bottom: _activeOffer != null
                        ? MediaQuery.of(context).size.height * 0.34
                        : 0,
                  ),
                  onMapCreated: _onMapCreated,
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
                  },
                ),
                Positioned(
                  top: 12.h,
                  right: 12.w,
                  child: Material(
                    color: _layersFabBg,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: PopupMenuButton<MapType>(
                      tooltip: 'map_type'.tr,
                      icon: Icon(
                        Icons.layers_rounded,
                        color: AppConst.black,
                        size: 22.sp,
                      ),
                      onSelected: _setMapType,
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: MapType.normal,
                          child: Text('map_type_default'.tr),
                        ),
                        PopupMenuItem(
                          value: MapType.satellite,
                          child: Text('map_type_satellite'.tr),
                        ),
                        PopupMenuItem(
                          value: MapType.terrain,
                          child: Text('map_type_terrain'.tr),
                        ),
                        PopupMenuItem(
                          value: MapType.hybrid,
                          child: Text('map_type_hybrid'.tr),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_activeOffer != null)
                  SlideTransition(
                    position: _sheetSlide,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: DraggableScrollableSheet(
                        expand: false,
                        initialChildSize: 0.44,
                        minChildSize: 0.29,
                        maxChildSize: 0.93,
                        builder: (context, scrollController) =>
                            NearbyOrderOfferSheet(
                              offer: _activeOffer!,
                              route: _activeRoute,
                              scrollController: scrollController,
                              onViewDetails: _onViewTap,
                              onDismiss: _onDismissSheet,
                            ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
