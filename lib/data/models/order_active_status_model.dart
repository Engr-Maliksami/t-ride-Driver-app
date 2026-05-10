Map<String, dynamic>? _asJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

/// Response from `GET /api/app/rides/active-status`.
class OrderActiveStatusResponse {
  OrderActiveStatusResponse({
    this.status,
    this.hasActiveActivity,
    this.activityType,
    this.ride,
    this.courier,
    this.foodOrder,
  });

  final bool? status;
  final bool? hasActiveActivity;
  final String? activityType;
  final ActiveRideCourierOrder? ride;
  final ActiveRideCourierOrder? courier;
  final ActiveFoodOrder? foodOrder;

  factory OrderActiveStatusResponse.fromJson(Map<String, dynamic> json) {
    return OrderActiveStatusResponse(
      status: json['status'] as bool?,
      hasActiveActivity: json['has_active_activity'] as bool?,
      activityType: json['activity_type'] as String?,
      ride: ActiveRideCourierOrder.maybeFrom(json['ride']),
      courier: ActiveRideCourierOrder.maybeFrom(json['courier']),
      foodOrder: json['food_order'] != null
          ? ActiveFoodOrder.fromJson(_asJsonMap(json['food_order'])!)
          : null,
    );
  }

  bool get hasAnyOrder =>
      ride != null || courier != null || foodOrder != null;
}

/// Shared shape for `ride` and `courier` payloads.
class ActiveRideCourierOrder {
  ActiveRideCourierOrder({
    this.id,
    this.serviceType,
    this.rideCustomId,
    this.riderId,
    this.driverId,
    this.acceptedAt,
    this.receiverName,
    this.receiverPhone,
    this.packageSize,
    this.packageWeight,
    this.pickupAddress,
    this.pickupInstructions,
    this.pickupLat,
    this.pickupLng,
    this.dropoffAddress,
    this.dropoffInstructions,
    this.dropoffLat,
    this.dropoffLng,
    this.fare,
    this.paymentMethod,
    this.paymentStatus,
    this.status,
    this.driver,
  });

  final int? id;
  final String? serviceType;
  final String? rideCustomId;
  final int? riderId;
  final int? driverId;

  /// When the rider assigned / driver accepted (API or client-parsed).
  final DateTime? acceptedAt;
  final String? receiverName;
  final String? receiverPhone;
  final String? packageSize;
  final String? packageWeight;
  final String? pickupAddress;
  final String? pickupInstructions;
  final String? pickupLat;
  final String? pickupLng;
  final String? dropoffAddress;
  final String? dropoffInstructions;
  final String? dropoffLat;
  final String? dropoffLng;
  final String? fare;
  final String? paymentMethod;
  final String? paymentStatus;
  final String? status;
  final ActiveDriverSummary? driver;

  static ActiveRideCourierOrder? maybeFrom(dynamic value) {
    final map = _asJsonMap(value);
    if (map == null) return null;
    return ActiveRideCourierOrder.fromJson(map);
  }

  factory ActiveRideCourierOrder.fromJson(Map<String, dynamic> json) {
    return ActiveRideCourierOrder(
      id: (json['id'] as num?)?.toInt(),
      serviceType: json['service_type'] as String?,
      rideCustomId: json['ride_custom_id'] as String?,
      riderId: (json['rider_id'] as num?)?.toInt(),
      driverId: (json['driver_id'] as num?)?.toInt(),
      acceptedAt: _parseAcceptedAtFlexible(
        json['accepted_at'] ?? json['acceptedAt'],
      ),
      receiverName: json['receiver_name'] as String?,
      receiverPhone: json['receiver_phone'] as String?,
      packageSize: json['package_size'] as String?,
      packageWeight: json['package_weight']?.toString(),
      pickupAddress: json['pickup_address'] as String?,
      pickupInstructions: json['pickup_instructions'] as String?,
      pickupLat: json['pickup_lat']?.toString(),
      pickupLng: json['pickup_lng']?.toString(),
      dropoffAddress: json['dropoff_address'] as String?,
      dropoffInstructions: json['dropoff_instructions'] as String?,
      dropoffLat: json['dropoff_lat']?.toString(),
      dropoffLng: json['dropoff_lng']?.toString(),
      fare: json['fare']?.toString(),
      paymentMethod: json['payment_method'] as String?,
      paymentStatus: json['payment_status'] as String?,
      status: json['status'] as String?,
      driver: json['driver'] != null
          ? ActiveDriverSummary.fromJson(_asJsonMap(json['driver'])!)
          : null,
    );
  }

  static DateTime? _parseAcceptedAtFlexible(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v.toLocal();
    if (v is String) {
      final d = DateTime.tryParse(v);
      return d?.toLocal();
    }
    if (v is int) {
      return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true).toLocal();
    }
    if (v is num) {
      return DateTime.fromMillisecondsSinceEpoch(v.round(), isUtc: true)
          .toLocal();
    }
    return null;
  }
}

class ActiveDriverSummary {
  ActiveDriverSummary({
    this.id,
    this.name,
    this.driverCode,
    this.user,
  });

  final int? id;
  final String? name;
  final String? driverCode;
  final ActiveDriverUser? user;

  factory ActiveDriverSummary.fromJson(Map<String, dynamic> json) {
    final rawDriverId = json['driver_id'];
    return ActiveDriverSummary(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String?,
      driverCode: rawDriverId == null ? null : '$rawDriverId',
      user: json['user'] != null
          ? ActiveDriverUser.fromJson(_asJsonMap(json['user'])!)
          : null,
    );
  }

  String? get displayName {
    final n = name?.trim();
    if (n != null && n.isNotEmpty) return n;
    final u = user?.name?.trim();
    if (u != null && u.isNotEmpty) return u;
    return null;
  }
}

class ActiveDriverUser {
  ActiveDriverUser({
    this.id,
    this.name,
    this.phoneNumber,
  });

  final int? id;
  final String? name;
  final String? phoneNumber;

  factory ActiveDriverUser.fromJson(Map<String, dynamic> json) {
    return ActiveDriverUser(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String?,
      phoneNumber: json['phone_number'] as String?,
    );
  }
}

class ActiveFoodOrder {
  ActiveFoodOrder({
    this.id,
    this.orderCode,
    this.customerId,
    this.vendorId,
    this.driverId,
    this.categoryId,
    this.totalItems,
    this.totalAmount,
    this.deliveryFee,
    this.paymentMethod,
    this.status,
    this.deliveryAddress,
    this.deliveryLat,
    this.deliveryLng,
    this.contactPhone,
    this.deliveryInstructions,
    this.createdAt,
    this.updatedAt,
    this.vendor,
    this.items = const [],
  });

  final int? id;
  final String? orderCode;
  final int? customerId;
  final int? vendorId;
  final int? driverId;
  final int? categoryId;
  final int? totalItems;
  final String? totalAmount;
  final String? deliveryFee;
  final String? paymentMethod;
  final String? status;
  final String? deliveryAddress;
  final String? deliveryLat;
  final String? deliveryLng;
  final String? contactPhone;
  final String? deliveryInstructions;
  final String? createdAt;
  final String? updatedAt;
  final FoodVendorSummary? vendor;
  final List<FoodOrderLineItem> items;

  static ActiveFoodOrder? maybeFrom(dynamic value) {
    final map = _asJsonMap(value);
    if (map == null) return null;
    return ActiveFoodOrder.fromJson(map);
  }

  factory ActiveFoodOrder.fromJson(Map<String, dynamic> json) {
    return ActiveFoodOrder(
      id: (json['id'] as num?)?.toInt(),
      orderCode: json['order_code'] as String?,
      customerId: (json['customer_id'] as num?)?.toInt(),
      vendorId: (json['vendor_id'] as num?)?.toInt(),
      driverId: (json['driver_id'] as num?)?.toInt(),
      categoryId: (json['category_id'] as num?)?.toInt(),
      totalItems: (json['total_items'] as num?)?.toInt(),
      totalAmount: json['total_amount']?.toString(),
      deliveryFee: json['delivery_fee']?.toString(),
      paymentMethod: json['payment_method'] as String?,
      status: json['status'] as String?,
      deliveryAddress: json['delivery_address'] as String?,
      deliveryLat: json['delivery_lat']?.toString(),
      deliveryLng: json['delivery_lng']?.toString(),
      contactPhone: json['contact_phone'] as String?,
      deliveryInstructions: json['delivery_instructions'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      vendor: json['vendor'] != null
          ? FoodVendorSummary.fromJson(_asJsonMap(json['vendor'])!)
          : null,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => FoodOrderLineItem.fromJson(_asJsonMap(e)!))
              .toList() ??
          [],
    );
  }
}

class FoodVendorSummary {
  FoodVendorSummary({
    this.id,
    this.name,
    this.logo,
    this.address,
    this.latitude,
    this.longitude,
  });

  final int? id;
  final String? name;
  final String? logo;
  final String? address;
  /// When API includes vendor coords (e.g. `latitude` / `longitude`).
  final String? latitude;
  final String? longitude;

  factory FoodVendorSummary.fromJson(Map<String, dynamic> json) {
    return FoodVendorSummary(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String?,
      logo: json['logo'] as String?,
      address: json['address'] as String?,
      latitude: json['latitude']?.toString() ??
          json['lat']?.toString() ??
          json['vendor_lat']?.toString(),
      longitude: json['longitude']?.toString() ??
          json['lng']?.toString() ??
          json['long']?.toString() ??
          json['vendor_lng']?.toString(),
    );
  }
}

class FoodOrderLineItem {
  FoodOrderLineItem({
    this.id,
    this.productName,
    this.quantity,
    this.total,
    this.unitPrice,
    this.specialInstructions,
    this.product,
  });

  final int? id;
  final String? productName;
  final int? quantity;
  final String? total;
  final String? unitPrice;
  final String? specialInstructions;
  final FoodLineProductRef? product;

  factory FoodOrderLineItem.fromJson(Map<String, dynamic> json) {
    return FoodOrderLineItem(
      id: (json['id'] as num?)?.toInt(),
      productName: json['product_name'] as String?,
      quantity: (json['quantity'] as num?)?.toInt(),
      total: json['total']?.toString(),
      unitPrice: json['unit_price']?.toString(),
      specialInstructions: json['special_instructions'] as String?,
      product: json['product'] != null
          ? FoodLineProductRef.fromJson(_asJsonMap(json['product'])!)
          : null,
    );
  }
}

/// Nested `product` on a line item (catalog name / list price).
class FoodLineProductRef {
  FoodLineProductRef({this.id, this.name, this.price});

  final int? id;
  final String? name;
  final String? price;

  factory FoodLineProductRef.fromJson(Map<String, dynamic> json) {
    return FoodLineProductRef(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String?,
      price: json['price']?.toString(),
    );
  }
}
