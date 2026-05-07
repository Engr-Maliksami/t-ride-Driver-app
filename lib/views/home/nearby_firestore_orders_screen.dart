import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:t_rider_services_app/consts/appConst.dart';
import 'package:t_rider_services_app/data/firestore/firestore_active_order_mapper.dart';
import 'package:t_rider_services_app/data/firestore/firestore_nearby_helper.dart';
import 'package:t_rider_services_app/data/local/secure_storage_service.dart';
import 'package:t_rider_services_app/data/models/order_active_status_model.dart';
import 'package:t_rider_services_app/views/home/finding_ride_requests_screen.dart';

/// Lists `active_rides` and `active_courier` documents whose pickup is within
/// [FirestoreNearbyHelper.maxRangeKm] of the driver's current position.
class NearbyFirestoreOrdersScreen extends StatefulWidget {
  const NearbyFirestoreOrdersScreen({super.key});

  @override
  State<NearbyFirestoreOrdersScreen> createState() =>
      _NearbyFirestoreOrdersScreenState();
}

class _NearbyFirestoreOrdersScreenState
    extends State<NearbyFirestoreOrdersScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SecureStorageService _storageService = SecureStorageService();

  List<_NearbyEntry> _entries = [];
  bool _loading = true;
  String? _errorKey;

  /// Device GPS [Position] used to measure distance to each order pickup.
  Position? _searchFromPosition;

  /// Human-readable place for [_searchFromPosition] (reverse geocoding).
  String? _searchFromLocationLabel;
  bool get _isDarkMode => AppConst.isDarkMode;
  Color get _screenBackground => AppConst.scaffoldBackground;
  Color _textWithOpacity(double opacity) =>
      Colors.black.withValues(alpha: opacity);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorKey = null;
    });

    final me = await FirestoreNearbyHelper.tryGetCurrentPosition();
    if (!mounted) return;
    if (me == null) {
      setState(() {
        _loading = false;
        _errorKey = 'firestore_location_needed';
        _entries = [];
        _searchFromPosition = null;
        _searchFromLocationLabel = null;
      });
      return;
    }

    try {
      final labelFuture = _reverseGeocodeLabel(me.latitude, me.longitude);
      final currentUserId = await _storageService.getUserId();
      final rides = await _db.collection('active_rides').get();
      final couriers = await _db.collection('active_courier').get();

      final list = <_NearbyEntry>[];

      for (final d in rides.docs) {
        final data = d.data();
        if (_isCompletedOrder(data)) continue;
        if (!_isRelevantForCurrentUser(data, currentUserId)) continue;
        final m = FirestoreNearbyHelper.distanceMetersToPickup(data, me);
        if (m != null && m <= FirestoreNearbyHelper.maxRangeMeters) {
          list.add(
            _NearbyEntry(
              isCourier: false,
              docId: d.id,
              data: data,
              distanceMeters: m,
            ),
          );
        }
      }

      for (final d in couriers.docs) {
        final data = d.data();
        if (_isCompletedOrder(data)) continue;
        if (!_isRelevantForCurrentUser(data, currentUserId)) continue;
        final m = FirestoreNearbyHelper.distanceMetersToPickup(data, me);
        if (m != null && m <= FirestoreNearbyHelper.maxRangeMeters) {
          list.add(
            _NearbyEntry(
              isCourier: true,
              docId: d.id,
              data: data,
              distanceMeters: m,
            ),
          );
        }
      }

      list.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

      final searchLabel = await labelFuture;
      if (!mounted) return;
      setState(() {
        _searchFromPosition = me;
        _searchFromLocationLabel = searchLabel;
        _entries = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _entries = [];
        _searchFromPosition = null;
        _searchFromLocationLabel = null;
        _loading = false;
        _errorKey = 'firestore_nearby_load_failed';
      });
    }
  }

  /// Street / locality (reverse geocoding), else a short lat/lng fallback.
  Future<String> _reverseGeocodeLabel(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final street = (p.street?.isNotEmpty == true)
            ? p.street
            : (p.name?.isNotEmpty == true ? p.name : null);
        final city = p.locality;
        final state = p.administrativeArea;
        final country = p.country;

        final parts = <String>[];
        if (street != null && street.isNotEmpty) parts.add(street);
        if (city != null && city.isNotEmpty && !parts.contains(city)) {
          parts.add(city);
        }
        if (state != null && state.isNotEmpty && !parts.contains(state)) {
          parts.add(state);
        }
        if (country != null && country.isNotEmpty && !parts.contains(country)) {
          parts.add(country);
        }

        if (parts.length > 3) return parts.sublist(0, 3).join(', ');
        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (_) {
      // fallback below
    }
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  /// Show only orders that are either:
  /// 1) waiting for acceptance (`accepted_by_user_id` missing/null), or
  /// 2) already accepted by current user.
  bool _isRelevantForCurrentUser(
    Map<String, dynamic> data,
    int? currentUserId,
  ) {
    final acceptedRaw = data['accepted_by_user_id'];
    final acceptedBy = _asInt(acceptedRaw);
    if (acceptedBy == null) return true;
    if (currentUserId == null) {
      // If local user id is unavailable, keep only "waiting" jobs.
      return false;
    }
    return acceptedBy == currentUserId;
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  /// Hide orders already marked complete (the service app settles payout on
  /// these). Matches the fields written in [FindingRideRequestsScreen].
  bool _isCompletedOrder(Map<String, dynamic> data) {
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

  /// 1 km ≈ 0.621371 miles. Used for display only; filtering still uses km.
  static const double _milesPerKm = 0.621371;
  static const double _milesPerMeter = 0.000621371;
  static const double _feetPerMeter = 3.28084;

  String get _maxRangeMilesLabel {
    final miles = FirestoreNearbyHelper.maxRangeKm * _milesPerKm;
    return miles >= 10 ? miles.toStringAsFixed(0) : miles.toStringAsFixed(1);
  }

  String _searchReferenceDetailText() {
    final pos = _searchFromPosition;
    if (pos == null) return '';
    final name =
        (_searchFromLocationLabel != null &&
            _searchFromLocationLabel!.trim().isNotEmpty)
        ? _searchFromLocationLabel!.trim()
        : '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
    return 'firestore_nearby_reference_detail'.tr
        .replaceAll('@name', name)
        .replaceAll('@mi', _maxRangeMilesLabel);
  }

  String _distanceLabel(double meters) {
    final miles = meters * _milesPerMeter;
    if (miles < 0.1) {
      final feet = (meters * _feetPerMeter).round();
      return '$feet ft';
    }
    return '${miles.toStringAsFixed(1)} mi';
  }

  String _activeOrderStatusBadgeLabel(String? status) {
    final raw = (status ?? '').trim();
    if (raw.isEmpty) return '—';
    if (raw.toLowerCase() == 'searching') return 'pending'.tr.toUpperCase();
    return raw.toUpperCase();
  }

  Future<void> _openDetail(_NearbyEntry e) async {
    HapticFeedback.lightImpact();
    final ActiveRideCourierOrder mapped = e.isCourier
        ? FirestoreActiveOrderMapper.activeCourierToModel(e.docId, e.data)
        : FirestoreActiveOrderMapper.activeRideToModel(e.docId, e.data);
    await Get.to<void>(
      () => FindingRideRequestsScreen(
        ride: mapped,
        preferAcceptAction: true,
        firestoreCollection: e.isCourier ? 'active_courier' : 'active_rides',
        firestoreDocId: e.docId,
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBackground,
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20.r),
                bottomRight: Radius.circular(20.r),
              ),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8.h,
              left: 8.w,
              right: 16.w,
              bottom: 20.h,
            ),
            child: Row(
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 22.sp,
                    ),
                    onPressed: () => Get.back<void>(),
                  ),
                ),
                Expanded(
                  child: Text(
                    'available_orders'.tr,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.white, size: 22.sp),
                  onPressed: _loading ? null : _load,
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: SizedBox(
                      width: 32.w,
                      height: 32.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _errorKey != null
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Text(
                        _errorKey!.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _textWithOpacity(0.75),
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  )
                : _entries.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'online_waiting_for_requests'.tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _textWithOpacity(0.65),
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            'move_to_busy_area_hint'.tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _textWithOpacity(0.55),
                              fontSize: 13.sp,
                              height: 1.35,
                            ),
                          ),
                          if (_searchFromPosition != null) ...[
                            SizedBox(height: 12.h),
                            Text(
                              _searchReferenceDetailText(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _textWithOpacity(0.5),
                                fontSize: 12.sp,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: _isDarkMode ? Colors.white : AppConst.black,
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
                      itemCount: _entries.length,
                      separatorBuilder: (_, __) => SizedBox(height: 10.h),
                      itemBuilder: (context, i) {
                        final e = _entries[i];
                        return _NearbyCard(
                          entry: e,
                          distanceLabel: _distanceLabel(e.distanceMeters),
                          statusLabel: _activeOrderStatusBadgeLabel(
                            e.data['status'] as String?,
                          ),
                          onOpen: () => _openDetail(e),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NearbyEntry {
  _NearbyEntry({
    required this.isCourier,
    required this.docId,
    required this.data,
    required this.distanceMeters,
  });

  final bool isCourier;
  final String docId;
  final Map<String, dynamic> data;
  final double distanceMeters;
}

class _NearbyCard extends StatelessWidget {
  const _NearbyCard({
    required this.entry,
    required this.distanceLabel,
    required this.statusLabel,
    required this.onOpen,
  });

  final _NearbyEntry entry;
  final String distanceLabel;
  final String statusLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = AppConst.isDarkMode;
    const primaryText = Colors.black;
    Color textWithOpacity(double opacity) =>
        primaryText.withValues(alpha: opacity);
    final cardBackground = isDarkMode
        ? const Color(0xFFEFEFEF)
        : AppConst.white;

    final pickup = entry.data['pickup'];
    String pickupAddr = '—';
    if (pickup is Map) {
      final a = pickup['address'];
      if (a != null) pickupAddr = a.toString();
    }
    final dropoff = entry.data['dropoff'];
    String dropAddr = '—';
    if (dropoff is Map) {
      final a = dropoff['address'];
      if (a != null) dropAddr = a.toString();
    }

    final typeLabel = entry.isCourier ? 'courier'.tr : 'ride'.tr;
    final idLabel = entry.isCourier
        ? (entry.data['doc_id'] ?? entry.data['courier_id'] ?? entry.docId)
              .toString()
        : (entry.data['ride_id'] ?? entry.docId).toString();

    final fareRaw = entry.isCourier
        ? entry.data['estimated_fare']
        : entry.data['fare'];
    final fareStr = fareRaw?.toString();

    return Material(
      color: cardBackground,
      borderRadius: AppConst.borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        splashColor: AppConst.primaryColorWithOpacity(0.35),
        highlightColor: textWithOpacity(0.04),
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppConst.primaryColorWithOpacity(0.35),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    idLabel,
                    style: TextStyle(
                      color: textWithOpacity(0.75),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Icon(
                    Icons.near_me_outlined,
                    size: 16.sp,
                    color: textWithOpacity(0.5),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    distanceLabel,
                    style: TextStyle(
                      color: textWithOpacity(0.65),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Text(
                pickupAddr,
                style: TextStyle(
                  color: textWithOpacity(0.85),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: Icon(
                  Icons.south,
                  size: 16.sp,
                  color: textWithOpacity(0.4),
                ),
              ),
              Text(
                dropAddr,
                style: TextStyle(
                  color: textWithOpacity(0.85),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: textWithOpacity(0.07),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (fareStr != null && fareStr.isNotEmpty)
                    Text(
                      fareStr,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
