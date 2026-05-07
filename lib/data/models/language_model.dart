/// Represents a language from the API.
/// Response shape: { status, message, data: [{ id, name, code, flag, status, ... }] }
class LanguageModel {
  const LanguageModel({
    required this.id,
    required this.name,
    required this.code,
    required this.flag,
    this.status = 1,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String code;
  final String flag;
  final int status;
  final String? createdAt;
  final String? updatedAt;

  factory LanguageModel.fromJson(Map<String, dynamic> json) {
    return LanguageModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      code: (json['code'] as String?) ?? '',
      flag: (json['flag'] as String?) ?? '',
      status: (json['status'] as num?)?.toInt() ?? 1,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  /// Parses API data array. Filters to active languages (status == 1).
  static List<LanguageModel> fromJsonList(dynamic data) {
    if (data == null) return [];
    if (data is! List) return [];
    return data
        .map((e) => e is Map<String, dynamic> ? LanguageModel.fromJson(e) : null)
        .whereType<LanguageModel>()
        .where((l) => l.status == 1)
        .toList();
  }
}
