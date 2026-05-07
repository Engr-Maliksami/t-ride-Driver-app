import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:t_rider_services_app/consts/appConst.dart';
import 'package:t_rider_services_app/data/repositories/auth_repository.dart';
import 'package:t_rider_services_app/views/widgets/app_snackbar.dart';
import 'Regsitration_screens/email_registration_screen.dart';
import 'Regsitration_screens/phone_otp_screen.dart';
import 'Regsitration_screens/whatsapp_registration_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController countryCodeController = TextEditingController();
  bool isPhoneNumberValid = false;
  bool _isSendingOtp = false;
  final AuthRepository _authRepository = AuthRepository();

  @override
  void initState() {
    super.initState();
    countryCodeController.text = '+1';
    phoneController.addListener(_validatePhoneNumber);
  }

  void _validatePhoneNumber() {
    setState(() {
      isPhoneNumberValid =
          phoneController.text.isNotEmpty && phoneController.text.length >= 10;
    });
  }

  @override
  void dispose() {
    phoneController.removeListener(_validatePhoneNumber);
    phoneController.dispose();
    countryCodeController.dispose();
    super.dispose();
  }

  Future<void> _onContinuePressed() async {
    if (!isPhoneNumberValid || _isSendingOtp) return;

    final fullNumber = '${countryCodeController.text}${phoneController.text}';

    setState(() {
      _isSendingOtp = true;
    });

    try {
      final success = await _authRepository.sendOtp(
        method: 'phone',
        phoneNumber: fullNumber,
      );

      if (!mounted) return;

      if (success) {
        Get.to(
          () => PhoneOtpScreen(
            phoneNumber: phoneController.text,
            countryCode: countryCodeController.text,
          ),
        );
      } else {
        AppSnackbar.showError(message: 'failed_send_otp_try_again'.tr);
      }
    } catch (e) {
      // ignore: avoid_print
      print('RegistrationScreen send OTP error: $e');
      if (mounted) {
        AppSnackbar.showApiError(
          e,
          fallbackMessage: 'could_not_send_otp_try_again'.tr,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingOtp = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConst.scaffoldBackground,
      body: Column(
        children: [
          // Top Section - Black Background with Logo
          ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30.r),
              bottomRight: Radius.circular(30.r),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppConst.brandedHeader,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30.r),
                  bottomRight: Radius.circular(30.r),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    // vert.h,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Logo
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Get.back(),
                              icon: Icon(
                                Icons.arrow_back,
                                color: AppConst.brandedHeaderForeground,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/T (1) 2 (1).png',
                              width: 200.w,
                              height: 200.h,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                        // Welcome Text
                        Text(
                          'welcome_to_t_ride'.tr,
                          style: TextStyle(
                            color: AppConst.primaryColor,
                            fontSize: 28.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        // Instruction Text
                        Text(
                          'enter_phone_to_continue'.tr,
                          style: TextStyle(
                            color: AppConst.brandedHeaderForeground,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        SizedBox(height: 40.h),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Bottom Section - Yellow Background with Input Fields
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20.w,
                    30.h,
                    20.w,
                    30.h + MediaQuery.of(context).padding.bottom,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Phone Number Input Fields
                        Row(
                          children: [
                            // Country Code Field
                            Container(
                              width: 100.w,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: TextField(
                                controller: countryCodeController,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppConst.black,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  fillColor: AppConst.white,
                                  filled: true,
                                  prefixIcon: Icon(
                                    Icons.phone,
                                    color: AppConst.black,
                                    size: 20.sp,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.only(
                                      topRight: Radius.circular(12.r),
                                      bottomLeft: Radius.circular(12.r),
                                    ),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 16.h,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            // Phone Number Field
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppConst.white,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: TextField(
                                  controller: phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: TextStyle(
                                    color: AppConst.black,
                                    fontSize: 16.sp,
                                  ),
                                  decoration: InputDecoration(
                                    fillColor: AppConst.white,
                                    filled: true,
                                    hintText: 'enter_phone_number'.tr,
                                    hintStyle: TextStyle(
                                      color: AppConst.grey,
                                      fontSize: 16.sp,
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
                                      vertical: 16.h,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 30.h),
                        // Continue Button
                        SizedBox(
                          width: double.infinity,
                          height: 50.h,
                          child: ElevatedButton(
                            onPressed: isPhoneNumberValid && !_isSendingOtp
                                ? _onContinuePressed
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isPhoneNumberValid && !_isSendingOtp
                                  ? AppConst.black
                                  : AppConst.blackWithOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Text(
                              _isSendingOtp ? 'sending_otp'.tr : 'continue'.tr,
                              style: TextStyle(
                                color: AppConst.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 30.h),
                        // Divider with "or continue with"
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: AppConst.black,
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              child: Text(
                                'or_continue_with'.tr,
                                style: TextStyle(
                                  color: AppConst.black,
                                  fontSize: 14.sp,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: AppConst.black,
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 30.h),
                        // Continue with Email Button
                        Container(
                          width: double.infinity,
                          height: 50.h,
                          decoration: BoxDecoration(
                            color: AppConst.white,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Get.to(() => const EmailRegistrationScreen());
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConst.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Google G Logo (simplified)
                                Container(
                                  width: 24.w,
                                  height: 24.w,
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'G',
                                      style: TextStyle(
                                        color: AppConst.white,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Text(
                                  'continue_with_email'.tr,
                                  style: TextStyle(
                                    color: AppConst.black,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        // Continue with WhatsApp Button
                        Container(
                          width: double.infinity,
                          height: 50.h,
                          decoration: BoxDecoration(
                            color: AppConst.white,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Get.to(() => const WhatsappRegistrationScreen());
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConst.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Google G Logo (simplified)
                                Container(
                                  width: 24.w,
                                  height: 24.w,
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'G',
                                      style: TextStyle(
                                        color: AppConst.white,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Text(
                                  'continue_with_whatsapp'.tr,
                                  style: TextStyle(
                                    color: AppConst.black,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
