import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:t_rider_services_app/consts/appConst.dart';
import 'package:t_rider_services_app/views/home/setting/setting_screen.dart';

import '../../widgets/custom_textfield.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _regionController.dispose();
    _cityController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConst.scaffoldBackground,
      body: Column(
        children: [
          // Custom Header with Settings Icon
          Container(
            decoration: BoxDecoration(
              color: AppConst.brandedHeader,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20.r),
                bottomRight: Radius.circular(20.r),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 60.h,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.arrow_back,
                        color: AppConst.brandedHeaderForeground,
                        size: 24.sp,
                      ),
                      onPressed: () => Get.back(),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        'profile'.tr,
                        style: TextStyle(
                          color: AppConst.brandedHeaderForeground,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.settings,
                        color: AppConst.brandedHeaderForeground,
                        size: 24.sp,
                      ),
                      onPressed: () {
                        Get.to(() => const SettingScreen());
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 30.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Picture
                  Center(
                    child: Container(
                      width: 80.w,
                      height: 80.w,
                      decoration: BoxDecoration(
                        color: AppConst.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_outline,
                        size: 30.sp,
                        color: AppConst.black,
                      ),
                    ),
                  ),
                  SizedBox(height: 30.h),
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
                      hintText: 'profile_name_hint'.tr,
                      keyboardType: TextInputType.name,
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
                      hintText: 'profile_address_hint'.tr,
                      keyboardType: TextInputType.streetAddress,
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
                      hintText: 'profile_region_hint'.tr,
                      keyboardType: TextInputType.text,
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
                      hintText: 'profile_city_hint'.tr,
                      keyboardType: TextInputType.text,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // Role Field
                  Text(
                    'role'.tr,
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
                      controller: _roleController,
                      hintText: 'user_driver_vendor'.tr,
                      keyboardType: TextInputType.text,
                    ),
                  ),
                  SizedBox(height: 30.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
