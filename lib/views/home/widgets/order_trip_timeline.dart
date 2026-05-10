import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:t_rider_services_app/utils/order_route_markers_bitmap.dart';

/// Vertical pickup → destination timeline (Uber-style), shared by map offer sheet + ride detail.
class OrderTripTimelineRows extends StatelessWidget {
  const OrderTripTimelineRows({
    super.key,
    required this.pickupTimeLine,
    required this.pickupAddress,
    required this.tripStatsLine,
    required this.destinationTitle,
  });

  final String pickupTimeLine;
  final String pickupAddress;
  final String tripStatsLine;
  final String destinationTitle;

  @override
  Widget build(BuildContext context) {
    const purple = kOrderRoutePurple;

    Widget pickupGlyph() => Container(
          width: 14.w,
          height: 14.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: purple, width: 2),
          ),
        );

    Widget destGlyph() => Container(
          width: 26.w,
          height: 26.w,
          alignment: Alignment.center,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: purple),
          child: Container(
            width: 12.w,
            height: 12.w,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30.w,
          child: Column(
            children: [
              SizedBox(height: 6.h),
              pickupGlyph(),
              SizedBox(height: 8.h),
              Container(
                width: 3.2.w,
                height: 96.h.clamp(72.0, 140.0),
                decoration: BoxDecoration(
                  color: purple,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 8.h),
              destGlyph(),
            ],
          ),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pickupTimeLine,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                pickupAddress,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.45),
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w500,
                  height: 1.28,
                ),
              ),
              SizedBox(height: 28.h),
              Text(
                tripStatsLine,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                destinationTitle,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.45),
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w500,
                  height: 1.28,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
