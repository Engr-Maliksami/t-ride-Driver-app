import 'dart:convert';

class RentalItemsDetails {
  bool? status;
  Data? data;

  RentalItemsDetails({this.status, this.data});

  RentalItemsDetails copyWith({bool? status, Data? data}) => RentalItemsDetails(
    status: status ?? this.status,
    data: data ?? this.data,
  );

  factory RentalItemsDetails.fromJson(Map<String, dynamic> json) =>
      RentalItemsDetails(
        status: json['status'] as bool?,
        data: json['data'] == null
            ? null
            : Data.fromJson(json['data'] as Map<String, dynamic>),
      );

  static RentalItemsDetails fromJsonString(String source) =>
      RentalItemsDetails.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

class Data {
  int? id;
  String? name;
  String? category;
  String? description;
  String? price;
  String? priceUnit;
  String? location;
  List<String>? images;
  Features? features;
  String? status;
  String? createdAt;
  String? updatedAt;

  Data({
    this.id,
    this.name,
    this.category,
    this.description,
    this.price,
    this.priceUnit,
    this.location,
    this.images,
    this.features,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  Data copyWith({
    int? id,
    String? name,
    String? category,
    String? description,
    String? price,
    String? priceUnit,
    String? location,
    List<String>? images,
    Features? features,
    String? status,
    String? createdAt,
    String? updatedAt,
  }) => Data(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    description: description ?? this.description,
    price: price ?? this.price,
    priceUnit: priceUnit ?? this.priceUnit,
    location: location ?? this.location,
    images: images ?? this.images,
    features: features ?? this.features,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory Data.fromJson(Map<String, dynamic> json) => Data(
    id: json['id'] as int?,
    name: json['name'] as String?,
    category: json['category'] as String?,
    description: json['description'] as String?,
    price: json['price']?.toString(),
    priceUnit: json['price_unit']?.toString(),
    location: json['location'] as String?,
    images: (json['images'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList(),
    features: json['features'] is Map<String, dynamic>
        ? Features.fromJson(json['features'] as Map<String, dynamic>)
        : null,
    status: json['status'] as String?,
    createdAt: json['created_at'] as String?,
    updatedAt: json['updated_at'] as String?,
  );
}

class Features {
  String? safety;
  bool? sunroof;
  bool? cruiseControl;

  Features({this.safety, this.sunroof, this.cruiseControl});

  Features copyWith({String? safety, bool? sunroof, bool? cruiseControl}) =>
      Features(
        safety: safety ?? this.safety,
        sunroof: sunroof ?? this.sunroof,
        cruiseControl: cruiseControl ?? this.cruiseControl,
      );

  factory Features.fromJson(Map<String, dynamic> json) => Features(
    safety: json['safety']?.toString(),
    sunroof: _toBool(json['sunroof']),
    cruiseControl: _toBool(json['cruise_control']),
  );

  static bool? _toBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    final v = value.toString().toLowerCase();
    if (v == 'true' || v == '1') return true;
    if (v == 'false' || v == '0') return false;
    return null;
  }
}
