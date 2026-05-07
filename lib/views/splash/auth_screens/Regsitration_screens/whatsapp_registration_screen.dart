import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:t_rider_services_app/consts/appConst.dart';
import 'package:t_rider_services_app/data/repositories/auth_repository.dart';
import 'package:t_rider_services_app/views/widgets/app_snackbar.dart';
import 'phone_otp_screen.dart';
import '../../../widgets/custom_appbar.dart';

class WhatsappRegistrationScreen extends StatefulWidget {
  const WhatsappRegistrationScreen({super.key});

  @override
  State<WhatsappRegistrationScreen> createState() =>
      _WhatsappRegistrationScreenState();
}

class _WhatsappRegistrationScreenState
    extends State<WhatsappRegistrationScreen> {
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
        method: 'whatsapp',
        whatsappNumber: fullNumber,
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
        AppSnackbar.showError(
          message: 'failed_send_otp_try_again'.tr,
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('WhatsAppRegistrationScreen send OTP error: $e');
      if (mounted) {
        AppSnackbar.showApiError(e);
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
          const CustomAppBar(title: 'continue_with_whatsapp'),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20.h),
                  Text(
                    'whatsapp_number'.tr,
                    style: TextStyle(
                      color: AppConst.black,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  // Phone number row
                  Row(
                    children: [
                      // Country code field
                      Container(
                        width: 100.w,
                        decoration: BoxDecoration(
                          color: AppConst.white,
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
                            counterText: '',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(12.r),
                                bottomLeft: Radius.circular(12.r),
                              ),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // Whatsapp number field
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
                              counterText: '',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(12.r),
                                  bottomLeft: Radius.circular(12.r),
                                ),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: isPhoneNumberValid && !_isSendingOtp
                          ? _onContinuePressed
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPhoneNumberValid && !_isSendingOtp
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
