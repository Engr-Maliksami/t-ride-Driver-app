import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:t_rider_services_app/consts/appConst.dart';
import 'package:t_rider_services_app/data/repositories/auth_repository.dart';
import 'package:t_rider_services_app/data/repositories/location_repository.dart';
import 'package:t_rider_services_app/views/splash/auth_screens/login_screen.dart';
import 'package:t_rider_services_app/views/widgets/custom_appbar.dart';
import 'package:t_rider_services_app/views/widgets/custom_textfield.dart';
import 'package:t_rider_services_app/views/widgets/app_snackbar.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String role;

  const ProfileSetupScreen({super.key, required this.role});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoading = false;
  bool _isSuccess = false;
  bool _shouldRegister = true;
  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;
  final AuthRepository _authRepository = AuthRepository();
  final LocationRepository _locationRepository = LocationRepository();
  bool _isSavingLocation = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _regionController.dispose();
    _cityController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isFormValid() {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    return _nameController.text.isNotEmpty &&
        _addressController.text.isNotEmpty &&
        _regionController.text.isNotEmpty &&
        _cityController.text.isNotEmpty &&
        password.isNotEmpty &&
        confirm.isNotEmpty &&
        password == confirm &&
        password.length >= 6;
  }

  Future<void> _submitProfile() async {
    if (!_isFormValid()) return;

    // These values should be passed via Get.arguments from previous steps
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final identifier = args['identifier'] as String? ?? '';
    final int languageId = (args['language_id'] as int?) ?? 1;
    final password = _passwordController.text.trim();

    if (identifier.isEmpty) {
      AppSnackbar.showError(
        message: 'missing_identifier_for_registration'.tr,
      );
      return;
    }

    if (password.isEmpty || password.length < 6) {
      AppSnackbar.showError(message: 'password_min_6'.tr);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _authRepository.register(
        identifier: identifier,
        name: _nameController.text.trim(),
        password: password,
        role: widget.role,
        languageId: languageId,
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        setState(() {
          _isSuccess = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        AppSnackbar.showError(message: 'failed_register_try_again'.tr);
      }
    } catch (e) {
      // ignore: avoid_print
      print('ProfileSetupScreen._submitProfile error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        AppSnackbar.showApiError(e);
      }
    }
  }

  Future<void> _onContinuePressed() async {
    // When registering, require form to be valid; otherwise just continue.
    if (_shouldRegister) {
      if (!_isFormValid()) return;
      await _submitProfile();
    } else {
      _handleContinue();
    }
  }

  void _handleContinue() {
    // Navigate based on role name (case-insensitive, contains match)
    final role = widget.role.toLowerCase();

    // if (role.contains('vendor')) {
    //   // Vendor-related roles go to VendorProfileSetup
    //   Get.offAll(() => const VendorProfileSetup());
    // } else {
    //   // Default: go to customer home (Navbar)
    //   Get.offAll(() => const Navbar());
    // }
  }

  Future<void> _onSuccessContinuePressed() async {
    if (_isSavingLocation) return;

    setState(() {
      _isSavingLocation = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        // ignore: avoid_print
        print(
          'ProfileSetupScreen current location: ${position.latitude}, ${position.longitude}',
        );

        try {
          await _locationRepository.saveLocation(
            lat: position.latitude,
            lng: position.longitude,
          );
        } catch (e) {
          // ignore: avoid_print
          print('ProfileSetupScreen saveLocation error: $e');
        }
      } else {
        // ignore: avoid_print
        print('Location permission not granted, skipping save-location call.');
      }
    } catch (e) {
      // ignore: avoid_print
      print('ProfileSetupScreen getCurrentPosition error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingLocation = false;
        });
        Get.offAll(() => const LoginScreen());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConst.scaffoldBackground,
      body: Stack(
        children: [
          // Success Screen
          if (_isSuccess)
            _buildSuccessView()
          else
            // Profile Setup Form
            Column(
              children: [
                const CustomAppBar(title: 'profile_setup'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 20.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 10.h),
                        // Profile Picture Placeholder
                        // Center(
                        //   child: Stack(
                        //     children: [
                        //       Container(
                        //         width: 100.w,
                        //         height: 100.w,
                        //         decoration: BoxDecoration(
                        //           color: AppConst.white,
                        //           shape: BoxShape.circle,
                        //         ),
                        //         child: Icon(
                        //           Icons.person_2_outlined,
                        //           size: 30.sp,
                        //           color: AppConst.black,
                        //         ),
                        //       ),
                        //       // Camera icon button
                        //       Positioned(
                        //         bottom: 0,
                        //         right: 0,
                        //         child: GestureDetector(
                        //           onTap: () {
                        //             // TODO: Handle profile picture selection
                        //           },
                        //           child: Container(
                        //             width: 32.w,
                        //             height: 32.w,
                        //             decoration: BoxDecoration(
                        //               color: AppConst.black,
                        //               shape: BoxShape.circle,
                        //             ),
                        //             child: Icon(
                        //               Icons.camera_alt,
                        //               size: 18.sp,
                        //               color: AppConst.white,
                        //             ),
                        //           ),
                        //         ),
                        //       ),
                        //     ],
                        //   ),
                        // ),
                        // SizedBox(height: 24.h),
                        // Register toggle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'create_account_register_now'.tr,
                                style: TextStyle(
                                  color: AppConst.black,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            // Switch(
                            //   value: _shouldRegister,
                            //   activeColor: AppConst.black,
                            //   onChanged: (value) {
                            //     setState(() {
                            //       _shouldRegister = value;
                            //     });
                            //   },
                            // ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        // Name Field
                        Text(
                          'name'.tr,
                          style: TextStyle(
                            color: AppConst.black,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        SizedBox(
                          height: 55.h,
                          child: CustomTextField(
                            controller: _nameController,
                            hintText: 'enter_full_name'.tr,
                            keyboardType: TextInputType.name,
                            onChanged: (value) => setState(() {}),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        // Address Field
                        Text(
                          'address'.tr,
                          style: TextStyle(
                            color: AppConst.black,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        SizedBox(
                          height: 55.h,
                          child: CustomTextField(
                            controller: _addressController,
                            hintText: 'enter_address'.tr,
                            keyboardType: TextInputType.streetAddress,
                            maxLines: 2,
                            onChanged: (value) => setState(() {}),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        // Region Field
                        Text(
                          'region'.tr,
                          style: TextStyle(
                            color: AppConst.black,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        SizedBox(
                          height: 55.h,
                          child: CustomTextField(
                            controller: _regionController,
                            hintText: 'enter_region'.tr,
                            keyboardType: TextInputType.text,
                            onChanged: (value) => setState(() {}),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        // City Field
                        Text(
                          'city'.tr,
                          style: TextStyle(
                            color: AppConst.black,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        SizedBox(
                          height: 55.h,
                          child: CustomTextField(
                            controller: _cityController,
                            hintText: 'enter_city'.tr,
                            keyboardType: TextInputType.text,
                            onChanged: (value) => setState(() {}),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        // Password Field
                        Text(
                          'password'.tr,
                          style: TextStyle(
                            color: AppConst.black,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        SizedBox(
                          height: 55.h,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: TextField(
                              controller: _passwordController,
                              onChanged: (value) => setState(() {}),
                              keyboardType: TextInputType.visiblePassword,
                              obscureText: _isPasswordObscured,
                              style: TextStyle(
                                color: AppConst.black,
                                fontSize: 16.sp,
                              ),
                              decoration: InputDecoration(
                                fillColor: AppConst.white,
                                filled: true,
                                hintText: 'enter_secure_password'.tr,
                                hintStyle: TextStyle(
                                  color: AppConst.grey,
                                  fontSize: 16.sp,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordObscured
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: AppConst.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordObscured =
                                          !_isPasswordObscured;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(12.r),
                                    bottomLeft: Radius.circular(12.r),
                                  ),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 18.h,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        // Confirm Password Field
                        Text(
                          'confirm_password'.tr,
                          style: TextStyle(
                            color: AppConst.black,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        SizedBox(
                          height: 55.h,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: TextField(
                              controller: _confirmPasswordController,
                              onChanged: (value) => setState(() {}),
                              keyboardType: TextInputType.visiblePassword,
                              obscureText: _isConfirmPasswordObscured,
                              style: TextStyle(
                                color: AppConst.black,
                                fontSize: 16.sp,
                              ),
                              decoration: InputDecoration(
                                fillColor: AppConst.white,
                                filled: true,
                                hintText: 're_enter_password'.tr,
                                hintStyle: TextStyle(
                                  color: AppConst.grey,
                                  fontSize: 16.sp,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isConfirmPasswordObscured
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: AppConst.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isConfirmPasswordObscured =
                                          !_isConfirmPasswordObscured;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(12.r),
                                    bottomLeft: Radius.circular(12.r),
                                  ),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 18.h,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 24.h),
                        // Continue Button
                        SizedBox(
                          width: double.infinity,
                          height: 50.h,
                          child: ElevatedButton(
                            onPressed: !_isLoading ? _onContinuePressed : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: !_isLoading
                                  ? AppConst.black
                                  : AppConst.blackWithOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Text(
                              _isLoading && _shouldRegister
                                  ? 'saving'.tr
                                  : 'continue'.tr,
                              style: TextStyle(
                                color: AppConst.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 20.h),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          // Loading Overlay
          if (_isLoading && !_isSuccess)
            Container(
              color: AppConst.blackWithOpacity(0.5),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: AppConst.white,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppConst.primaryColor),
                      SizedBox(height: 16.h),
                      Text(
                        'getting_your_location'.tr,
                        style: TextStyle(
                          color: AppConst.black,
                          fontSize: 16.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      children: [
        const CustomAppBar(title: 'profile_setup'),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Success Checkmark Icon
                  Container(
                    width: 120.w,
                    height: 120.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.green, width: 4),
                    ),
                    child: Icon(Icons.check, color: Colors.green, size: 80.sp),
                  ),
                  SizedBox(height: 32.h),
                  // Success Message
                  Text(
                    'profile_saved_successfully'.tr,
                    style: TextStyle(
                      color: AppConst.black,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12.h),
                  // Sub Message
                  Text(
                    'you_can_proceed_to_explore'.tr,
                    style: TextStyle(color: AppConst.black, fontSize: 14.sp),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 60.h),
                ],
              ),
            ),
          ),
        ),
        // Continue Button
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: AppConst.primaryColor,
            boxShadow: [
              BoxShadow(
                color: AppConst.blackWithOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: GestureDetector(
            onTap: _onSuccessContinuePressed,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              decoration: BoxDecoration(
                color: AppConst.black,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Center(
                child: _isSavingLocation
                    ? SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppConst.white,
                        ),
                      )
                    : Text(
                        'continue'.tr,
                        style: TextStyle(
                          color: AppConst.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
