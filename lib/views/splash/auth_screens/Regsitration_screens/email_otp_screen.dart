import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:t_rider_services_app/consts/appConst.dart';
import 'package:t_rider_services_app/data/repositories/auth_repository.dart';
import 'package:t_rider_services_app/views/widgets/custom_appbar.dart';
import 'package:t_rider_services_app/views/widgets/app_snackbar.dart';

import 'terms_and_condition_screen.dart';

class EmailOtpScreen extends StatefulWidget {
  const EmailOtpScreen({super.key});

  @override
  State<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends State<EmailOtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isVerifying = false;
  final AuthRepository _authRepository = AuthRepository();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyEmailOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || _isVerifying) return;

    // In a full flow, pass the email as an argument when navigating here.
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final identifier = args['email'] as String? ?? '';

    if (identifier.isEmpty) {
      AppSnackbar.showError(
        message: 'missing_email_identifier'.tr,
      );
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      final success = await _authRepository.verifyOtp(
        identifier: identifier,
        otp: otp,
      );

      if (!mounted) return;

      if (success) {
        Get.to(
          () => const TermsAndCondition(),
          arguments: {
            'identifier': identifier,
            ...?Get.arguments as Map<String, dynamic>?,
          },
        );
      } else {
        AppSnackbar.showError(
          message: 'invalid_otp_try_again'.tr,
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('EmailOtpScreen verify OTP error: $e');
      if (mounted) {
        AppSnackbar.showApiError(e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
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
          const CustomAppBar(title: 'verify_email'),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 40.h),
                  Text(
                    'enter_code_sent_email'.tr,
                    style: TextStyle(
                      color: AppConst.black,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    decoration: BoxDecoration(
                      color: AppConst.white,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: AppConst.black, fontSize: 16.sp),
                      decoration: InputDecoration(
                        hintText: 'enter_otp_code'.tr,
                        hintStyle: TextStyle(
                          color: AppConst.grey,
                          fontSize: 16.sp,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 18.h,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: !_isVerifying ? _verifyEmailOtp : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !_isVerifying
                            ? AppConst.black
                            : AppConst.blackWithOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        _isVerifying ? 'verifying'.tr : 'continue'.tr,
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
