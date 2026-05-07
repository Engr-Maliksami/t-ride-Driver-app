import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:t_rider_services_app/views/home/navbar.dart';
import 'package:t_rider_services_app/views/splash/auth_screens/login_screen.dart';
import '../../consts/appConst.dart';
import '../../data/local/secure_storage_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  final SecureStorageService _storageService = SecureStorageService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );
    _animationController.forward();
    _printCurrentLocation();
    _checkOnboardingAndNavigate();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _printCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // ignore: avoid_print
        print('SplashScreen location: services disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        // ignore: avoid_print
        print('SplashScreen location: permission denied ($permission)');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // ignore: avoid_print
      print(
        'SplashScreen current location: '
        'lat=${position.latitude}, lng=${position.longitude}',
      );

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

          String label;
          if (parts.length > 3) {
            label = parts.sublist(0, 3).join(', ');
          } else if (parts.isNotEmpty) {
            label = parts.join(', ');
          } else {
            label =
                '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
          }

          // ignore: avoid_print
          print('SplashScreen current location name: $label');
        }
      } catch (e) {
        // ignore: avoid_print
        print('SplashScreen reverse geocode error: $e');
      }
    } catch (e) {
      // ignore: avoid_print
      print('SplashScreen _printCurrentLocation error: $e');
    }
  }

  _checkOnboardingAndNavigate() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      final token = await _storageService.getAuthToken();

      if (token != null && token.isNotEmpty) {
        // ignore: avoid_print
        print('SplashScreen existing auth token: $token');
        // User already logged in, go directly to home
        Get.off(() => const Navbar());
      } else {
        // No token, show login screen
        Get.off(() => const LoginScreen());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConst.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // Logo
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // T Logo Image
                  Image.asset(
                    AppConst.NewLogo,
                    width: 270.w,
                    height: 270.h,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Progress Bar
            Padding(
              padding: EdgeInsets.only(bottom: 50.h),
              child: Container(
                width: double.infinity,
                height: 4.h,
                margin: EdgeInsets.symmetric(horizontal: 40.w),
                decoration: BoxDecoration(
                  color: AppConst.black,
                  borderRadius: BorderRadius.circular(2.r),
                ),
                child: AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return Stack(
                      children: [
                        Container(
                          width:
                              (MediaQuery.of(context).size.width - 80.w) *
                              _progressAnimation.value,
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: AppConst.white,
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
