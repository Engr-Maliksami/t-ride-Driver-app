import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:t_rider_services_app/data/local/secure_storage_service.dart';
import 'package:t_rider_services_app/data/firestore/firestore_active_order_mapper.dart';
import 'package:t_rider_services_app/data/firestore/firestore_nearby_helper.dart';
import 'package:t_rider_services_app/models/nearby_order_map_offer.dart';
import 'package:t_rider_services_app/views/home/navbar.dart';
import 'package:t_rider_services_app/views/home/finding_ride_requests_screen.dart';
import 'package:t_rider_services_app/views/widgets/app_snackbar.dart';

/// Listens to `active_rides` / `active_courier` and surfaces nearby new orders **only**
/// via [foregroundMapOffer] (consumers: [FullScreenDashboardMapScreen], etc.).
///
/// Does **not** show app-wide dialogs. Drivers see the animated bottom sheet only
/// while the fullscreen map route is visible.
///
/// Nearby filter uses [FirestoreNearbyHelper.isPickupWithinRange].
class FirestoreActiveOrdersListener extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SecureStorageService _storageService = SecureStorageService();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ridesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _courierSub;

  final List<NearbyOrderMapOffer> _offerQueue = [];

  /// Offer currently shown as the draggable sheet on the map (if any).
  final Rxn<NearbyOrderMapOffer> foregroundMapOffer = Rxn<NearbyOrderMapOffer>();

  /// Firestore listeners run app-wide; only surface orders when logged in.
  Future<bool> _hasActiveSession() async {
    final token = await _storageService.getAuthToken();
    return token != null && token.trim().isNotEmpty;
  }

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

  /// User dismissed sheet or tapped cancel.
  void dismissCurrentForegroundOffer() {
    final cur = foregroundMapOffer.value;
    if (cur == null) return;
    removeOffersForDocKey(cur.docKey);
  }

  /// Navigating to accepting flow consumes the surfaced offer.
  void consumeCurrentForegroundOffer() {
    dismissCurrentForegroundOffer();
  }

  /// Removes queued + foreground instances of this composite key (`collection:id`).
  void removeOffersForDocKey(String docKey) {
    _offerQueue.removeWhere((o) => o.docKey == docKey);
    if (foregroundMapOffer.value?.docKey == docKey) {
      foregroundMapOffer.value =
          _offerQueue.isEmpty ? null : _offerQueue.removeAt(0);
    }
  }

  void _enqueueOffer(NearbyOrderMapOffer offer) {
    final exists = foregroundMapOffer.value?.docKey == offer.docKey ||
        _offerQueue.any((o) => o.docKey == offer.docKey);
    if (exists) return;

    if (foregroundMapOffer.value == null) {
      foregroundMapOffer.value = offer;
      return;
    }
    _offerQueue.add(offer);
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
          if (change.type == DocumentChangeType.removed) {
            removeOffersForDocKey('active_rides:${change.doc.id}');
            continue;
          }
          if (change.type == DocumentChangeType.modified) {
            _removeMapOfferIfDocAccepted(change.doc, isCourier: false);
            unawaited(_handleAcceptedUpdate(change.doc, isCourier: false));
          }
          final isNewOrUpdated = change.type == DocumentChangeType.added ||
              change.type == DocumentChangeType.modified;
          if (isNewOrUpdated) {
            unawaited(_trySurfaceRideOffer(change.doc));
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
          if (change.type == DocumentChangeType.removed) {
            removeOffersForDocKey('active_courier:${change.doc.id}');
            continue;
          }
          if (change.type == DocumentChangeType.modified) {
            _removeMapOfferIfDocAccepted(change.doc, isCourier: true);
            unawaited(_handleAcceptedUpdate(change.doc, isCourier: true));
          }
          final isNewOrUpdated = change.type == DocumentChangeType.added ||
              change.type == DocumentChangeType.modified;
          if (isNewOrUpdated) {
            unawaited(_trySurfaceCourierOffer(change.doc));
          }
        }
      },
      onError: (_) {},
    );
  }

  void _removeMapOfferIfDocAccepted(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required bool isCourier,
  }) {
    final data = doc.data();
    if (data == null) return;

    final raw = data['accepted_by_user_id'];
    if (raw == null) return;

    final acceptedBy = raw is int
        ? raw
        : raw is num
            ? raw.toInt()
            : int.tryParse(raw.toString());
    if (acceptedBy == null) return;

    final collection = isCourier ? 'active_courier' : 'active_rides';
    removeOffersForDocKey('$collection:${doc.id}');
  }

  /// Drops surfaced / queued offers whose Firestore documents were deleted (no `removed` event yet).
  Future<void> pruneStaleSurfacedOffers() async {
    final keys = <String>{
      if (foregroundMapOffer.value != null) foregroundMapOffer.value!.docKey,
      ..._offerQueue.map((o) => o.docKey),
    };
    for (final docKey in keys) {
      final sep = docKey.indexOf(':');
      if (sep <= 0 || sep >= docKey.length - 1) continue;
      final collection = docKey.substring(0, sep);
      final id = docKey.substring(sep + 1);
      if (collection != 'active_rides' && collection != 'active_courier') {
        continue;
      }
      try {
        final snap = await _db.collection(collection).doc(id).get();
        if (!snap.exists) {
          removeOffersForDocKey(docKey);
        }
      } catch (_) {}
    }
  }

  /// One-shot catch-up (e.g. fullscreen map opens) plus stream gaps / `modified`-only docs.
  Future<void> syncPendingNearbyOffers() async {
    if (!await _hasActiveSession()) return;
    await pruneStaleSurfacedOffers();
    final me = await FirestoreNearbyHelper.tryDriverReferencePoint();
    if (me == null) return;

    Future<void> scan(
      QuerySnapshot<Map<String, dynamic>> snap,
      NearbyOrderMapOffer Function(String id, Map<String, dynamic> d) wrap,
    ) async {
      for (final doc in snap.docs) {
        final data = doc.data();
        if (!FirestoreNearbyHelper.isEligibleOpenOffer(data)) continue;
        final meters = FirestoreNearbyHelper.distanceMetersToPickupFromCoords(
          data,
          me.lat,
          me.lng,
        );
        if (meters == null ||
            meters > FirestoreNearbyHelper.maxRangeMeters) {
          continue;
        }
        _enqueueOffer(wrap(doc.id, Map<String, dynamic>.from(data)));
      }
    }

    try {
      final rides = await _db.collection('active_rides').get();
      await scan(
        rides,
        (id, data) => NearbyOrderMapOffer(
          docId: id,
          collection: 'active_rides',
          mapped: FirestoreActiveOrderMapper.activeRideToModel(id, data),
          raw: data,
        ),
      );
    } catch (_) {}

    try {
      final courier = await _db.collection('active_courier').get();
      await scan(
        courier,
        (id, data) => NearbyOrderMapOffer(
          docId: id,
          collection: 'active_courier',
          mapped: FirestoreActiveOrderMapper.activeCourierToModel(id, data),
          raw: data,
        ),
      );
    } catch (_) {}
  }

  Future<void> _trySurfaceRideOffer(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    if (!await _hasActiveSession()) return;
    final data = doc.data();
    if (data == null) return;

    if (!FirestoreNearbyHelper.isEligibleOpenOffer(data)) return;

    if (!await FirestoreNearbyHelper.isPickupWithinRange(data)) return;

    final mapped = FirestoreActiveOrderMapper.activeRideToModel(doc.id, data);
    _enqueueOffer(
      NearbyOrderMapOffer(
        docId: doc.id,
        collection: 'active_rides',
        mapped: mapped,
        raw: Map<String, dynamic>.from(data),
      ),
    );
  }

  Future<void> _trySurfaceCourierOffer(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    if (!await _hasActiveSession()) return;
    final data = doc.data();
    if (data == null) return;

    if (!FirestoreNearbyHelper.isEligibleOpenOffer(data)) return;

    if (!await FirestoreNearbyHelper.isPickupWithinRange(data)) return;

    final mapped = FirestoreActiveOrderMapper.activeCourierToModel(doc.id, data);
    _enqueueOffer(
      NearbyOrderMapOffer(
        docId: doc.id,
        collection: 'active_courier',
        mapped: mapped,
        raw: Map<String, dynamic>.from(data),
      ),
    );
  }

  Future<void> _handleAcceptedUpdate(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required bool isCourier,
  }) async {
    if (!await _hasActiveSession()) return;
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
    removeOffersForDocKey(docKey);

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
}
