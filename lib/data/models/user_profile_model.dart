class UserProfileResponse {
  UserProfileResponse({this.status, this.user});

  final bool? status;
  final UserProfile? user;

  factory UserProfileResponse.fromJson(Map<String, dynamic> json) {
    return UserProfileResponse(
      status: json['status'] as bool?,
      user: json['user'] != null
          ? UserProfile.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}

class UserProfile {
  UserProfile({
    this.id,
    this.name,
    this.email,
    this.phoneNumber,
    this.whatsappNumber,
    this.address,
    this.city,
    this.lat,
    this.lng,
    this.languageId,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.walletBalance,
    this.roles,
    this.photo,
  });

  final int? id;
  final String? name;
  final String? email;
  final String? phoneNumber;
  final String? whatsappNumber;
  final String? address;
  final String? city;
  final double? lat;
  final double? lng;
  final int? languageId;
  final String? status;
  final String? createdAt;
  final String? updatedAt;
  final String? walletBalance;
  final List<UserRole>? roles;
  final String? photo;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String?,
      email: json['email'] as String?,
      phoneNumber: json['phone_number'] as String?,
      whatsappNumber: json['whatsapp_number'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      languageId: (json['language_id'] as num?)?.toInt(),
      status: json['status'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      walletBalance: json['wallet_balance'] as String?,
      photo: json['photo'] as String?,
      roles: (json['roles'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(UserRole.fromJson)
              .toList() ??
          [],
    );
  }
}

class UserRole {
  UserRole({
    this.id,
    this.name,
    this.guardName,
    this.createdAt,
    this.updatedAt,
    this.pivot,
  });

  final int? id;
  final String? name;
  final String? guardName;
  final String? createdAt;
  final String? updatedAt;
  final RolePivot? pivot;

  factory UserRole.fromJson(Map<String, dynamic> json) {
    return UserRole(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String?,
      guardName: json['guard_name'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      pivot: json['pivot'] != null
          ? RolePivot.fromJson(json['pivot'] as Map<String, dynamic>)
          : null,
    );
  }
}

class RolePivot {
  RolePivot({
    this.modelType,
    this.modelId,
    this.roleId,
  });

  final String? modelType;
  final int? modelId;
  final int? roleId;

  factory RolePivot.fromJson(Map<String, dynamic> json) {
    return RolePivot(
      modelType: json['model_type'] as String?,
      modelId: (json['model_id'] as num?)?.toInt(),
      roleId: (json['role_id'] as num?)?.toInt(),
    );
  }
}

