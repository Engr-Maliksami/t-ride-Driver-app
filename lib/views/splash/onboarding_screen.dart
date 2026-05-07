import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../consts/appConst.dart';
import '../../controllers/onboarding_controller.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(OnboardingController());

    final List<OnboardingData> onboardingData = [
      OnboardingData(
        title: 'onboarding_title_1',
        description: 'onboarding_desc_1',
        imagePath: 'assets/image-removebg-preview 1.png',
      ),
      OnboardingData(
        title: 'onboarding_title_2',
        description: 'onboarding_desc_2',
        imagePath: 'assets/fda09075-9e94-4381-889f-3fed533e537e 1.png',
      ),
      OnboardingData(
        title: 'onboarding_title_3',
        description: 'onboarding_desc_3',
        imagePath:
            'assets/WhatsApp_Image_2025-12-18_at_11.50.46_AM-removebg-preview.png',
      ),
      OnboardingData(
        title: 'onboarding_title_4',
        description: 'onboarding_desc_4',
        imagePath: 'assets/_Hoodie Sale Instagram Post (1) 1.png',
      ),
    ];

    return Scaffold(
      backgroundColor: AppConst.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppConst.black,
              AppConst.black,

              AppConst.transparent,
              AppConst.primaryColor,

              AppConst.primaryColor,
              AppConst.primaryColor,
            ],
            // stops: const [0.5, 0.6, 0.5],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Back Button
              Obx(
                () => controller.currentPage.value > 0
                    ? Padding(
                        padding: EdgeInsets.only(left: 20.w, top: 10.h),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: Icon(
                              Icons.arrow_back,
                              color: AppConst.white,
                              size: 24.sp,
                            ),
                            onPressed: () => controller.previousPage(),
                          ),
                        ),
                      )
                    : SizedBox(height: 60.h),
              ),
              // PageView
              Expanded(
                child: PageView.builder(
                  controller: controller.pageController,
                  onPageChanged: controller.onPageChanged,
                  itemCount: onboardingData.length,
                  itemBuilder: (context, index) {
                    return OnboardingPage(
                      data: onboardingData[index],
                      index: index,
                    );
                  },
                ),
              ),
              // Pagination Dots
              Obx(
                () => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    onboardingData.length,
                    (index) => Container(
                      width: 8.w,
                      height: 8.w,
                      margin: EdgeInsets.symmetric(horizontal: 4.w),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: controller.currentPage.value == index
                            ? AppConst.white
                            : AppConst.blackWithOpacity(0.3),
                      ),
                    ),
                  ),
                ),
              ),

              // Next/Done Button
              Obx(
                () => Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 30.h,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: controller.nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConst.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Text(
                        (controller.currentPage.value == onboardingData.length - 1
                                ? 'done'
                                : 'next')
                            .tr,
                        style: TextStyle(
                          color: AppConst.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final OnboardingData data;
  final int index;

  const OnboardingPage({super.key, required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image
          Container(
            margin: EdgeInsets.only(bottom: 40.h),
            decoration: BoxDecoration(color: Colors.transparent),
            child: Image.asset(
              data.imagePath,
              // width: 400.w,
              height: 350.h,
              fit: BoxFit.cover,
            ),
          ),
          // Title
          Text(
            data.title.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppConst.black,
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          SizedBox(height: 16.h),
          // Description
          Text(
            data.description.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppConst.blackWithOpacity(0.7),
              fontSize: 14.sp,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final String imagePath;

  OnboardingData({
    required this.title,
    required this.description,
    required this.imagePath,
  });
}
