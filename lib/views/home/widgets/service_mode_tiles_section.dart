import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:t_rider_services_app/consts/appConst.dart';
import 'package:t_rider_services_app/views/home/available_courier_requests_screen.dart';
import 'package:t_rider_services_app/views/home/available_food_delivery_screen.dart';
import 'package:t_rider_services_app/views/home/available_ride_requests_screen.dart';

/// [compactRow]: three equal columns (home). [list]: full-width rows (e.g. gallery).
enum ServiceModeTilesLayout { compactRow, list }

/// Ride / Courier / Delivery shortcuts — row or list layout.
class ServiceModeTilesSection extends StatelessWidget {
  const ServiceModeTilesSection({
    super.key,
    this.showHeader = true,
    this.headerText = 'choose_a_service',
    this.layout = ServiceModeTilesLayout.compactRow,
  });

  final bool showHeader;
  final String headerText;
  final ServiceModeTilesLayout layout;

  static const List<_ServiceModeItem> _items = [
    _ServiceModeItem(
      asset: 'assets/Vector.png',
      title: 'ride',
      subtitle: 'book_a_trip',
      screen: _ModeScreen.ride,
    ),
    _ServiceModeItem(
      asset: 'assets/Vector (2).png',
      title: 'courier',
      subtitle: 'send_parcels',
      screen: _ModeScreen.courier,
    ),
    _ServiceModeItem(
      asset: 'assets/Group.png',
      title: 'delivery',
      subtitle: 'food_and_more',
      screen: _ModeScreen.delivery,
    ),
  ];

  void _open(_ModeScreen mode) {
    HapticFeedback.lightImpact();
    switch (mode) {
      case _ModeScreen.ride:
        Get.to(() => const AvailableRideRequestsScreen());
      case _ModeScreen.courier:
        Get.to(() => const AvailableCourierRequestsScreen());
      case _ModeScreen.delivery:
        Get.to(() => const AvailableFoodDeliveryScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Padding(
            padding: EdgeInsets.only(
              left: 4.w,
              bottom: layout == ServiceModeTilesLayout.list ? 6.h : 10.h,
            ),
            child: Text(
              headerText.tr,
              style: TextStyle(
                color: AppConst.blackWithOpacity(
                  layout == ServiceModeTilesLayout.list ? 0.55 : 0.45,
                ),
                fontSize: layout == ServiceModeTilesLayout.list ? 14.sp : 13.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: layout == ServiceModeTilesLayout.list
                    ? 0.3
                    : 0.2,
              ),
            ),
          ),
          if (layout == ServiceModeTilesLayout.list)
            Padding(
              padding: EdgeInsets.only(left: 4.w, bottom: 14.h),
              child: Text(
                'pick_a_service_to_view'.tr,
                style: TextStyle(
                  color: AppConst.blackWithOpacity(0.42),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
            ),
        ],
        if (layout == ServiceModeTilesLayout.compactRow)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0) SizedBox(width: 10.w),
                Expanded(
                  child: _CompactServiceTile(
                    icon: _items[i].asset,
                    title: _items[i].title,
                    subtitle: _items[i].subtitle,
                    onTap: () => _open(_items[i].screen),
                  ),
                ),
              ],
            ],
          )
        else
          Column(
            children: [
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0) SizedBox(height: 12.h),
                _ListServiceTile(
                  icon: _items[i].asset,
                  title: _items[i].title,
                  subtitle: _items[i].subtitle,
                  index: i,
                  onTap: () => _open(_items[i].screen),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

enum _ModeScreen { ride, courier, delivery }

class _ServiceModeItem {
  const _ServiceModeItem({
    required this.asset,
    required this.title,
    required this.subtitle,
    required this.screen,
  });

  final String asset;
  final String title;
  final String subtitle;
  final _ModeScreen screen;
}

class _CompactServiceTile extends StatelessWidget {
  const _CompactServiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = AppConst.borderRadius;
    return Semantics(
      button: true,
      label: '${title.tr}. ${subtitle.tr}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: AppConst.blackWithOpacity(0.07),
              blurRadius: 14,
              offset: Offset(0, 5.h),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Material(
          color: AppConst.white,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashColor: AppConst.primaryColorWithOpacity(0.35),
            highlightColor: AppConst.blackWithOpacity(0.04),
            borderRadius: radius,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 14.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48.w,
                    height: 48.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppConst.blackWithOpacity(0.05),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Image.asset(
                      icon,
                      width: 26.w,
                      height: 26.h,
                      color: AppConst.black,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    title.tr,
                    style: TextStyle(
                      color: AppConst.black,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    subtitle.tr,
                    style: TextStyle(
                      color: AppConst.blackWithOpacity(0.48),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

class _ListServiceTile extends StatelessWidget {
  const _ListServiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.index,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16.r);
    return Semantics(
      button: true,
      label: '${title.tr}. ${subtitle.tr}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: AppConst.blackWithOpacity(0.08),
              blurRadius: 18,
              offset: Offset(0, 6.h),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Material(
          color: AppConst.white,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashColor: AppConst.primaryColorWithOpacity(0.28),
            highlightColor: AppConst.blackWithOpacity(0.03),
            borderRadius: radius,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4.w,
                    decoration: BoxDecoration(
                      color: AppConst.primaryColorWithOpacity(
                        0.55 + (index * 0.08).clamp(0.0, 0.22),
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16.r),
                        bottomLeft: Radius.circular(16.r),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(14.w, 14.h, 12.w, 14.h),
                      child: Row(
                        children: [
                          Container(
                            width: 54.w,
                            height: 54.w,
                            decoration: BoxDecoration(
                              color: AppConst.primaryColorWithOpacity(0.22),
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                            alignment: Alignment.center,
                            child: Image.asset(
                              icon,
                              width: 28.w,
                              height: 28.h,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  title.tr,
                                  style: TextStyle(
                                    color: AppConst.black,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  subtitle.tr,
                                  style: TextStyle(
                                    color: AppConst.blackWithOpacity(0.48),
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppConst.blackWithOpacity(0.38),
                            size: 28.sp,
                          ),
                        ],
                      ),
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
