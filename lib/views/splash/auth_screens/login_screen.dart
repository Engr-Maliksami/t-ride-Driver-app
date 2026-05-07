import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:t_rider_services_app/controllers/app_language_controller.dart';
import 'package:t_rider_services_app/consts/appConst.dart';
import 'package:t_rider_services_app/data/local/secure_storage_service.dart';
import 'package:t_rider_services_app/data/repositories/auth_repository.dart';
import 'package:t_rider_services_app/views/home/navbar.dart';
import 'package:t_rider_services_app/views/splash/auth_screens/language_selection_screen.dart';
import 'package:t_rider_services_app/utils/api_error_message.dart';
import 'package:t_rider_services_app/views/widgets/app_snackbar.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordObscured = true;
  bool _isLoading = false;
  final AuthRepository _authRepository = AuthRepository();
  final SecureStorageService _storageService = SecureStorageService();
  final AppLanguageController _appLanguageController =
      Get.find<AppLanguageController>();

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isFormValid() {
    return _identifierController.text.isNotEmpty &&
        _passwordController.text.length >= 6;
  }

  Future<void> _onLoginPressed() async {
    if (!_isFormValid() || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _authRepository.login(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
      );

      // Log full response for debugging
      // ignore: avoid_print
      print('Login API response: $response');

      final status = response['status'];

      if (status == true || status == 1) {
        final user = response['user'];
        if (!_userHasDriverRole(user)) {
          await _storageService.clearAuthToken();
          await _storageService.clearUserId();
          if (mounted) {
            AppSnackbar.showError(
              title: 'cannot_sign_in'.tr,
              message: 'roles_driver_only'.tr,
            );
          }
          return;
        }

        final token = response['token'] as String?;
        if (token != null && token.isNotEmpty) {
          await _storageService.saveAuthToken(token);
        }
        if (user is Map) {
          final idRaw = user['id'];
          int? userId;
          if (idRaw is int) userId = idRaw;
          if (idRaw is num) userId = idRaw.toInt();
          if (idRaw is String) userId = int.tryParse(idRaw.trim());
          if (userId != null) {
            await _storageService.saveUserId(userId);
          }
        }

        if (!mounted) return;
        Get.offAll(() => const Navbar());
      } else {
        final message = messageFromApiMap(
          response,
          fallback: 'failed_login_try_again'.tr,
        );
        if (mounted) {
          AppSnackbar.showError(title: 'login_failed'.tr, message: message);
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('LoginScreen login error: $e');
      if (mounted) {
        AppSnackbar.showApiError(
          e,
          fallbackMessage: 'failed_login_try_again'.tr,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSignUpPressed() {
    Get.to(() => const LanguageSelectionScreen());
  }

  /// This app is driver-only. A user is considered a driver when the login
  /// response's `user.driver_id` is present and non-empty (int or numeric
  /// string). Non-driver users have `driver_id == null`.
  bool _userHasDriverRole(dynamic user) {
    if (user is! Map) return false;
    final driverIdRaw = user['driver_id'];
    if (driverIdRaw == null) return false;
    if (driverIdRaw is num) return driverIdRaw != 0;
    if (driverIdRaw is String) {
      final trimmed = driverIdRaw.trim();
      if (trimmed.isEmpty) return false;
      final parsed = int.tryParse(trimmed);
      if (parsed != null) return parsed != 0;
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConst.scaffoldBackground,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppConst.primaryColorWithOpacity(0.95),
              AppConst.primaryColorWithOpacity(0.75),
            ],
          ),
        ),
        child: Column(
          children: [
            // Top black header with title
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              decoration: BoxDecoration(
                color: AppConst.brandedHeader,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30.r),
                  bottomRight: Radius.circular(30.r),
                ),
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'welcome_back'.tr,
                      style: TextStyle(
                        color: AppConst.brandedHeaderForeground,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'login_to_continue'.tr,
                      style: TextStyle(
                        color: AppConst.brandedHeaderForeground.withOpacity(
                          0.8,
                        ),
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 24.h,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Centered login card
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 24.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppConst.white,
                          borderRadius: BorderRadius.circular(24.r),
                          boxShadow: [
                            BoxShadow(
                              color: AppConst.blackWithOpacity(0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'login'.tr,
                              style: TextStyle(
                                color: AppConst.black,
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'login_subtitle'.tr,
                              style: TextStyle(
                                color: AppConst.grey,
                                fontSize: 13.sp,
                              ),
                            ),
                            SizedBox(height: 24.h),
                            Text(
                              'phone_or_email'.tr,
                              style: TextStyle(
                                color: AppConst.black,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Container(
                              decoration: BoxDecoration(
                                color: AppConst.white,
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(
                                  color: AppConst.blackWithOpacity(0.12),
                                ),
                              ),
                              child: TextField(
                                controller: _identifierController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  prefixIcon: Icon(
                                    Icons.person_outline,
                                    color: AppConst.grey,
                                    size: 22.sp,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12.w,
                                    vertical: 14.h,
                                  ),
                                  hintText: 'enter_phone_or_email'.tr,
                                  hintStyle: TextStyle(
                                    color: AppConst.grey,
                                    fontSize: 14.sp,
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            SizedBox(height: 20.h),
                            Text(
                              'password'.tr,
                              style: TextStyle(
                                color: AppConst.black,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Container(
                              decoration: BoxDecoration(
                                color: AppConst.white,
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(
                                  color: AppConst.blackWithOpacity(0.12),
                                ),
                              ),
                              child: TextField(
                                controller: _passwordController,
                                obscureText: _isPasswordObscured,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  prefixIcon: Icon(
                                    Icons.lock_outline,
                                    color: AppConst.grey,
                                    size: 22.sp,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12.w,
                                    vertical: 14.h,
                                  ),
                                  hintText: 'enter_password'.tr,
                                  hintStyle: TextStyle(
                                    color: AppConst.grey,
                                    fontSize: 14.sp,
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
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            SizedBox(height: 10.h),
                            // Align(
                            //   alignment: Alignment.centerRight,
                            //   child: TextButton(
                            //     onPressed: () {
                            //       // TODO: Forgot password flow
                            //     },
                            //     style: TextButton.styleFrom(
                            //       padding: EdgeInsets.zero,
                            //       minimumSize: Size(0, 0),
                            //       tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            //     ),
                            //     child: Text(
                            //       'Forgot password?',
                            //       style: TextStyle(
                            //         color: AppConst.black,
                            //         fontSize: 13.sp,
                            //         fontWeight: FontWeight.w500,
                            //       ),
                            //     ),
                            //   ),
                            // ),
                            SizedBox(height: 12.h),
                            SizedBox(
                              width: double.infinity,
                              height: 50.h,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppConst.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18.r),
                                  ),
                                  elevation: 2,
                                ),
                                onPressed: _isFormValid() && !_isLoading
                                    ? _onLoginPressed
                                    : null,
                                child: _isLoading
                                    ? SizedBox(
                                        width: 20.w,
                                        height: 20.w,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppConst.white,
                                        ),
                                      )
                                    : Text(
                                        'login'.tr,
                                        style: TextStyle(
                                          color: AppConst.white,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w),
                          decoration: BoxDecoration(
                            color: AppConst.blackWithOpacity(0.08),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: AppConst.blackWithOpacity(0.15),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _appLanguageController
                                  .locale
                                  .value
                                  .languageCode,
                              dropdownColor: AppConst.white,
                              iconEnabledColor: AppConst.black,
                              style: TextStyle(
                                color: AppConst.black,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                              ),
                              items: [
                                DropdownMenuItem<String>(
                                  value: 'en',
                                  child: Text('english'.tr),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'ar',
                                  child: Text('arabic'.tr),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'es',
                                  child: Text('spanish'.tr),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'fr',
                                  child: Text('french'.tr),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'zh',
                                  child: Text('mandarin'.tr),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  _appLanguageController.changeLanguage(value);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 100.h),
                      Center(
                        child: TextButton(
                          onPressed: _onSignUpPressed,
                          child: RichText(
                            text: TextSpan(
                              text: 'dont_have_account'.tr,
                              style: TextStyle(
                                color: AppConst.black,
                                fontSize: 14.sp,
                              ),
                              children: [
                                TextSpan(
                                  text: 'sign_up'.tr,
                                  style: TextStyle(
                                    color: AppConst.black,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
