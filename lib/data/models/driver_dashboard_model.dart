/// `GET /api/app/driver/dashboard` → `data` object.
class DriverDashboardData {
  const DriverDashboardData({
    required this.isOnline,
    this.accountStatus,
    this.rating,
    this.totalTrips,
    this.earningsToday = 0,
    this.earningsWeekly = 0,
    this.earningsMonthly = 0,
  });

  final bool isOnline;
  final String? accountStatus;
  final num? rating;
  final int? totalTrips;
  final num earningsToday;
  final num earningsWeekly;
  final num earningsMonthly;

  static bool _parseBool(dynamic raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final s = raw.trim().toLowerCase();
      return s == '1' || s == 'true' || s == 'yes';
    }
    return false;
  }

  factory DriverDashboardData.fromJson(Map<String, dynamic> json) {
    final earnings = json['earnings'];
    num today = 0, weekly = 0, monthly = 0;
    if (earnings is Map) {
      final m = Map<String, dynamic>.from(earnings);
      today = (m['today'] as num?) ?? 0;
      weekly = (m['weekly'] as num?) ?? 0;
      monthly = (m['monthly'] as num?) ?? 0;
    }

    return DriverDashboardData(
      isOnline: _parseBool(json['is_online']),
      accountStatus: json['account_status']?.toString(),
      rating: json['rating'] as num?,
      totalTrips: (json['total_trips'] as num?)?.toInt(),
      earningsToday: today,
      earningsWeekly: weekly,
      earningsMonthly: monthly,
    );
  }
}
