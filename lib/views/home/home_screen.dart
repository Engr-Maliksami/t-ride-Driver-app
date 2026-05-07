import 'dart:developer' show log;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:t_rider_services_app/controllers/app_language_controller.dart';
import 'package:t_rider_services_app/consts/appConst.dart';
import 'package:t_rider_services_app/config/api_urls.dart';
import 'package:t_rider_services_app/data/local/secure_storage_service.dart';
import 'package:t_rider_services_app/data/repositories/rider_status_repository.dart';
import 'package:t_rider_services_app/data/repositories/profile_repository.dart';
import 'package:t_rider_services_app/views/home/setting/setting_screen.dart';
import 'package:t_rider_services_app/views/home/nearby_firestore_orders_screen.dart';
import 'package:t_rider_services_app/views/home/widgets/active_orders_section.dart';
import 'package:t_rider_services_app/views/widgets/app_snackbar.dart';
import 'package:t_rider_services_app/views/home/widgets/service_mode_tiles_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final RiderStatusRepository _riderStatusRepository = RiderStatusRepository();
  final ProfileRepository _profileRepository = ProfileRepository();
  final SecureStorageService _secureStorageService = SecureStorageService();
  final AppLanguageController _appLanguageController =
      Get.find<AppLanguageController>();
  bool _isOnline = false;
  bool _onlineStatusLoading = true;
  bool _togglingOnline = false;
  num? _driverRating;
  int? _totalTrips;
  num? _earningsToday;
  num? _earningsWeekly;
  num? _earningsMonthly;
  String? _userName;
  String? _userPhotoUrl;
  String _carModel = '';
  String _carPlate = '';
  bool _profileLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _locationLabel = '';
  bool _locationLoading = true;
  LatLng? _userLatLng;
  GoogleMapController? _mapController;
  bool get _isDarkMode => AppConst.isDarkMode;
  Color get _cardBackground =>
      _isDarkMode ? const Color(0xFFEFEFEF) : AppConst.white;
  Color get _screenBackground => AppConst.scaffoldBackground;
  Color get _headerBackground => AppConst.brandedHeader;
  Color get _primaryTextColor => Colors.black;
  Color _textWithOpacity(double opacity) =>
      _primaryTextColor.withValues(alpha: opacity);
  bool get _hasCarInfo =>
      _carModel.trim().isNotEmpty || _carPlate.trim().isNotEmpty;

  static const LatLng _defaultMapCenter = LatLng(6.5244, 3.3792);

  @override
  void initState() {
    super.initState();
    _loadDriverDashboard();
    _loadProfileHeader();
    _loadLocalCarInfo();
    _fetchUserLocation();
  }

  Future<void> _loadLocalCarInfo() async {
    try {
      final carInfo = await _secureStorageService.getCarInfo();
      if (!mounted) return;
      setState(() {
        _carModel = (carInfo['model'] ?? '').trim();
        _carPlate = (carInfo['plateNumber'] ?? '').trim();
      });
    } catch (_) {
      // ignore; car info is optional local data
    }
  }

  Future<void> _loadProfileHeader() async {
    setState(() {
      _profileLoading = true;
    });
    try {
      final profile = await _profileRepository.getProfile();
      if (!mounted) return;
      setState(() {
        _userName = profile.name ?? '—';
        _userPhotoUrl = profile.photo;
      });

      // If backend provides lat/lng, use it only as a temporary fallback label.
      final lat = profile.lat;
      final lng = profile.lng;
      if (lat != null && lng != null) {
        final userLatLng = LatLng(lat, lng);
        final label = await _reverseGeocodeLabel(lat, lng);
        if (!mounted) return;
        setState(() {
          _userLatLng ??= userLatLng;
          if (_locationLabel.isEmpty) {
            _locationLabel = label;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _userName = _userName ?? '—';
        _profileLoading = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _profileLoading = false;
        });
      }
    }
  }

  Future<String> _reverseGeocodeLabel(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final street = (p.street?.isNotEmpty == true)
            ? p.street
            : (p.name?.isNotEmpty == true ? p.name : null);
        final city = p.locality;
        final state = p.administrativeArea;
        final country = p.country;

        final parts = <String>[];
        if (street != null && street.isNotEmpty) parts.add(street);
        if (city != null && city.isNotEmpty && !parts.contains(city)) {
          parts.add(city);
        }
        if (state != null && state.isNotEmpty && !parts.contains(state)) {
          parts.add(state);
        }
        if (country != null && country.isNotEmpty && !parts.contains(country)) {
          parts.add(country);
        }

        if (parts.length > 3) return parts.sublist(0, 3).join(', ');
        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (_) {
      // ignore; fallback below
    }
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  Future<void> _fetchUserLocation() async {
    setState(() {
      _locationLoading = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _locationLoading = false;
          _locationLabel = 'location_services_off'.tr;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _locationLoading = false;
          _locationLabel = 'location_permission_needed'.tr;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      final userLatLng = LatLng(position.latitude, position.longitude);

      String label;
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final street = (p.street?.isNotEmpty == true)
              ? p.street
              : (p.name?.isNotEmpty == true ? p.name : null);
          final city = p.locality;
          final state = p.administrativeArea;
          final country = p.country;

          final parts = <String>[];
          if (street != null && street.isNotEmpty) parts.add(street);
          if (city != null && city.isNotEmpty && !parts.contains(city)) {
            parts.add(city);
          }
          if (state != null && state.isNotEmpty && !parts.contains(state)) {
            parts.add(state);
          }
          if (country != null &&
              country.isNotEmpty &&
              !parts.contains(country)) {
            parts.add(country);
          }

          if (parts.length > 3) {
            label = parts.sublist(0, 3).join(', ');
          } else if (parts.isNotEmpty) {
            label = parts.join(', ');
          } else {
            label =
                '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
          }
        } else {
          label =
              '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        }
      } catch (_) {
        label =
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }

      if (!mounted) return;
      setState(() {
        _locationLoading = false;
        _locationLabel = label;
        _userLatLng = userLatLng;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(userLatLng, 14));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationLoading = false;
        if (_locationLabel.isEmpty) {
          _locationLabel = 'could_not_get_location'.tr;
        }
      });
    }
  }

  LatLng get _mapTarget => _userLatLng ?? _defaultMapCenter;

  /// Star row for 0–5 scale (dashboard [rating]).
  Widget _ratingStarsRow(double value) {
    final v = value.clamp(0.0, 5.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final idx = i + 1;
        IconData icon;
        Color color;
        if (v >= idx) {
          icon = Icons.star_rounded;
          color = _primaryTextColor;
        } else if (v > i) {
          icon = Icons.star_half_rounded;
          color = _primaryTextColor;
        } else {
          icon = Icons.star_outline_rounded;
          color = _textWithOpacity(0.22);
        }
        return Padding(
          padding: EdgeInsets.only(right: i < 4 ? 2.w : 0),
          child: Icon(icon, size: 18.sp, color: color),
        );
      }),
    );
  }

  Widget _buildDriverRatingCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: AppConst.borderRadius,
        boxShadow: [
          BoxShadow(
            color: _textWithOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _onlineStatusLoading
          ? Row(
              children: [
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: _textWithOpacity(0.06),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12.h,
                        width: 100.w,
                        decoration: BoxDecoration(
                          color: _textWithOpacity(0.08),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Container(
                        height: 22.h,
                        width: 72.w,
                        decoration: BoxDecoration(
                          color: _textWithOpacity(0.06),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52.w,
                  height: 52.w,
                  decoration: BoxDecoration(
                    color: AppConst.primaryColorWithOpacity(0.35),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Icon(
                    Icons.star_rounded,
                    color: _primaryTextColor,
                    size: 30.sp,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'your_rating'.tr,
                              style: TextStyle(
                                color: _textWithOpacity(0.5),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          if (_hasCarInfo) ...[
                            Container(
                              constraints: BoxConstraints(maxWidth: 180.w),
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppConst.primaryColorWithOpacity(0.28),
                                borderRadius: BorderRadius.circular(999.r),
                                border: Border.all(
                                  color: AppConst.primaryColorWithOpacity(0.55),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.directions_car_filled_rounded,
                                    color: _primaryTextColor,
                                    size: 13.sp,
                                  ),
                                  SizedBox(width: 4.w),
                                  Flexible(
                                    child: Text(
                                      [
                                        if (_carModel.isNotEmpty) _carModel,
                                        if (_carPlate.isNotEmpty) _carPlate,
                                      ].join(' • '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _primaryTextColor,
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 6.h),
                      if (_driverRating != null) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              _driverRating!.toDouble().toStringAsFixed(1),
                              style: TextStyle(
                                color: _primaryTextColor,
                                fontSize: 28.sp,
                                fontWeight: FontWeight.w800,
                                height: 1.05,
                              ),
                            ),
                            Text(
                              ' / 5',
                              style: TextStyle(
                                color: _textWithOpacity(0.45),
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_totalTrips != null) ...[
                              SizedBox(width: 10.w),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  color: _textWithOpacity(0.06),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Text(
                                  _totalTrips! == 1
                                      ? '1 ${'trip'.tr}'
                                      : '${_totalTrips!} ${'trips'.tr}',
                                  style: TextStyle(
                                    color: _textWithOpacity(0.65),
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 8.h),
                        _ratingStarsRow(_driverRating!.toDouble()),
                        if (_driverRating == 0) ...[
                          SizedBox(height: 8.h),
                          Text(
                            'complete_trips_to_earn_reviews'.tr,
                            style: TextStyle(
                              color: _textWithOpacity(0.42),
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ] else ...[
                        Text(
                          'unavailable'.tr,
                          style: TextStyle(
                            color: _textWithOpacity(0.45),
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'switch_tab_retry'.tr,
                          style: TextStyle(
                            color: _textWithOpacity(0.45),
                            fontSize: 12.sp,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  String _formatEarningsAmount(num n) => n.toDouble().toStringAsFixed(2);

  Widget _buildEarningsStatCell(String label, num amount) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _textWithOpacity(0.48),
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            _formatEarningsAmount(amount),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _primaryTextColor,
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 16.h),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: AppConst.borderRadius,
        boxShadow: [
          BoxShadow(
            color: _textWithOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(9.r),
                decoration: BoxDecoration(
                  color: AppConst.primaryColorWithOpacity(0.35),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(
                  Icons.payments_outlined,
                  color: _primaryTextColor,
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                'earnings'.tr,
                style: TextStyle(
                  color: _primaryTextColor,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (_onlineStatusLoading)
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48.h,
                    decoration: BoxDecoration(
                      color: _textWithOpacity(0.06),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Container(
                    height: 48.h,
                    decoration: BoxDecoration(
                      color: _textWithOpacity(0.06),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Container(
                    height: 48.h,
                    decoration: BoxDecoration(
                      color: _textWithOpacity(0.06),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                ),
              ],
            )
          else if (_earningsToday != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEarningsStatCell('today'.tr, _earningsToday!),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.w),
                  child: SizedBox(
                    height: 44.h,
                    child: VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: _textWithOpacity(0.08),
                    ),
                  ),
                ),
                _buildEarningsStatCell('this_week'.tr, _earningsWeekly!),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.w),
                  child: SizedBox(
                    height: 44.h,
                    child: VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: _textWithOpacity(0.08),
                    ),
                  ),
                ),
                _buildEarningsStatCell('this_month'.tr, _earningsMonthly!),
              ],
            )
          else
            Text(
              'earnings_unavailable_retry'.tr,
              style: TextStyle(
                color: _textWithOpacity(0.45),
                fontSize: 12.sp,
                height: 1.35,
              ),
            ),
        ],
      ),
    );
  }

  Set<Marker> _nearbyRideMarkers() {
    const rideHue = BitmapDescriptor.hueYellow;
    final center = _mapTarget;
    final offsets = <List<double>>[
      [0.004, 0.002],
      [-0.0032, 0.0048],
      [0.0025, -0.004],
      [-0.0045, -0.0025],
      [0.001, 0.006],
    ];
    return {
      for (var i = 0; i < offsets.length; i++)
        Marker(
          markerId: MarkerId('ride_$i'),
          position: LatLng(
            center.latitude + offsets[i][0],
            center.longitude + offsets[i][1],
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(rideHue),
          infoWindow: InfoWindow(
            title: 'Ride nearby',
            snippet: 'Placeholder • ~${i + 2} min',
          ),
        ),
    };
  }

  /// Call when the Home tab becomes active again (see [Navbar]).
  Future<void> refreshDashboard() => _loadDriverDashboard(silent: true);

  /// Online status comes from `GET /api/app/driver/dashboard` only (not local storage).
  Future<void> _loadDriverDashboard({bool silent = false}) async {
    if (!silent) {
      setState(() => _onlineStatusLoading = true);
    }
    try {
      final dash = await _riderStatusRepository.fetchDriverDashboard();
      if (!mounted) return;
      setState(() {
        _isOnline = dash.isOnline;
        _driverRating = dash.rating ?? 0;
        _totalTrips = dash.totalTrips;
        _earningsToday = dash.earningsToday;
        _earningsWeekly = dash.earningsWeekly;
        _earningsMonthly = dash.earningsMonthly;
        _onlineStatusLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isOnline = false;
        if (!silent) {
          _driverRating = null;
          _totalTrips = null;
          _earningsToday = null;
          _earningsWeekly = null;
          _earningsMonthly = null;
        }
        _onlineStatusLoading = false;
      });
      AppSnackbar.showApiError(
        e,
        fallbackMessage: 'could_not_load_driver_dashboard'.tr,
      );
    }
  }

  Future<void> _onOnlineChanged(bool value) async {
    if (_onlineStatusLoading || _togglingOnline) {
      log(
        'toggle ignored: _onlineStatusLoading=$_onlineStatusLoading '
        '_togglingOnline=$_togglingOnline',
        name: 'HomeScreen.online',
      );
      return;
    }
    final previous = _isOnline;
    setState(() {
      _isOnline = value;
      _togglingOnline = true;
    });
    log(
      'calling updateOnlineStatus isOnline=$value',
      name: 'HomeScreen.online',
    );
    try {
      final responseBody = await _riderStatusRepository.updateOnlineStatus(
        isOnline: value,
      );
      log(
        'updateOnlineStatus success: $responseBody',
        name: 'HomeScreen.online',
      );
      if (!mounted) return;
      setState(() => _togglingOnline = false);
    } catch (e, st) {
      log(
        'updateOnlineStatus failed',
        name: 'HomeScreen.online',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() {
        _isOnline = previous;
        _togglingOnline = false;
      });
      AppSnackbar.showApiError(
        e,
        fallbackMessage: 'could_not_update_availability'.tr,
      );
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBackground,
      body: Column(
        children: [
          // Top Section - Dark Theme
          Container(
            decoration: BoxDecoration(
              color: _headerBackground,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20.r),
                bottomRight: Radius.circular(20.r),
              ),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              left: 20.w,
              right: 20.w,
              bottom: 20.h,
            ),
            child: Column(
              children: [
                // Header with back arrow and settings
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Get.to(() => const SettingScreen());
                      },
                      child: Icon(
                        Icons.settings,
                        color: Colors.white,
                        size: 24.sp,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                // User Profile Section
                Row(
                  children: [
                    // Profile Picture
                    Container(
                      width: 60.w,
                      height: 60.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _cardBackground,
                      ),
                      child: ClipOval(
                        child: _profileLoading
                            ? Center(
                                child: SizedBox(
                                  width: 18.w,
                                  height: 18.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : (_userPhotoUrl != null &&
                                  _userPhotoUrl!.trim().isNotEmpty)
                            ? Image.network(
                                _userPhotoUrl!.trim().startsWith('http')
                                    ? _userPhotoUrl!.trim()
                                    : '${ApiUrls.baseUrl}${_userPhotoUrl!.trim()}',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.person, size: 30);
                                },
                              )
                            : const Icon(Icons.person, size: 30),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    // Greeting and Name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'good_morning'.tr,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                            ),
                          ),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _profileLoading
                                      ? 'loading'.tr
                                      : (_userName ?? '—'),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Icon(
                                Icons.verified,
                                color: AppConst.selectedBorderColor,
                                size: 18.sp,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Obx(() {
                        const languages = <Map<String, String>>[
                          {'code': 'en', 'short': 'EN', 'name': 'english'},
                          {'code': 'ar', 'short': 'AR', 'name': 'arabic'},
                          {'code': 'es', 'short': 'ES', 'name': 'spanish'},
                          {'code': 'fr', 'short': 'FR', 'name': 'french'},
                          {'code': 'zh', 'short': 'ZH', 'name': 'mandarin'},
                        ];
                        return DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _appLanguageController
                                .locale
                                .value
                                .languageCode,
                            dropdownColor: _headerBackground,
                            iconEnabledColor: Colors.white,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            selectedItemBuilder: (context) {
                              return languages
                                  .map(
                                    (lang) => Align(
                                      alignment: Alignment.center,
                                      child: Text(
                                        lang['short']!,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList();
                            },
                            items: languages
                                .map(
                                  (lang) => DropdownMenuItem<String>(
                                    value: lang['code'],
                                    child: Text(lang['name']!.tr),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                _appLanguageController.changeLanguage(value);
                              }
                            },
                          ),
                        );
                      }),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                // Online Status Toggle
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: _cardBackground,
                    borderRadius: AppConst.borderRadius,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isOnline ? 'online'.tr : 'offline'.tr,
                              style: TextStyle(
                                color: _primaryTextColor,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              _isOnline
                                  ? 'available_for_tasks'.tr
                                  : 'not_receiving_tasks'.tr,
                              style: TextStyle(
                                color: _textWithOpacity(0.7),
                                fontSize: 12.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_onlineStatusLoading)
                        SizedBox(
                          width: 24.w,
                          height: 24.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      else
                        Switch(
                          value: _isOnline,
                          onChanged: _onOnlineChanged,
                          // On: green track. Off: solid grey — reads as intentional off,
                          // not a disabled / washed-out control.
                          thumbColor: WidgetStateProperty.all<Color>(
                            Colors.white,
                          ),
                          trackColor: WidgetStateProperty.resolveWith<Color>((
                            states,
                          ) {
                            if (states.contains(WidgetState.selected)) {
                              return Colors.green;
                            }
                            return AppConst.grey;
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Bottom Section - Yellow Themsplae
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  // CustomTextField(
                  //   controller: _searchController,
                  //   hintText: 'Search',
                  //   keyboardType: TextInputType.text,
                  //   prefixIcon: Icon(
                  //     Icons.search,
                  //     color: AppConst.blackWithOpacity(0.5),
                  //     size: 24.sp,
                  //   ),
                  //   onChanged: (value) {
                  //     // TODO: Handle search
                  //   },
                  //   onSubmitted: (value) {
                  //     // TODO: Handle search submission
                  //   },
                  // ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Get.to(() => const NearbyFirestoreOrdersScreen());
                      },
                      icon: Icon(
                        Icons.location_on_outlined,
                        color: _primaryTextColor,
                        size: 20.sp,
                      ),
                      label: Text(
                        'available_orders'.tr,
                        style: TextStyle(
                          color: _primaryTextColor,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _cardBackground,
                        foregroundColor: _primaryTextColor,
                        side: BorderSide(color: _textWithOpacity(0.12)),
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 14.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppConst.borderRadius,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _buildDriverRatingCard(),
                  SizedBox(height: 16.h),
                  const ServiceModeTilesSection(),
                  SizedBox(height: 20.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: _cardBackground,
                      borderRadius: AppConst.borderRadius,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 2.h),
                          child: Icon(
                            Icons.location_on,
                            color: AppConst.primaryColor,
                            size: 22.sp,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: _locationLoading
                              ? Text(
                                  'getting_your_location'.tr,
                                  style: TextStyle(
                                    color: _textWithOpacity(0.6),
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'your_location'.tr,
                                      style: TextStyle(
                                        color: _textWithOpacity(0.55),
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      _locationLabel.isEmpty
                                          ? '—'
                                          : _locationLabel,
                                      style: TextStyle(
                                        color: _primaryTextColor,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _buildEarningsCard(),
                  SizedBox(height: 12.h),
                  const ActiveOrdersSection(previewCardLimit: 3),
                  SizedBox(height: 16.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: SizedBox(
                      width: double.infinity,
                      height: 300.h,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _mapTarget,
                          zoom: 13.8,
                        ),
                        markers: _nearbyRideMarkers(),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        compassEnabled: false,
                        onMapCreated: (c) {
                          _mapController = c;
                          if (_userLatLng != null) {
                            c.animateCamera(
                              CameraUpdate.newLatLngZoom(_userLatLng!, 14),
                            );
                          }
                        },
                        gestureRecognizers:
                            <Factory<OneSequenceGestureRecognizer>>{
                              Factory<EagerGestureRecognizer>(
                                EagerGestureRecognizer.new,
                              ),
                            },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
