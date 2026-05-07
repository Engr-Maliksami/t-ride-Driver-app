import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:t_rider_services_app/consts/appConst.dart';
import '../../widgets/custom_appbar.dart';
import '../../widgets/custom_textfield.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _roleController.dispose();
    _cityController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  bool _isFormValid() {
    return _nameController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _roleController.text.isNotEmpty &&
        _cityController.text.isNotEmpty &&
        _commentsController.text.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConst.scaffoldBackground,
      body: Column(
        children: [
          const CustomAppBar(title: 'feedback_form'),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 30.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      hintText: 'enter_full_name'.tr,
                      keyboardType: TextInputType.name,
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // Email Field
                  Text(
                    'email'.tr,
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
                      controller: _emailController,
                      hintText: 'enter_your_email'.tr,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (value) => setState(() {}),
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
                      onChanged: (value) => setState(() {}),
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
                      hintText: 'enter_city'.tr,
                      keyboardType: TextInputType.text,
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // Comments Field
                  Text(
                    'comments'.tr,
                    style: TextStyle(
                      color: AppConst.black,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  SizedBox(
                    height: 120.h,
                    child: CustomTextField(
                      controller: _commentsController,
                      hintText:
                          'feedback_hint'.tr,
                      keyboardType: TextInputType.multiline,
                      maxLines: 5,
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                  SizedBox(height: 30.h),
                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: _isFormValid()
                          ? () {
                              // TODO: Handle feedback submission
                              print('Feedback submitted');
                              print('Name: ${_nameController.text}');
                              print('Email: ${_emailController.text}');
                              print('Role: ${_roleController.text}');
                              print('City: ${_cityController.text}');
                              print('Comments: ${_commentsController.text}');
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFormValid()
                            ? AppConst.black
                            : AppConst.blackWithOpacity(0.5),
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
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
