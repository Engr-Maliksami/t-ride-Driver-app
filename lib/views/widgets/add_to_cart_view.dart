import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:t_rider_services_app/consts/appConst.dart';
import 'package:t_rider_services_app/views/widgets/custom_appbar.dart';

class AddToCartSuccessView extends StatelessWidget {
  const AddToCartSuccessView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConst.scaffoldBackground,
      body: Column(
        children: [
          // Top Header (Black Background)
          CustomAppBar(title: ''),
          // Main Content
          Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Success Checkmark Icon
                    Container(
                      width: 100.w,
                      height: 100.w,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.green, width: 2),
                      ),
                      child: Icon(
                        Icons.check,
                        color: AppConst.white,
                        size: 60.sp,
                      ),
                    ),
                    SizedBox(height: 32.h),
                    // Main Message
                    Text(
                      'Successfully added to cart',
                      style: TextStyle(
                        color: AppConst.black,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16.h),
                    // Sub-message
                    Text(
                      'You can proceed to checkout or continue browsing',
                      style: TextStyle(color: AppConst.black, fontSize: 16.sp),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 100.h),
                  ],
                ),
              ),
            ),
          ),
          // Bottom Action Buttons
          Padding(
            padding: EdgeInsets.all(20.w),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Checkout Button
                  GestureDetector(
                    onTap: () {
                      // Navigate to checkout screen
                      // Get.to(() => const CheckoutScreen());
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      decoration: BoxDecoration(
                        color: AppConst.black,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Center(
                        child: Text(
                          'Checkout',
                          style: TextStyle(
                            color: AppConst.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  // Order more Button
                  GestureDetector(
                    onTap: () {
                      // Navigate back to food menu - pop back twice to reach food menu
                      Get.back(); // Pop success screen
                      Get.back(); // Pop add to cart screen
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      decoration: BoxDecoration(
                        color: AppConst.grey,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Center(
                        child: Text(
                          'Order more',
                          style: TextStyle(
                            color: AppConst.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
