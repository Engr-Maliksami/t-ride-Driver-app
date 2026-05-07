import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:t_rider_services_app/consts/appConst.dart';

class CustomTextField extends StatelessWidget {
  final String? hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final TextInputType? keyboardType;
  final int? maxLines;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final FocusNode? focusNode;

  const CustomTextField({
    super.key,
    this.hintText,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.keyboardType,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.only(
      topRight: Radius.circular(12.r),
      bottomLeft: Radius.circular(12.r),
    );
    final Color borderColor = AppConst.blackWithOpacity(0.18);
    final Color focusedBorderColor = AppConst.black;

    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12.r)),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        enabled: enabled,
        keyboardType: keyboardType,
        maxLines: maxLines,
        focusNode: focusNode,
        style: TextStyle(color: AppConst.black, fontSize: 16.sp),
        decoration: InputDecoration(
          fillColor: AppConst.white,
          filled: true,
          hintText: hintText ?? '',
          hintStyle: TextStyle(color: AppConst.grey, fontSize: 16.sp),
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 18.h,
          ),
          border: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: borderColor, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: borderColor, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: focusedBorderColor, width: 1.5),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(
              color: AppConst.blackWithOpacity(0.08),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}
