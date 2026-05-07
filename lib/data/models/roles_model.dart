class Roles {
  Roles({this.status, this.roles});

  final bool? status;
  final List<Role>? roles;

  Roles copyWith({bool? status, List<Role>? roles}) =>
      Roles(status: status ?? this.status, roles: roles ?? this.roles);

  factory Roles.fromJson(Map<String, dynamic> json) {
    final rawList = (json['data'] ?? json['roles']) as List<dynamic>? ?? [];
    return Roles(
      status: json['status'] as bool?,
      roles: rawList
          .whereType<Map<String, dynamic>>()
          .map(Role.fromJson)
          .toList(),
    );
  }
}

class Role {
  Role({
    this.id,
    this.name,
    this.guardName,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String? name;
  final String? guardName;
  final String? createdAt;
  final String? updatedAt;

  Role copyWith({
    int? id,
    String? name,
    String? guardName,
    String? createdAt,
    String? updatedAt,
  }) =>
      Role(
        id: id ?? this.id,
        name: name ?? this.name,
        guardName: guardName ?? this.guardName,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory Role.fromJson(Map<String, dynamic> json) => Role(
        id: (json['id'] as num?)?.toInt(),
        name: json['name'] as String?,
        guardName: json['guard_name'] as String?,
        createdAt: json['created_at'] as String?,
        updatedAt: json['updated_at'] as String?,
      );
}

