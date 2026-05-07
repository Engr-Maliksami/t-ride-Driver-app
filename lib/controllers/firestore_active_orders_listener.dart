import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:t_rider_services_app/consts/appConst.dart';
import 'package:t_rider_services_app/data/local/secure_storage_service.dart';
import 'package:t_rider_services_app/data/firestore/firestore_active_order_mapper.dart';
import 'package:t_rider_services_app/data/firestore/firestore_nearby_helper.dart';
import 'package:t_rider_services_app/data/models/order_active_status_model.dart';
import 'package:t_rider_services_app/views/home/navbar.dart';
import 'package:t_rider_services_app/views/home/finding_ride_requests_screen.dart';
import 'package:t_rider_services_app/views/widgets/app_snackbar.dart';

/// Listens to `active_rides` and `active_courier` and shows a global dialog when
/// a new document is added (first snapshot is ignored to avoid flooding).
///
/// Notifications are only shown when the document's **pickup** coordinates are
/// within [FirestoreNearbyHelper.maxRangeKm] of the driver's current location.
class FirestoreActiveOrdersListener extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SecureStorageService _storageService = SecureStorageService();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ridesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _courierSub;

  final List<_QueuedDialog> _queue = [];
  bool _dialogOpen = false;
  String? _activeDialogDocKey;

  @override
  void onReady() {
    super.onReady();
    _attachRides();
    _attachCourier();
  }

  @override
  void onClose() {
    _ridesSub?.cancel();
    _courierSub?.cancel();
    super.onClose();
  }

  void _attachRides() {
    var first = true;
    _ridesSub = _db.collection('active_rides').snapshots().listen(
      (snapshot) {
        if (first) {
          first = false;
          return;
        }
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            unawaited(_enqueueRideIfNearby(change.doc));
          } else if (change.type == DocumentChangeType.modified) {
            unawaited(_handleAcceptedUpdate(change.doc, isCourier: false));
          }
        }
      },
      onError: (_) {},
    );
  }

  void _attachCourier() {
    var first = true;
    _courierSub = _db.collection('active_courier').snapshots().listen(
      (snapshot) {
        if (first) {
          first = false;
          return;
        }
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            unawaited(_enqueueCourierIfNearby(change.doc));
          } else if (change.type == DocumentChangeType.modified) {
            unawaited(_handleAcceptedUpdate(change.doc, isCourier: true));
          }
        }
      },
      onError: (_) {},
    );
  }

  Future<void> _enqueueRideIfNearby(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    if (data == null) return;
    if (!await FirestoreNearbyHelper.isPickupWithinRange(data)) return;
    final mapped = FirestoreActiveOrderMapper.activeRideToModel(doc.id, data);
    _queue.add(
      _QueuedDialog(
        titleKey: 'firestore_new_active_ride',
        mapped: mapped,
        docId: doc.id,
        collection: 'active_rides',
        child: _FirestoreRideDialogBody(data: data),
      ),
    );
    _pumpQueue();
  }

  Future<void> _enqueueCourierIfNearby(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    if (data == null) return;
    if (!await FirestoreNearbyHelper.isPickupWithinRange(data)) return;
    final mapped = FirestoreActiveOrderMapper.activeCourierToModel(doc.id, data);
    _queue.add(
      _QueuedDialog(
        titleKey: 'firestore_new_active_courier',
        mapped: mapped,
        docId: doc.id,
        collection: 'active_courier',
        child: _FirestoreCourierDialogBody(data: data),
      ),
    );
    _pumpQueue();
  }

  Future<void> _handleAcceptedUpdate(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required bool isCourier,
  }) async {
    final data = doc.data();
    if (data == null) return;
    final acceptedRaw = data['accepted_by_user_id'];
    if (acceptedRaw == null) return;
    final acceptedByUserId = acceptedRaw is int
        ? acceptedRaw
        : int.tryParse(acceptedRaw.toString());
    if (acceptedByUserId == null) return;

    final myUserId = await _storageService.getUserId();
    if (myUserId == null || myUserId == acceptedByUserId) return;

    final collection = isCourier ? 'active_courier' : 'active_rides';
    final docKey = '$collection:${doc.id}';
    _queue.removeWhere((e) => e.docKey == docKey);
    if (_activeDialogDocKey == docKey && (Get.isDialogOpen ?? false)) {
      Get.back<void>();
    }

    final viewing = FindingRideRequestsScreen.currentlyViewingOrder;
    if (viewing == null) return;
    final viewingKind = viewing.kind;
    final expectedKind = isCourier ? 'courier' : 'ride';
    if (viewingKind != expectedKind) return;

    final viewingDocId = viewing.docId;
    final orderIdRaw = isCourier ? data['courier_id'] : data['ride_id'];
    final changedOrderId = orderIdRaw is int
        ? orderIdRaw
        : int.tryParse(orderIdRaw?.toString() ?? '');

    final sameDoc = viewingDocId != null && viewingDocId == doc.id;
    final sameOrderId =
        changedOrderId != null && viewing.orderId != null && viewing.orderId == changedOrderId;
    if (!sameDoc && !sameOrderId) return;

    FindingRideRequestsScreen.currentlyViewingOrder = null;
    if (Get.currentRoute != '/Navbar') {
      Get.offAll(() => const Navbar());
    }
    AppSnackbar.show(title: 'Expired', message: 'Expired');
  }

  Future<void> _pumpQueue() async {
    if (_dialogOpen || _queue.isEmpty) return;
    _dialogOpen = true;
    final item = _queue.removeAt(0);
    _activeDialogDocKey = item.docKey;
    await Get.dialog<void>(
      _FirestoreNewOrderDialog(
        titleKey: item.titleKey,
        mapped: item.mapped,
        docId: item.docId,
        collection: item.collection,
        child: item.child,
      ),
      barrierDismissible: true,
    );
    _dialogOpen = false;
    _activeDialogDocKey = null;
    _pumpQueue();
  }
}

class _QueuedDialog {
  _QueuedDialog({
    required this.titleKey,
    required this.mapped,
    required this.docId,
    required this.collection,
    required this.child,
  });

  final String titleKey;
  final ActiveRideCourierOrder mapped;
  final String docId;
  final String collection;
  final Widget child;

  String get docKey => '$collection:$docId';
}

class _FirestoreNewOrderDialog extends StatelessWidget {
  const _FirestoreNewOrderDialog({
    required this.titleKey,
    required this.mapped,
    required this.docId,
    required this.collection,
    required this.child,
  });

  final String titleKey;
  final ActiveRideCourierOrder mapped;
  final String docId;
  final String collection;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                titleKey.tr,
                style: TextStyle(
                  color: AppConst.black,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                height: (MediaQuery.sizeOf(context).height * 0.52).clamp(
                  220.0,
                  520.0,
                ),
                child: SingleChildScrollView(
                  child: child,
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Get.back<void>();
                      },
                      child: Text('cancel'.tr),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Get.back<void>();
                        Future<void>.microtask(() {
                          Get.to<void>(
                            () => FindingRideRequestsScreen(
                              ride: mapped,
                              preferAcceptAction: true,
                              firestoreDocId: docId,
                              firestoreCollection: collection,
                            ),
                          );
                        });
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppConst.primaryColor,
                        foregroundColor: AppConst.black,
                      ),
                      child: Text('view'.tr),
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

class _FirestoreRideDialogBody extends StatelessWidget {
  const _FirestoreRideDialogBody({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final pickup = _asMap(data['pickup']);
    final dropoff = _asMap(data['dropoff']);
    final rider = _asMap(data['rider']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _kv('fs_ride_id'.tr, _fmt(data['ride_id'])),
        _kv('status'.tr, _fmt(data['status'])),
        _kv('fs_general_status'.tr, _fmt(data['general_status'])),
        _kv('fs_service_type'.tr, _fmt(data['service_type'])),
        _kv('fs_ride_type'.tr, _fmt(data['ride_type'])),
        _kv('fare'.tr, _fmt(data['fare'])),
        _kv('payment'.tr, _fmt(data['payment_method'])),
        _kv('fs_coupon_code'.tr, _fmt(data['coupon_code'])),
        _kv('fs_assigned_driver_id'.tr, _fmt(data['assigned_driver_id'])),
        SizedBox(height: 8.h),
        _section('pickup'.tr),
        _kv('fs_address'.tr, _fmt(pickup?['address'])),
        _kv('fs_latitude'.tr, _fmtLat(pickup?['latitude'])),
        _kv('fs_longitude'.tr, _fmtLng(pickup?['longitude'])),
        SizedBox(height: 8.h),
        _section('dropoff'.tr),
        _kv('fs_address'.tr, _fmt(dropoff?['address'])),
        _kv('fs_latitude'.tr, _fmtLat(dropoff?['latitude'])),
        _kv('fs_longitude'.tr, _fmtLng(dropoff?['longitude'])),
        SizedBox(height: 8.h),
        _section('passenger'.tr),
        _kv('fs_rider_id'.tr, _fmt(rider?['id'])),
        _kv('fs_rider_name'.tr, _fmt(rider?['name'])),
        _kv('fs_rider_phone'.tr, _fmt(rider?['phone_number'])),
        _kv('fs_rider_photo'.tr, _fmt(rider?['photo'])),
        SizedBox(height: 8.h),
        _kv('fs_created_at'.tr, _fmt(data['created_at'])),
        _kv('fs_updated_at'.tr, _fmt(data['updated_at'])),
        _kv('fs_source_app'.tr, _fmt(data['source_app'])),
      ],
    );
  }
}

class _FirestoreCourierDialogBody extends StatelessWidget {
  const _FirestoreCourierDialogBody({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final pickup = _asMap(data['pickup']);
    final dropoff = _asMap(data['dropoff']);
    final rider = _asMap(data['rider']);
    final pkg = _asMap(data['package']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _kv('fs_doc_id'.tr, _fmt(data['doc_id'])),
        _kv('fs_courier_id'.tr, _fmt(data['courier_id'])),
        _kv('status'.tr, _fmt(data['status'])),
        _kv('fs_general_status'.tr, _fmt(data['general_status'])),
        _kv('fs_service_type'.tr, _fmt(data['service_type'])),
        _kv('fs_estimated_fare'.tr, _fmt(data['estimated_fare'])),
        _kv('payment'.tr, _fmt(data['payment_method'])),
        SizedBox(height: 8.h),
        _section('item'.tr),
        _kv('fs_package_size'.tr, _fmt(pkg?['size'])),
        _kv('fs_package_weight'.tr, _fmt(pkg?['weight'])),
        _kv('fs_package_photo'.tr, _fmt(pkg?['photo'])),
        SizedBox(height: 8.h),
        _section('pickup'.tr),
        _kv('fs_address'.tr, _fmt(pickup?['address'])),
        _kv('fs_latitude'.tr, _fmtLat(pickup?['latitude'])),
        _kv('fs_longitude'.tr, _fmtLng(pickup?['longitude'])),
        _kv('fs_pickup_instructions'.tr, _fmt(pickup?['instructions'])),
        SizedBox(height: 8.h),
        _section('dropoff'.tr),
        _kv('fs_receiver_name'.tr, _fmt(dropoff?['receiver_name'])),
        _kv('fs_receiver_phone'.tr, _fmt(dropoff?['receiver_phone'])),
        _kv('fs_address'.tr, _fmt(dropoff?['address'])),
        _kv('fs_latitude'.tr, _fmtLat(dropoff?['latitude'])),
        _kv('fs_longitude'.tr, _fmtLng(dropoff?['longitude'])),
        _kv('fs_dropoff_instructions'.tr, _fmt(dropoff?['instructions'])),
        SizedBox(height: 8.h),
        _section('passenger'.tr),
        _kv('fs_rider_id'.tr, _fmt(rider?['id'])),
        _kv('fs_rider_name'.tr, _fmt(rider?['name'])),
        _kv('fs_rider_phone'.tr, _fmt(rider?['phone_number'])),
        _kv('fs_rider_photo'.tr, _fmt(rider?['photo'])),
        SizedBox(height: 8.h),
        _kv('fs_sender_phone'.tr, _fmt(data['sender_phone'])),
        _kv('fs_created_at'.tr, _fmt(data['created_at'])),
        _kv('fs_updated_at'.tr, _fmt(data['updated_at'])),
        _kv('fs_source_app'.tr, _fmt(data['source_app'])),
      ],
    );
  }
}

Widget _section(String title) {
  return Padding(
    padding: EdgeInsets.only(bottom: 4.h),
    child: Text(
      title,
      style: TextStyle(
        color: AppConst.black,
        fontSize: 13.sp,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

Widget _kv(String label, String value) {
  return Padding(
    padding: EdgeInsets.only(bottom: 6.h),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118.w,
          child: Text(
            label,
            style: TextStyle(
              color: AppConst.blackWithOpacity(0.55),
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: TextStyle(
              color: AppConst.black,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

String _fmt(dynamic v) {
  if (v == null) return '—';
  if (v is Timestamp) {
    return v.toDate().toLocal().toIso8601String();
  }
  return v.toString();
}

String _fmtLat(dynamic v) {
  if (v == null) return '—';
  if (v is GeoPoint) return v.latitude.toString();
  return _fmt(v);
}

String _fmtLng(dynamic v) {
  if (v == null) return '—';
  if (v is GeoPoint) return v.longitude.toString();
  return _fmt(v);
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}
