import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:t_rider_services_app/consts/appConst.dart';
import 'package:t_rider_services_app/utils/api_error_message.dart';
import 'package:t_rider_services_app/data/local/secure_storage_service.dart';
import 'package:t_rider_services_app/views/splash/auth_screens/login_screen.dart';

/// App-wide black snackbars (GetX). Use this instead of [Get.snackbar].
abstract final class AppSnackbar {
  static const Duration _defaultDuration = Duration(seconds: 3);
  static bool _isAuthRedirecting = false;

  static bool _isUnauthenticated(Object error) {
    // Most repositories throw custom exceptions with `statusCode`.
    try {
      final dynamic e = error;
      final statusCode = e.statusCode;
      if (statusCode is int && statusCode == 401) return true;
    } catch (_) {
      // ignore
    }

    // Fallback: match server message text.
    final text = error.toString().toLowerCase();
    return text.contains('unauthenticated') || text.contains('unauthorized');
  }

  static Future<void> _redirectToLoginIfUnauthenticated(Object error) async {
    if (!_isUnauthenticated(error)) return;
    if (_isAuthRedirecting) return;
    _isAuthRedirecting = true;

    try {
      final storage = SecureStorageService();
      await storage.clearAuthToken();
    } catch (_) {
      // ignore: if storage fails, still redirect.
    }

    if (Get.isOverlaysOpen) {
      // Avoid leaving snackbars/dialogs over the login screen.
      Get.closeAllSnackbars();
    }

    // Replace entire stack so user can't go "back" into authenticated screens.
    if (Get.currentRoute != '/login') {
      Get.offAll(() => const LoginScreen());
    }
  }

  /// Generic black snackbar.
  static void show({
    required String title,
    required String message,
    Duration duration = _defaultDuration,
    IconData? icon,
  }) {
    _showBlack(
      title: title,
      message: message,
      duration: duration,
      icon: icon,
    );
  }

  static void showApiError(
    Object error, {
    String fallbackMessage = 'Something went wrong. Please try again.',
  }) {
    _redirectToLoginIfUnauthenticated(error);
    showError(
      title: 'Error',
      message: apiErrorMessage(error, fallback: fallbackMessage),
    );
  }

  static void showError({
    String title = 'Error',
    required String message,
    Duration duration = _defaultDuration,
  }) {
    show(
      title: title,
      message: message,
      duration: duration,
      icon: Icons.error_outline_rounded,
    );
  }

  static void showSuccess({
    String title = 'Success',
    required String message,
    Duration duration = _defaultDuration,
  }) {
    show(
      title: title,
      message: message,
      duration: duration,
      icon: Icons.check_circle_outline_rounded,
    );
  }

  static void _showBlack({
    required String title,
    required String message,
    required Duration duration,
    IconData? icon,
  }) {
    if (Get.context == null) return;

    Get.closeAllSnackbars();

    final topInset = MediaQuery.paddingOf(Get.context!).top;

    Get.snackbar(
      '',
      '',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.transparent,
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      duration: duration,
      titleText: const SizedBox.shrink(),
      messageText: Padding(
        padding: EdgeInsets.fromLTRB(16.w, topInset + 8.h, 16.w, 0),
        child: Material(
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppConst.brandedHeader,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(16.r),
                bottomLeft: Radius.circular(16.r),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppConst.blackWithOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      color: AppConst.brandedHeaderForeground.withValues(
                        alpha: 0.9,
                      ),
                      size: 24.sp,
                    ),
                    SizedBox(width: 12.w),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (title.isNotEmpty)
                          Text(
                            title,
                            style: TextStyle(
                              color: AppConst.brandedHeaderForeground,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        if (title.isNotEmpty) SizedBox(height: 6.h),
                        Text(
                          message,
                          style: TextStyle(
                            color: AppConst.brandedHeaderForeground.withValues(
                              alpha: 0.88,
                            ),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
