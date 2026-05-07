import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:t_rider_services_app/consts/appConst.dart';

import 'package:t_rider_services_app/data/repositories/auth_repository.dart';
import 'package:t_rider_services_app/views/widgets/custom_appbar.dart';
import 'package:t_rider_services_app/views/widgets/app_snackbar.dart';
import 'dart:async';
import 'terms_and_condition_screen.dart';

class PhoneOtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String countryCode;

  const PhoneOtpScreen({
    super.key,
    required this.phoneNumber,
    required this.countryCode,
  });

  @override
  State<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends State<PhoneOtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  int _resendCountdown = 30;
  Timer? _countdownTimer;
  bool _canResend = false;
  bool _isVerifying = false;
  final AuthRepository _authRepository = AuthRepository();
  String? _debugOtp;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    // Auto-focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });

    // Capture the last debug OTP (if any) to display on screen.
    _debugOtp = AuthRepository.lastDebugOtp;
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  String _formatPhoneNumber() {
    final phone = widget.phoneNumber;
    if (phone.length == 10) {
      return '${phone.substring(0, 3)} ${phone.substring(3, 6)} ${phone.substring(6)}';
    }
    return phone;
  }

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty && index < 3) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  bool _isOtpComplete() {
    return _controllers.every((controller) => controller.text.isNotEmpty);
  }

  String _getOtpCode() {
    return _controllers.map((controller) => controller.text).join();
  }

  Future<void> _verifyOtp() async {
    if (!_isOtpComplete() || _isVerifying) return;

    final identifier = '${widget.countryCode}${widget.phoneNumber}';
    final otp = _getOtpCode();

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
      print('PhoneOtpScreen verify OTP error: $e');
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
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConst.scaffoldBackground,
      body: Column(
        children: [
          const CustomAppBar(title: 'verify_code'),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 40.h),
                  // Instruction text with phone number
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: AppConst.black,
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(text: 'verification_code_sent_to'.tr),
                        TextSpan(
                          text: '${widget.countryCode} ${_formatPhoneNumber()}',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  if (_debugOtp != null) ...[
                    SizedBox(height: 12.h),
                    Text(
                      'DEBUG OTP: $_debugOtp',
                      style: TextStyle(
                        color: AppConst.black.withOpacity(0.7),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  SizedBox(height: 40.h),
                  // 4 OTP input fields
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(4, (index) {
                      return Container(
                        width: 70.w,
                        height: 80.h,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: TextStyle(
                            color: AppConst.black,
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            fillColor: AppConst.white,
                            filled: true,
                            counterText: '',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12.r),
                                bottomRight: Radius.circular(12.r),
                              ),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (value) {
                            _onOtpChanged(index, value);
                            setState(() {});
                          },
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 24.h),
                  // Resend code text
                  Center(
                    child: GestureDetector(
                      onTap: _canResend
                          ? () {
                              // TODO: Handle resend code
                              setState(() {
                                _resendCountdown = 30;
                                _canResend = false;
                              });
                              _startCountdown();
                            }
                          : null,
                      child: Text(
                        _canResend
                            ? 'resend_code'.tr
                            : '${'resend_code_in'.tr} ${_resendCountdown}s',
                        style: TextStyle(
                          color: AppConst.black,
                          fontSize: 14.sp,
                          fontWeight: _canResend
                              ? FontWeight.w600
                              : FontWeight.normal,
                          decoration: _canResend
                              ? TextDecoration.underline
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: _isOtpComplete() && !_isVerifying
                          ? _verifyOtp
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isOtpComplete() && !_isVerifying
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
