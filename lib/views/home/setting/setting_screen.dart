import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:t_rider_services_app/consts/appConst.dart';
import 'package:t_rider_services_app/controllers/app_theme_controller.dart';
import 'package:t_rider_services_app/data/repositories/auth_repository.dart';
import 'package:t_rider_services_app/views/splash/auth_screens/login_screen.dart';
import 'package:t_rider_services_app/views/widgets/app_snackbar.dart';
import '../../widgets/custom_appbar.dart';
import 'profile_screen.dart';
import 'feedback_screen.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  bool _pushNotificationsEnabled = true;
  bool _isLoggingOut = false;
  final AuthRepository _authRepository = AuthRepository();
  final AppThemeController _appThemeController = Get.find<AppThemeController>();
  bool get _isDarkMode => AppConst.isDarkMode;
  Color get _screenBackground => AppConst.scaffoldBackground;
  Color get _tileBackground =>
      _isDarkMode ? const Color(0xFFEFEFEF) : AppConst.white;
  Color get _tileForeground => Colors.black;

  void _showSupportDialog() {
    Get.dialog(
      Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(horizontal: 20.w),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: _tileBackground,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.headset_mic,
                      color: _tileForeground,
                      size: 22.sp,
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      'support'.tr,
                      style: TextStyle(
                        color: _tileForeground,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Text(
                  'support_dialog_message'.tr,
                  style: TextStyle(
                    color: _tileForeground,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 14.h),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (Get.isDialogOpen == true) Get.back();
                          Get.to(() => const FeedbackScreen());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _tileForeground,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                        child: Text(
                          'open_feedback_form'.tr,
                          style: TextStyle(
                            color: _isDarkMode
                                ? AppConst.black
                                : AppConst.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    IconButton(
                      onPressed: () {
                        if (Get.isDialogOpen == true) Get.back();
                      },
                      icon: const Icon(Icons.close),
                      color: AppConst.grey,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  Future<void> _onLogoutPressed() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authRepository.logout();

      if (!mounted) return;
      Get.offAll(() => const LoginScreen());
    } catch (e) {
      // ignore: avoid_print
      print('SettingScreen logout error: $e');
      if (mounted) {
        AppSnackbar.showApiError(e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBackground,
      body: Column(
        children: [
          const CustomAppBar(title: 'settings'),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Profile Opti
                  SizedBox(height: 100),
                  _buildSettingOption(
                    icon: Icons.person_outline,
                    title: 'profile'.tr,
                    onTap: () {
                      Get.to(() => const ProfileScreen());
                    },
                  ),
                  SizedBox(height: 12.h),
                  // Support Option
                  _buildSettingOption(
                    icon: Icons.headset_outlined,
                    title: 'support'.tr,
                    onTap: () {
                      _showSupportDialog();
                    },
                  ),
                  SizedBox(height: 12.h),
                  // Provide feedback Option
                  _buildSettingOption(
                    icon: Icons.feedback_outlined,
                    title: 'provide_feedback'.tr,
                    onTap: () {
                      Get.to(() => const FeedbackScreen());
                    },
                  ),
                  SizedBox(height: 12.h),
                  // Sign out Option
                  _buildSettingOption(
                    icon: Icons.logout,
                    title: _isLoggingOut ? 'logging_out'.tr : 'logout'.tr,
                    onTap: () {
                      _onLogoutPressed();
                    },
                  ),
                  SizedBox(height: 12.h),
                  // Push notifications Option with Toggle
                  _buildSettingOptionWithToggle(
                    icon: Icons.notifications_outlined,
                    title: 'push_notifications'.tr,
                    value: _pushNotificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _pushNotificationsEnabled = value;
                      });
                    },
                  ),
                  SizedBox(height: 12.h),
                  Obx(
                    () => _buildSettingOptionWithToggle(
                      icon: Icons.palette_outlined,
                      title: 'White Theme',
                      value: _appThemeController.isDarkMode,
                      onChanged: _appThemeController.setDarkMode,
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

  Widget _buildSettingOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: _tileBackground,
          borderRadius: AppConst.borderRadius,
          boxShadow: [
            BoxShadow(
              color: AppConst.blackWithOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: _tileForeground, size: 24.sp),
            SizedBox(width: 16.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: _tileForeground,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: _tileForeground, size: 24.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingOptionWithToggle({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: _tileBackground,
        borderRadius: AppConst.borderRadius,
        boxShadow: [
          BoxShadow(
            color: AppConst.blackWithOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: _tileForeground, size: 24.sp),
          SizedBox(width: 16.w),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: _tileForeground,
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppConst.white,
            activeTrackColor: AppConst.primaryColor,
            inactiveThumbColor: AppConst.grey,
            inactiveTrackColor: AppConst.grey.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
