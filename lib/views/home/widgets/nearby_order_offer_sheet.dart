import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:t_rider_services_app/data/directions/google_directions_service.dart';
import 'package:t_rider_services_app/models/nearby_order_map_offer.dart';
import 'package:t_rider_services_app/utils/order_route_markers_bitmap.dart';
import 'package:t_rider_services_app/views/home/widgets/order_trip_timeline.dart';

/// Draggable-sheet body matching the Uber-like “new ride” chrome (fair, timeline, rider).
class NearbyOrderOfferSheet extends StatelessWidget {
  const NearbyOrderOfferSheet({
    super.key,
    required this.offer,
    required this.route,
    required this.scrollController,
    required this.onViewDetails,
    required this.onDismiss,
  });

  final NearbyOrderMapOffer offer;
  final DrivingRouteSummary? route;

  /// From [DraggableScrollableSheet] builder.
  final ScrollController scrollController;

  final VoidCallback onViewDetails;
  final VoidCallback onDismiss;

  static String _fmtDuration(Duration d) {
    if (d.inHours >= 1) {
      final m = d.inMinutes.remainder(60);
      if (m <= 0) return '${d.inHours} hr';
      return '${d.inHours} hr $m min';
    }
    if (d.inMinutes < 1) return '${d.inSeconds.toString()}s';
    return '${d.inMinutes} min';
  }

  static String _fmtMi(int meters) {
    final mi = meters / 1609.344;
    return '${mi.toStringAsFixed(1)} mi';
  }

  @override
  Widget build(BuildContext context) {
    final localeTag = Get.locale?.toLanguageTag() ?? 'en_US';
    final pickupLabel = offer.pickupAddressShort();
    final destTitle = offer.destinationTitle();
    final rider = offer.riderDisplayName();
    final bonus = offer.formattedBonusUsd();
    final schedule = offer.scheduledOrCreatedLocal();

    final dateLine = schedule != null
        ? DateFormat('EEE, MMM d · h:mm a', localeTag).format(schedule)
        : 'map_order_schedule_unknown'.tr;

    final statsLine = route != null
        ? '${_fmtDuration(route!.duration)} · ${_fmtMi(route!.distanceMeters)}'
        : 'map_order_route_fallback'.tr;

    return Material(
      color: Colors.white,
      elevation: 16,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      child: SafeArea(
        top: false,
        child: ListView(
          controller: scrollController,
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(22.w, 10.h, 22.w, 20.h),
          children: [
            Center(
              child: Container(
                width: 42.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 16.h),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    offer.formattedFareUsd(),
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.9,
                      height: 1.05,
                    ),
                  ),
                ),
                if (bonus != null && bonus.trim().isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: 4.h),
                    child: Text(
                      'map_order_bonus_line'.tr.replaceAll(
                        '@amount',
                        '\$$bonus',
                      ),
                      style: TextStyle(
                        color: const Color(0xFF2E7D32),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            Divider(
              height: 28.h,
              thickness: 1,
              color: Colors.black.withValues(alpha: 0.07),
            ),
            OrderTripTimelineRows(
              pickupTimeLine: dateLine,
              pickupAddress: pickupLabel.isEmpty ? '—' : pickupLabel,
              tripStatsLine: statsLine,
              destinationTitle: destTitle.isEmpty
                  ? 'map_order_destination_fallback'.tr
                  : destTitle,
            ),
            Divider(
              height: 28.h,
              thickness: 1,
              color: Colors.black.withValues(alpha: 0.07),
            ),
            Text(
              'Name : $rider',
              style: TextStyle(
                color: Colors.black,
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8.h),
            // Row(
            //   children: [
            //     Icon(Icons.star_rounded, color: Colors.black87, size: 19.sp),
            //     SizedBox(width: 4.w),
            //     Text(
            //       rating != null ? rating.toStringAsFixed(1) : 'map_order_rating_unknown'.tr,
            //       style: TextStyle(
            //         color: Colors.black87,
            //         fontSize: 15.sp,
            //         fontWeight: FontWeight.w600,
            //       ),
            //     ),
            //   ],
            // ),
            SizedBox(height: 22.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      side: BorderSide(
                        color: Colors.black.withValues(alpha: 0.12),
                      ),
                      foregroundColor: Colors.black87,
                    ),
                    onPressed: onDismiss,
                    child: Text('cancel'.tr),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      backgroundColor: kOrderRoutePurple,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: onViewDetails,
                    child: Text('view'.tr),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
