import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:t_rider_services_app/consts/appConst.dart';
import 'package:t_rider_services_app/views/widgets/custom_appbar.dart';

import 'role_screen.dart';

class TermsAndCondition extends StatefulWidget {
  const TermsAndCondition({super.key});

  @override
  State<TermsAndCondition> createState() => _TermsAndConditionState();
}

class _TermsAndConditionState extends State<TermsAndCondition> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConst.scaffoldBackground,
      body: Column(
        children: [
          const CustomAppBar(title: 'terms_conditions'),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 30.h),
              child: Column(
                children: [
                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 20.h),
                          // Introductory text
                          Text(
                            'terms_intro'.tr,
                            style: TextStyle(
                              color: AppConst.black,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.normal,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 30.h),
                          // Section 1: Account Responsibility
                          Text(
                            'account_responsibility'.tr,
                            style: TextStyle(
                              color: AppConst.black,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            'account_responsibility_desc'.tr,
                            style: TextStyle(
                              color: AppConst.black,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.normal,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 24.h),
                          // Section 2: User Information
                          Text(
                            'user_information'.tr,
                            style: TextStyle(
                              color: AppConst.black,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            'user_information_desc'.tr,
                            style: TextStyle(
                              color: AppConst.black,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.normal,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 24.h),
                          // Section 3: Payments
                          Text(
                            'payments'.tr,
                            style: TextStyle(
                              color: AppConst.black,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            'payments_desc'.tr,
                            style: TextStyle(
                              color: AppConst.black,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.normal,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 30.h),
                        ],
                      ),
                    ),
                  ),
                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: () {
                        Get.to(
                          () => const RoleScreen(),
                          arguments:
                              Get.arguments as Map<String, dynamic>? ?? {},
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConst.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        'continue'.tr,
                        style: TextStyle(
                          color: AppConst.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
