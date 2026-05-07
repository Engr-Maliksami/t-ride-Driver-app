import 'dart:convert';

class RentalItems {
  bool? status;
  List<Datum>? data;

  RentalItems({this.status, this.data});

  RentalItems copyWith({bool? status, List<Datum>? data}) =>
      RentalItems(status: status ?? this.status, data: data ?? this.data);

  factory RentalItems.fromJson(Map<String, dynamic> json) => RentalItems(
    status: json['status'] as bool?,
    data: (json['data'] as List<dynamic>?)
        ?.map((e) => Datum.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  static RentalItems fromJsonString(String source) =>
      RentalItems.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

class Datum {
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

  Datum({
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

  Datum copyWith({
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
  }) => Datum(
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

  factory Datum.fromJson(Map<String, dynamic> json) => Datum(
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
  bool? ac;
  String? fuel;
  String? transmission;

  Features({
    this.safety,
    this.sunroof,
    this.cruiseControl,
    this.ac,
    this.fuel,
    this.transmission,
  });

  Features copyWith({
    String? safety,
    bool? sunroof,
    bool? cruiseControl,
    bool? ac,
    String? fuel,
    String? transmission,
  }) => Features(
    safety: safety ?? this.safety,
    sunroof: sunroof ?? this.sunroof,
    cruiseControl: cruiseControl ?? this.cruiseControl,
    ac: ac ?? this.ac,
    fuel: fuel ?? this.fuel,
    transmission: transmission ?? this.transmission,
  );

  factory Features.fromJson(Map<String, dynamic> json) => Features(
    safety: json['safety']?.toString(),
    sunroof: _toBool(json['sunroof']),
    cruiseControl: _toBool(json['cruise_control']),
    ac: _toBool(json['ac']),
    fuel: json['fuel']?.toString(),
    transmission: json['transmission']?.toString(),
  );

  static bool? _toBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    final str = value.toString().toLowerCase();
    if (str == 'true' || str == '1') return true;
    if (str == 'false' || str == '0') return false;
    return null;
  }
}
