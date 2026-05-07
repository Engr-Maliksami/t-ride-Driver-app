import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:t_rider_services_app/consts/appConst.dart';
import 'package:t_rider_services_app/data/directions/google_directions_service.dart';
import 'package:t_rider_services_app/data/models/order_active_status_model.dart';
import 'package:t_rider_services_app/data/repositories/rides_repository.dart';
import 'package:t_rider_services_app/views/home/setting/setting_screen.dart';
import 'package:t_rider_services_app/views/widgets/app_snackbar.dart';

String? _formatFoodOrderTime(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final d = DateTime.tryParse(iso);
  if (d == null) return null;
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

Widget _foodMetaChip(IconData icon, String label) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
    decoration: BoxDecoration(
      color: AppConst.blackWithOpacity(0.07),
      borderRadius: BorderRadius.circular(20.r),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.sp, color: AppConst.blackWithOpacity(0.72)),
        SizedBox(width: 6.w),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: AppConst.black.withValues(alpha: 0.88),
            ),
          ),
        ),
      ],
    ),
  );
}

class FindingFoodDeliveryScreen extends StatefulWidget {
  const FindingFoodDeliveryScreen({super.key, required this.order});

  final ActiveFoodOrder order;

  @override
  State<FindingFoodDeliveryScreen> createState() =>
      _FindingFoodDeliveryScreenState();
}

class _FindingFoodDeliveryScreenState extends State<FindingFoodDeliveryScreen> {
  final RidesRepository _ridesRepository = RidesRepository();
  GoogleMapController? _mapController;
  bool _actionInProgress = false;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  List<LatLng>? _drivingPolylinePoints;
  bool _routeLoading = false;
  bool _acceptedThisSession = false;

  ActiveFoodOrder get _order => widget.order;

  static const LatLng _fallbackMapCenter = LatLng(24.8607, 67.0011);

  LatLng? get _pickupLatLng {
    final v = _order.vendor;
    return _parseLatLng(v?.latitude, v?.longitude);
  }

  LatLng? get _dropLatLng =>
      _parseLatLng(_order.deliveryLat, _order.deliveryLng);

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

  bool get _hasMapCoords => _pickupLatLng != null || _dropLatLng != null;

  void _populateMapOverlays({bool awaitDirections = false}) {
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
            title: 'from'.tr,
            snippet: _shortSnippet(_order.vendor?.name ?? 'vendor'.tr),
          ),
        ),
      );
    }
    if (drop != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('delivery'),
          position: drop,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'to'.tr,
            snippet: _shortSnippet(_order.deliveryAddress),
          ),
        ),
      );
    }
    if (pickup != null && drop != null && !awaitDirections) {
      _setRoutePolylinePoints([pickup, drop], geodesic: true);
    }
  }

  void _setRoutePolylinePoints(List<LatLng> points, {required bool geodesic}) {
    _polylines
      ..clear()
      ..add(
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
        _setRoutePolylinePoints(pts, geodesic: false);
      });
      await _fitCameraToRoute();
    } else {
      setState(() {
        _routeLoading = false;
        _drivingPolylinePoints = null;
        _setRoutePolylinePoints([pickup, drop], geodesic: true);
      });
      await _fitCameraToRoute();
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

  bool get _showAcceptButton {
    if (_acceptedThisSession) return false;
    final s = (_order.status ?? '').trim().toLowerCase();
    return s == 'searching' || s == 'pending';
  }

  bool get _isTerminalOrderStatus {
    final s = (_order.status ?? '').trim().toLowerCase().replaceAll(' ', '_');
    return s == 'completed' ||
        s == 'cancelled' ||
        s == 'canceled' ||
        s == 'done' ||
        s == 'delivered';
  }

  bool get _showMarkCompleteButton =>
      !_showAcceptButton && !_isTerminalOrderStatus;

  Future<void> _onMarkCompletePressed() async {
    final id = _order.id;
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
          'mark_delivery_completed_question'.tr,
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

    setState(() => _actionInProgress = true);
    try {
      await _ridesRepository.completeFoodOrder(orderId: id);
      if (!mounted) return;
      setState(() => _actionInProgress = false);
      Get.back();
      AppSnackbar.showSuccess(
        title: 'delivery_completed'.tr,
        message: 'order_marked_completed'.tr,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionInProgress = false);
      AppSnackbar.showApiError(
        e,
        fallbackMessage: 'could_not_complete_try_again'.tr,
      );
    }
  }

  Future<void> _onAccept() async {
    final id = _order.id;
    if (id == null) {
      AppSnackbar.show(title: 'accept'.tr, message: 'missing_order_id'.tr);
      return;
    }
    setState(() => _actionInProgress = true);
    try {
      await _ridesRepository.acceptFoodOrder(orderId: id);
      if (!mounted) return;
      setState(() {
        _actionInProgress = false;
        _acceptedThisSession = true;
      });
      AppSnackbar.showSuccess(
        title: 'delivery_accepted'.tr,
        message: 'you_can_cancel_from_here'.tr,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionInProgress = false);
      AppSnackbar.showApiError(
        e,
        fallbackMessage: 'could_not_accept_order_try_again'.tr,
      );
    }
  }

  Future<void> _onCancel() async {
    final id = _order.id;
    if (id == null) {
      Get.back();
      return;
    }
    setState(() => _actionInProgress = true);
    try {
      await _ridesRepository.cancelFoodOrder(orderId: id);
      if (!mounted) return;
      setState(() => _actionInProgress = false);
      Get.back();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionInProgress = false);
      AppSnackbar.showApiError(
        e,
        fallbackMessage: 'could_not_cancel_try_again'.tr,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    final twoPoints = _pickupLatLng != null && _dropLatLng != null;
    _routeLoading = twoPoints;
    _populateMapOverlays(awaitDirections: twoPoints);
    if (twoPoints) {
      _loadDrivingRoute();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: !_hasMapCoords
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
                            'no_location_data_for_order'.tr,
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
                      'delivery'.tr,
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
                      onPressed: () => Get.to(() => const SettingScreen()),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
                    Container(
                      margin: EdgeInsets.only(top: 12.h),
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: AppConst.white,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
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
                                  Text(
                                    _order.orderCode != null
                                        ? '${'order'.tr} ${_order.orderCode}'
                                        : 'food_order'.tr,
                                    style: TextStyle(
                                      color: AppConst.black,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 8.w,
                                    runSpacing: 6.h,
                                    children: [
                                      if (_order.categoryId != null)
                                        _foodMetaChip(
                                          Icons.category_outlined,
                                          '${'category'.tr} ${_order.categoryId}',
                                        ),
                                      if (_formatFoodOrderTime(
                                            _order.createdAt,
                                          ) !=
                                          null)
                                        _foodMetaChip(
                                          Icons.schedule_outlined,
                                          '${'placed'.tr} ${_formatFoodOrderTime(_order.createdAt)}',
                                        ),
                                      if (_order.driverId == null)
                                        _foodMetaChip(
                                          Icons.delivery_dining_outlined,
                                          'unassigned'.tr,
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 4.h),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.storefront_outlined,
                                        color: AppConst.black,
                                        size: 20.sp,
                                      ),
                                      SizedBox(width: 8.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${'from'.tr}:',
                                              style: TextStyle(
                                                color: AppConst.black
                                                    .withValues(alpha: 0.45),
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            SizedBox(height: 2.h),
                                            Text(
                                              _order.vendor?.name ??
                                                  'restaurant'.tr,
                                              style: TextStyle(
                                                color: AppConst.black,
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if ((_order.vendor?.address ?? '')
                                                .trim()
                                                .isNotEmpty) ...[
                                              SizedBox(height: 4.h),
                                              Text(
                                                _order.vendor!.address!.trim(),
                                                style: TextStyle(
                                                  color: AppConst.black
                                                      .withValues(alpha: 0.8),
                                                  fontSize: 13.sp,
                                                  height: 1.25,
                                                ),
                                              ),
                                            ],
                                            if (_pickupLatLng == null)
                                              Padding(
                                                padding: EdgeInsets.only(
                                                  top: 4.h,
                                                ),
                                                child: Text(
                                                  'no_pickup_coordinates'.tr,
                                                  style: TextStyle(
                                                    color:
                                                        AppConst.blackWithOpacity(
                                                          0.5,
                                                        ),
                                                    fontSize: 11.sp,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12.h),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: AppConst.black,
                                        size: 20.sp,
                                      ),
                                      SizedBox(width: 8.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${'to'.tr}:',
                                              style: TextStyle(
                                                color: AppConst.black
                                                    .withValues(alpha: 0.45),
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            SizedBox(height: 2.h),
                                            Text(
                                              _order.deliveryAddress ?? '—',
                                              style: TextStyle(
                                                color: AppConst.black,
                                                fontSize: 14.sp,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if ((_order.deliveryInstructions ?? '')
                                      .trim()
                                      .isNotEmpty) ...[
                                    SizedBox(height: 12.h),
                                    Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.all(12.w),
                                      decoration: BoxDecoration(
                                        color: AppConst.primaryColorWithOpacity(
                                          0.28,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                        border: Border.all(
                                          color: AppConst.blackWithOpacity(
                                            0.06,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.note_alt_outlined,
                                                size: 18.sp,
                                                color: AppConst.black
                                                    .withValues(alpha: 0.75),
                                              ),
                                              SizedBox(width: 6.w),
                                              Text(
                                                'delivery_instructions'.tr,
                                                style: TextStyle(
                                                  color: AppConst.black,
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 6.h),
                                          Text(
                                            _order.deliveryInstructions!.trim(),
                                            style: TextStyle(
                                              color: AppConst.black.withValues(
                                                alpha: 0.85,
                                              ),
                                              fontSize: 13.sp,
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  SizedBox(height: 12.h),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.payments_outlined,
                                        color: AppConst.black,
                                        size: 20.sp,
                                      ),
                                      SizedBox(width: 8.w),
                                      Expanded(
                                        child: Text(
                                          [
                                            if ((_order.totalAmount ?? '')
                                                .isNotEmpty)
                                              '${'items_total'.tr}: ${_order.totalAmount}',
                                            if ((_order.deliveryFee ?? '')
                                                .isNotEmpty)
                                              '${'delivery'.tr}: ${_order.deliveryFee}',
                                            if ((_order.paymentMethod ?? '')
                                                .isNotEmpty)
                                              _order.paymentMethod!,
                                          ].join(' · '),
                                          style: TextStyle(
                                            color: AppConst.black,
                                            fontSize: 14.sp,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_formatFoodOrderTime(_order.updatedAt) !=
                                      null) ...[
                                    SizedBox(height: 6.h),
                                    Text(
                                      '${'updated'.tr} ${_formatFoodOrderTime(_order.updatedAt)}',
                                      style: TextStyle(
                                        color: AppConst.blackWithOpacity(0.45),
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                  if (_order.items.isNotEmpty) ...[
                                    SizedBox(height: 14.h),
                                    Text(
                                      '${'items'.tr} (${_order.items.length})',
                                      style: TextStyle(
                                        color: AppConst.black,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 8.h),
                                    ..._order.items.asMap().entries.map((en) {
                                      final i = en.key;
                                      final e = en.value;
                                      final name =
                                          (e.product?.name ?? e.productName)
                                              ?.trim();
                                      final displayName =
                                          (name != null && name.isNotEmpty)
                                          ? name
                                          : 'item'.tr;
                                      final unit = (e.unitPrice ?? '').trim();
                                      final lineTotal = (e.total ?? '').trim();
                                      final listPrice = (e.product?.price ?? '')
                                          .trim();
                                      final note = (e.specialInstructions ?? '')
                                          .trim();
                                      final isLast =
                                          i == _order.items.length - 1;
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${e.quantity ?? 1}× $displayName',
                                            style: TextStyle(
                                              color: AppConst.black,
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (unit.isNotEmpty) ...[
                                            SizedBox(height: 2.h),
                                            Text(
                                              '$unit ${'each'.tr}',
                                              style: TextStyle(
                                                color:
                                                    AppConst.blackWithOpacity(
                                                      0.6,
                                                    ),
                                                fontSize: 12.sp,
                                              ),
                                            ),
                                          ],
                                          if (lineTotal.isNotEmpty) ...[
                                            SizedBox(height: 2.h),
                                            Text(
                                              '${'line_total'.tr}: $lineTotal',
                                              style: TextStyle(
                                                color: AppConst.black
                                                    .withValues(alpha: 0.75),
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                          if (listPrice.isNotEmpty &&
                                              listPrice != unit) ...[
                                            SizedBox(height: 2.h),
                                            Text(
                                              '${'menu_price'.tr}: $listPrice',
                                              style: TextStyle(
                                                color:
                                                    AppConst.blackWithOpacity(
                                                      0.5,
                                                    ),
                                                fontSize: 11.sp,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                          if (note.isNotEmpty) ...[
                                            SizedBox(height: 4.h),
                                            Text(
                                              '${'note'.tr}: $note',
                                              style: TextStyle(
                                                color: AppConst.black
                                                    .withValues(alpha: 0.72),
                                                fontSize: 11.sp,
                                                height: 1.25,
                                              ),
                                            ),
                                          ],
                                          if (!isLast) ...[
                                            SizedBox(height: 12.h),
                                            Divider(
                                              height: 1,
                                              color: AppConst.blackWithOpacity(
                                                0.08,
                                              ),
                                            ),
                                          ],
                                        ],
                                      );
                                    }),
                                  ],
                                  if ((_order.contactPhone ?? '')
                                      .isNotEmpty) ...[
                                    SizedBox(height: 12.h),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.phone_outlined,
                                          color: AppConst.black,
                                          size: 18.sp,
                                        ),
                                        SizedBox(width: 8.w),
                                        Expanded(
                                          child: Text(
                                            _order.contactPhone!,
                                            style: TextStyle(
                                              color: AppConst.blackWithOpacity(
                                                0.75,
                                              ),
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
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
                                  onPressed: _actionInProgress
                                      ? null
                                      : _onAccept,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppConst.black,
                                    disabledBackgroundColor:
                                        AppConst.blackWithOpacity(0.4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                  ),
                                  child: _actionInProgress
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
                                      onPressed: _actionInProgress
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
                                      child: _actionInProgress
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
                                  SizedBox(height: 12.h),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50.h,
                                    child: ElevatedButton(
                                      onPressed: _actionInProgress
                                          ? null
                                          : _onCancel,
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
                                  onPressed: _actionInProgress
                                      ? null
                                      : _onCancel,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppConst.grey,
                                    disabledBackgroundColor: AppConst.grey
                                        .withValues(alpha: 0.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                  ),
                                  child: _actionInProgress
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
