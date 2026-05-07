import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:t_rider_services_app/data/local/secure_storage_service.dart';
import 'package:t_rider_services_app/data/repositories/profile_repository.dart';
import 'package:t_rider_services_app/views/home/setting/setting_screen.dart';
import 'package:t_rider_services_app/views/widgets/app_snackbar.dart';
import 'package:t_rider_services_app/views/widgets/custom_textfield.dart';

import '../../consts/appConst.dart';

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
  final TextEditingController _carModelController = TextEditingController();
  final TextEditingController _carPlateController = TextEditingController();
  final TextEditingController _carColorController = TextEditingController();
  final ProfileRepository _profileRepository = ProfileRepository();
  final SecureStorageService _secureStorageService = SecureStorageService();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSavingCarInfo = false;
  File? _selectedPhoto;
  String? _existingPhotoUrl;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _regionController.dispose();
    _cityController.dispose();
    _roleController.dispose();
    _carModelController.dispose();
    _carPlateController.dispose();
    _carColorController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadLocalCarInfo();
  }

  bool get _isCarInfoValid =>
      _carModelController.text.trim().isNotEmpty &&
      _carPlateController.text.trim().isNotEmpty &&
      _carColorController.text.trim().isNotEmpty;

  bool get _hasSavedCarInfo =>
      _carModelController.text.trim().isNotEmpty ||
      _carPlateController.text.trim().isNotEmpty ||
      _carColorController.text.trim().isNotEmpty;

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final profile = await _profileRepository.getProfile();
      if (!mounted) return;
      setState(() {
        _nameController.text = profile.name ?? '';
        _addressController.text = profile.address ?? '';
        _cityController.text = profile.city ?? '';
        _regionController.text = profile.city ?? '';
        _roleController.text =
            (profile.roles != null && profile.roles!.isNotEmpty)
            ? (profile.roles!.first.name ?? '')
            : '';
        // If backend sends a photo URL, store it for display.
        _existingPhotoUrl = profile.photo;
      });
    } catch (e) {
      // ignore: avoid_print
      print('ProfileScreen loadProfile error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool get _isFormValid =>
      _nameController.text.trim().isNotEmpty &&
      _addressController.text.trim().isNotEmpty &&
      _regionController.text.trim().isNotEmpty &&
      _cityController.text.trim().isNotEmpty &&
      _roleController.text.trim().isNotEmpty;

  Future<void> _saveProfile() async {
    if (_isSaving || !_isFormValid) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final updated = await _profileRepository.updateProfile(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        region: _regionController.text.trim(),
        city: _cityController.text.trim(),
        role: _roleController.text.trim(),
        photoFile: _selectedPhoto,
      );

      // refresh controllers with server data (in case backend normalized them)
      _nameController.text = updated.name ?? _nameController.text;
      _addressController.text = updated.address ?? _addressController.text;
      _cityController.text = updated.city ?? _cityController.text;
      _regionController.text = _regionController.text;
      _roleController.text =
          (updated.roles != null && updated.roles!.isNotEmpty)
          ? (updated.roles!.first.name ?? _roleController.text)
          : _roleController.text;
      _existingPhotoUrl = updated.photo ?? _existingPhotoUrl;

      AppSnackbar.showSuccess(
        title: 'success'.tr,
        message: 'profile_updated_successfully'.tr,
      );
    } catch (e) {
      // ignore: avoid_print
      print('ProfileScreen saveProfile error: $e');
      AppSnackbar.showApiError(e);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return;
      setState(() {
        _selectedPhoto = File(picked.path);
      });
    } catch (e) {
      // ignore: avoid_print
      print('ProfileScreen pickImage error: $e');
      AppSnackbar.showError(message: 'unable_to_pick_image'.tr);
    }
  }

  Future<void> _loadLocalCarInfo() async {
    try {
      final carInfo = await _secureStorageService.getCarInfo();
      if (!mounted) return;
      setState(() {
        _carModelController.text = carInfo['model'] ?? '';
        _carPlateController.text = carInfo['plateNumber'] ?? '';
        _carColorController.text = carInfo['color'] ?? '';
      });
    } catch (e) {
      // ignore: avoid_print
      print('ProfileScreen loadLocalCarInfo error: $e');
    }
  }

  Future<void> _saveLocalCarInfo() async {
    if (_isSavingCarInfo || !_isCarInfoValid) return;
    setState(() {
      _isSavingCarInfo = true;
    });
    try {
      await _secureStorageService.saveCarInfo(
        model: _carModelController.text.trim(),
        plateNumber: _carPlateController.text.trim(),
        color: _carColorController.text.trim(),
      );
      if (!mounted) return;
      AppSnackbar.showSuccess(
        title: 'success'.tr,
        message: 'Car information saved locally',
      );
    } catch (e) {
      AppSnackbar.showError(message: 'Failed to save car information');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingCarInfo = false;
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
                  if (_isLoading) ...[
                    Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 20.h),
                        child: CircularProgressIndicator(
                          color: AppConst.primaryColor,
                        ),
                      ),
                    ),
                  ],
                  // Profile Picture (tap to change)
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          Container(
                            width: 80.w,
                            height: 80.w,
                            decoration: BoxDecoration(
                              color: AppConst.white,
                              shape: BoxShape.circle,
                              image: _selectedPhoto != null
                                  ? DecorationImage(
                                      image: FileImage(_selectedPhoto!),
                                      fit: BoxFit.cover,
                                    )
                                  : (_existingPhotoUrl != null &&
                                        _existingPhotoUrl!.isNotEmpty)
                                  ? DecorationImage(
                                      image: NetworkImage(_existingPhotoUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child:
                                (_selectedPhoto == null &&
                                    (_existingPhotoUrl == null ||
                                        _existingPhotoUrl!.isEmpty))
                                ? Icon(
                                    Icons.person_outline,
                                    size: 30.sp,
                                    color: AppConst.black,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 24.w,
                              height: 24.w,
                              decoration: BoxDecoration(
                                color: AppConst.black,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                color: AppConst.white,
                                size: 14.sp,
                              ),
                            ),
                          ),
                        ],
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
                  SizedBox(height: 24.h),
                  Text(
                    'Car Information',
                    style: TextStyle(
                      color: AppConst.black,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Saved locally on this device',
                    style: TextStyle(
                      color: AppConst.blackWithOpacity(0.6),
                      fontSize: 12.sp,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  SizedBox(
                    height: 55.h,
                    child: CustomTextField(
                      controller: _carModelController,
                      hintText: 'Car model (e.g. Toyota Corolla)',
                      keyboardType: TextInputType.text,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  SizedBox(
                    height: 55.h,
                    child: CustomTextField(
                      controller: _carPlateController,
                      hintText: 'Plate number',
                      keyboardType: TextInputType.text,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  SizedBox(
                    height: 55.h,
                    child: CustomTextField(
                      controller: _carColorController,
                      hintText: 'Car color',
                      keyboardType: TextInputType.text,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  SizedBox(
                    width: double.infinity,
                    height: 46.h,
                    child: ElevatedButton(
                      onPressed: _isCarInfoValid && !_isSavingCarInfo
                          ? _saveLocalCarInfo
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConst.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: _isSavingCarInfo
                          ? SizedBox(
                              width: 18.w,
                              height: 18.w,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppConst.white,
                              ),
                            )
                          : Text(
                              'Save Car Info',
                              style: TextStyle(
                                color: AppConst.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  if (_hasSavedCarInfo) ...[
                    SizedBox(height: 12.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: AppConst.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: AppConst.blackWithOpacity(0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saved Car Info',
                            style: TextStyle(
                              color: AppConst.black,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            'Model: ${_carModelController.text.trim()}',
                            style: TextStyle(
                              color: AppConst.blackWithOpacity(0.8),
                              fontSize: 12.sp,
                            ),
                          ),
                          Text(
                            'Plate: ${_carPlateController.text.trim()}',
                            style: TextStyle(
                              color: AppConst.blackWithOpacity(0.8),
                              fontSize: 12.sp,
                            ),
                          ),
                          Text(
                            'Color: ${_carColorController.text.trim()}',
                            style: TextStyle(
                              color: AppConst.blackWithOpacity(0.8),
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 30.h),
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: _isFormValid && !_isSaving
                          ? _saveProfile
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConst.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: _isSaving
                          ? SizedBox(
                              width: 20.w,
                              height: 20.w,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppConst.white,
                              ),
                            )
                          : Text(
                              'save'.tr,
                              style: TextStyle(
                                color: AppConst.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
