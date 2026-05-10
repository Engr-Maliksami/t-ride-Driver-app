import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:t_rider_services_app/data/models/order_active_status_model.dart';

/// A newly added Firestore `active_*` document surfaced only on the full map UI.
class NearbyOrderMapOffer {
  NearbyOrderMapOffer({
    required this.docId,
    required this.collection,
    required this.mapped,
    required this.raw,
  });

  final String docId;
  final String collection;
  final ActiveRideCourierOrder mapped;
  final Map<String, dynamic> raw;

  String get docKey => '$collection:$docId';

  bool get isCourier => collection == 'active_courier';

  Map<String, dynamic>? get _pickupRaw {
    final p = raw['pickup'];
    if (p is Map<String, dynamic>) return p;
    if (p is Map) return Map<String, dynamic>.from(p);
    return null;
  }

  Map<String, dynamic>? get _dropoffRaw {
    final p = raw['dropoff'];
    if (p is Map<String, dynamic>) return p;
    if (p is Map) return Map<String, dynamic>.from(p);
    return null;
  }

  Map<String, dynamic>? get _riderRaw {
    final p = raw['rider'];
    if (p is Map<String, dynamic>) return p;
    if (p is Map) return Map<String, dynamic>.from(p);
    return null;
  }

  String pickupAddressShort() =>
      _pickupRaw?['address']?.toString().trim().isNotEmpty == true
          ? _pickupRaw!['address'].toString()
          : '';

  String destinationTitle() =>
      _dropoffRaw?['address']?.toString().trim().isNotEmpty == true
          ? _dropoffRaw!['address'].toString()
          : '';

  /// Display name shown on the Uber-style rider row (first name preference).
  String riderDisplayName() {
    final rider = _riderRaw;
    final n = rider?['name']?.toString().trim();
    if (n != null && n.isNotEmpty) {
      final parts = n.split(RegExp(r'\s+'));
      return parts.isNotEmpty ? parts.first : n;
    }
    return mapped.receiverName?.trim().isNotEmpty == true
        ? mapped.receiverName!.trim()
        : '—';
  }

  double? riderRatingStars() {
    final r = _riderRaw?['rating'] ?? raw['passenger_rating'] ?? raw['rider_rating'];
    if (r == null) return null;
    if (r is num) return r.toDouble();
    return double.tryParse(r.toString());
  }

  DateTime? scheduledOrCreatedLocal() {
    final pick = _pickupRaw;
    dynamic t =
        pick?['scheduled_at'] ??
        pick?['pickup_time'] ??
        raw['scheduled_pickup_at'] ??
        raw['created_at'];
    if (t == null) return null;
    if (t is Timestamp) return t.toDate().toLocal();
    return null;
  }

  /// Optional bonus/discount dollar amount shown in green (Firestore key varies).
  String? formattedBonusUsd() {
    for (final k in const ['bonus_amount', 'fare_bonus', 'bonus', 'driver_bonus']) {
      final v = raw[k];
      if (v == null) continue;
      if (v is num) return v.toDouble().toStringAsFixed(2);
      final parsed = double.tryParse(v.toString());
      if (parsed != null) return parsed.toStringAsFixed(2);
    }
    return null;
  }

  /// Total fare displayed large (prefer Firestore fare over mapped string).
  String formattedFareUsd() {
    final f = raw['fare'] ?? raw['estimated_fare'] ?? mapped.fare;
    if (f == null) return '—';
    final s = f.toString().trim();
    if (s.isEmpty) return '—';
    if (s.startsWith(r'$')) return s;
    final n = double.tryParse(s.replaceAll(',', ''));
    if (n != null) return '\$${n.toStringAsFixed(2)}';
    return '\$$s';
  }
}
