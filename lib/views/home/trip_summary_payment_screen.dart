import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:t_rider_services_app/consts/appConst.dart';
import 'package:t_rider_services_app/views/widgets/custom_appbar.dart';

class TripSummaryPaymentScreen extends StatefulWidget {
  const TripSummaryPaymentScreen({super.key});

  @override
  State<TripSummaryPaymentScreen> createState() =>
      _TripSummaryPaymentScreenState();
}

class _TripSummaryPaymentScreenState extends State<TripSummaryPaymentScreen> {
  int _selectedRating = 4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConst.scaffoldBackground,
      body: Column(
        children: [
          // Top Header
          CustomAppBar(title: 'trip_summary_payment'),
          // Container(
          //   decoration: BoxDecoration(
          //     color: AppConst.black,
          //     borderRadius: BorderRadius.only(
          //       bottomLeft: Radius.circular(20.r),
          //       bottomRight: Radius.circular(20.r),
          //     ),
          //   ),
          //   padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          //   child: SafeArea(
          //     child: Row(
          //       children: [
          //         IconButton(
          //           icon: Icon(
          //             Icons.arrow_back,
          //             color: AppConst.white,
          //             size: 20.sp,
          //           ),
          //           onPressed: () => Get.back(),
          //         ),
          //         Text(
          //           'Trip Summary & Payment',
          //           style: TextStyle(
          //             color: AppConst.white,
          //             fontSize: 18.sp,
          //             fontWeight: FontWeight.bold,
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),
          // ),
          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Card with Yellow Border
                  Container(
                    decoration: BoxDecoration(
                      color: AppConst.black,
                      borderRadius: AppConst.borderRadius,
                      border: Border(
                        left: BorderSide(
                          color: AppConst.primaryColor,
                          width: 6.w,
                        ),
                      ),
                    ),
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Fare Summary Section
                        Text(
                          'fare_summary'.tr,
                          style: TextStyle(
                            color: AppConst.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: AppConst.white,
                            borderRadius: AppConst.borderRadius,
                          ),
                          child: Column(
                            children: [
                              _buildFareItem('base_fare'.tr, '\$3.00'),
                              SizedBox(height: 12.h),
                              _buildFareItem('distance_fare'.tr, '\$8.00'),
                              SizedBox(height: 12.h),
                              _buildFareItem('time_fare'.tr, '\$2.00'),
                              SizedBox(height: 12.h),
                              _buildFareItem('discount'.tr, '\$2.00'),
                              SizedBox(height: 12.h),
                              _buildFareItem('tolls'.tr, '\$0.00'),
                              SizedBox(height: 16.h),
                              Divider(
                                color: AppConst.white.withOpacity(0.3),
                                thickness: 1,
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 16.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'total_fare'.tr,
                              style: TextStyle(
                                color: AppConst.white,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '\$15.00',
                              style: TextStyle(
                                color: AppConst.white,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 30.h),
                        // Payment Status Section
                        Text(
                          'payment_status'.tr,
                          style: TextStyle(
                            color: AppConst.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: AppConst.white,
                            borderRadius: AppConst.borderRadius,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.money,
                                color: AppConst.black,
                                size: 24.sp,
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Text(
                                  'cash_pay_driver'.tr,
                                  style: TextStyle(
                                    color: AppConst.black,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 30.h),
                        // Passenger's Rate For Driver Section
                        Text(
                          'passenger_rate_for_driver'.tr,
                          style: TextStyle(
                            color: AppConst.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: AppConst.white,
                            borderRadius: AppConst.borderRadius,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  // Driver Profile Picture
                                  Container(
                                    width: 60.w,
                                    height: 60.w,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.blue[100],
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      size: 40.sp,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  // Driver Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Olive Rio',
                                          style: TextStyle(
                                            color: AppConst.black,
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          '4.9 (2160+ rides)',
                                          style: TextStyle(
                                            color: AppConst.blackWithOpacity(
                                              0.7,
                                            ),
                                            fontSize: 14.sp,
                                          ),
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          'White Honda City',
                                          style: TextStyle(
                                            color: AppConst.blackWithOpacity(
                                              0.7,
                                            ),
                                            fontSize: 14.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 20.h),
                              // Rating Stars
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(5, (index) {
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedRating = index + 1;
                                      });
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 4.w,
                                      ),
                                      child: Icon(
                                        index < _selectedRating
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: AppConst.primaryColor,
                                        size: 32.sp,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Handle done action
                        Get.back();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConst.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          side: BorderSide(
                            color: AppConst.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Text(
                        'done'.tr,
                        style: TextStyle(
                          color: AppConst.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Done Button
          // Container(
          //   padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          //   decoration: BoxDecoration(
          //     color: AppConst.black,
          //     boxShadow: [
          //       BoxShadow(
          //         color: AppConst.blackWithOpacity(0.1),
          //         blurRadius: 10,
          //         offset: const Offset(0, -2),
          //       ),
          //     ],
          //   ),
          //   child:
          // ),
        ],
      ),
    );
  }

  Widget _buildFareItem(String label, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: AppConst.black, fontSize: 14.sp),
        ),
        Text(
          amount,
          style: TextStyle(
            color: AppConst.black,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
