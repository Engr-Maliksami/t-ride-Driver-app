import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:t_rider_services_app/consts/appConst.dart';
import 'package:t_rider_services_app/data/models/order_active_status_model.dart';
import 'package:t_rider_services_app/data/repositories/rides_repository.dart';
import 'package:t_rider_services_app/views/home/finding_food_delivery_screen.dart';
import 'package:t_rider_services_app/views/home/finding_ride_requests_screen.dart';

/// Active ride / courier / food snapshot with refresh — same UX as home.
///
/// [previewCardLimit]: when non-null and there are more cards than this,
/// shows "Show all" / "Show less". When null, every card is listed.
class ActiveOrdersSection extends StatefulWidget {
  const ActiveOrdersSection({super.key, this.previewCardLimit = 3});

  final int? previewCardLimit;

  @override
  State<ActiveOrdersSection> createState() => _ActiveOrdersSectionState();
}

class _ActiveOrdersSectionState extends State<ActiveOrdersSection> {
  final RidesRepository _ridesRepository = RidesRepository();
  OrderActiveStatusResponse? _activeOrders;
  bool _activeOrdersLoading = true;
  bool _showAllActiveOrders = false;

  @override
  void initState() {
    super.initState();
    _fetchActiveOrders();
  }

  Future<void> _fetchActiveOrders() async {
    setState(() => _activeOrdersLoading = true);
    try {
      final data = await _ridesRepository.getActiveOrderStatus();
      if (!mounted) return;
      setState(() {
        _activeOrders = data;
        _activeOrdersLoading = false;
        _showAllActiveOrders = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activeOrders = null;
        _activeOrdersLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'active_orders'.tr,
              style: TextStyle(
                color: AppConst.black,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (!_activeOrdersLoading)
              GestureDetector(
                onTap: _fetchActiveOrders,
                child: Icon(
                  Icons.refresh,
                  size: 22.sp,
                  color: AppConst.blackWithOpacity(0.65),
                ),
              ),
          ],
        ),
        SizedBox(height: 12.h),
        if (_activeOrdersLoading)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24.h),
            child: Center(
              child: SizedBox(
                width: 28.w,
                height: 28.w,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_activeOrders == null)
          Text(
            'could_not_load_active_orders'.tr,
            style: TextStyle(
              color: AppConst.blackWithOpacity(0.55),
              fontSize: 13.sp,
            ),
          )
        else
          _buildActiveOrderCards(_activeOrders!),
      ],
    );
  }

  List<Widget> _collectActiveOrderCards(OrderActiveStatusResponse r) {
    final cards = <Widget>[];
    if (r.ride != null) {
      cards.add(_activeServiceOrderCard('ride'.tr, r.ride!));
    }
    if (r.courier != null) {
      cards.add(_activeServiceOrderCard('courier'.tr, r.courier!));
    }
    if (r.foodOrder != null) {
      cards.add(_activeFoodOrderCard(r.foodOrder!));
    }
    return cards;
  }

  Widget _buildActiveOrderCards(OrderActiveStatusResponse r) {
    final cards = _collectActiveOrderCards(r);

    if (cards.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'online_waiting_for_requests'.tr,
            style: TextStyle(
              color: AppConst.black,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'move_to_busy_area_hint'.tr,
            style: TextStyle(
              color: AppConst.blackWithOpacity(0.6),
              fontSize: 12.sp,
            ),
          ),
        ],
      );
    }

    final limit = widget.previewCardLimit;
    final hasMore = limit != null && cards.length > limit;
    final visibleCount = limit == null || _showAllActiveOrders || !hasMore
        ? cards.length
        : limit;
    final visibleCards = cards.take(visibleCount).toList();

    final children = <Widget>[];
    for (var i = 0; i < visibleCards.length; i++) {
      if (i > 0) {
        children.add(SizedBox(height: 10.h));
      }
      children.add(visibleCards[i]);
    }

    if (hasMore) {
      children.add(SizedBox(height: 12.h));
      children.add(
        Center(
          child: TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                _showAllActiveOrders = !_showAllActiveOrders;
              });
            },
            child: Text(
              _showAllActiveOrders ? 'show_less'.tr : '${'show_all'.tr} (${cards.length})',
              style: TextStyle(
                color: AppConst.black,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  String _activeOrderStatusBadgeLabel(String? status) {
    final raw = (status ?? '').trim();
    if (raw.isEmpty) return '—';
    if (raw.toLowerCase() == 'searching') return 'pending'.tr.toUpperCase();
    return raw.toUpperCase();
  }

  Future<void> _onActiveServiceCardTap(
    String typeLabel,
    ActiveRideCourierOrder o,
  ) async {
    HapticFeedback.lightImpact();
    await Get.to(() => FindingRideRequestsScreen(ride: o));
    if (mounted) _fetchActiveOrders();
  }

  Future<void> _onActiveFoodCardTap(ActiveFoodOrder o) async {
    HapticFeedback.lightImpact();
    await Get.to(() => FindingFoodDeliveryScreen(order: o));
    if (mounted) _fetchActiveOrders();
  }

  Widget _activeServiceOrderCard(String typeLabel, ActiveRideCourierOrder o) {
    final driverName = o.driver?.displayName;
    return Material(
      color: AppConst.white,
      borderRadius: AppConst.borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onActiveServiceCardTap(typeLabel, o),
        splashColor: AppConst.primaryColorWithOpacity(0.35),
        highlightColor: AppConst.blackWithOpacity(0.04),
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppConst.primaryColorWithOpacity(0.35),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        color: AppConst.black,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    o.rideCustomId ?? '—',
                    style: TextStyle(
                      color: AppConst.blackWithOpacity(0.75),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Text(
                o.pickupAddress ?? 'pickup'.tr,
                style: TextStyle(
                  color: AppConst.blackWithOpacity(0.85),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: Icon(
                  Icons.south,
                  size: 16.sp,
                  color: AppConst.blackWithOpacity(0.4),
                ),
              ),
              Text(
                o.dropoffAddress ?? 'dropoff'.tr,
                style: TextStyle(
                  color: AppConst.blackWithOpacity(0.85),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppConst.blackWithOpacity(0.07),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      _activeOrderStatusBadgeLabel(o.status),
                      style: TextStyle(
                        color: AppConst.black,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (o.fare != null && o.fare!.isNotEmpty)
                    Text(
                      o.fare!,
                      style: TextStyle(
                        color: AppConst.black,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              if (typeLabel == 'courier'.tr &&
                  (o.receiverName != null || o.packageSize != null)) ...[
                SizedBox(height: 8.h),
                Text(
                  [
                    if (o.packageSize != null) o.packageSize,
                    if (o.receiverName != null) '${'to'.tr}: ${o.receiverName}',
                  ].whereType<String>().join(' • '),
                  style: TextStyle(
                    color: AppConst.blackWithOpacity(0.55),
                    fontSize: 11.sp,
                  ),
                ),
              ],
              if (driverName != null) ...[
                SizedBox(height: 8.h),
                Text(
                  '${'driver'.tr}: $driverName',
                  style: TextStyle(
                    color: AppConst.blackWithOpacity(0.55),
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _activeFoodOrderCard(ActiveFoodOrder o) {
    final vendorName = o.vendor?.name;
    return Material(
      color: AppConst.white,
      borderRadius: AppConst.borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onActiveFoodCardTap(o),
        splashColor: AppConst.primaryColorWithOpacity(0.35),
        highlightColor: AppConst.blackWithOpacity(0.04),
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppConst.primaryColorWithOpacity(0.35),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      'delivery'.tr,
                      style: TextStyle(
                        color: AppConst.black,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    o.orderCode ?? '—',
                    style: TextStyle(
                      color: AppConst.blackWithOpacity(0.75),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (vendorName != null) ...[
                SizedBox(height: 10.h),
                Text(
                  vendorName,
                  style: TextStyle(
                    color: AppConst.black,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              SizedBox(height: 8.h),
              Text(
                o.deliveryAddress ?? '—',
                style: TextStyle(
                  color: AppConst.blackWithOpacity(0.85),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppConst.blackWithOpacity(0.07),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      _activeOrderStatusBadgeLabel(o.status),
                      style: TextStyle(
                        color: AppConst.black,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (o.totalAmount != null && o.totalAmount!.isNotEmpty)
                    Text(
                      o.totalAmount!,
                      style: TextStyle(
                        color: AppConst.black,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              if (o.items.isNotEmpty) ...[
                SizedBox(height: 8.h),
                Text(
                  o.items
                      .map(
                        (e) => '${e.quantity ?? 0}× ${e.productName ?? 'item'.tr}',
                      )
                      .take(3)
                      .join(', '),
                  style: TextStyle(
                    color: AppConst.blackWithOpacity(0.55),
                    fontSize: 11.sp,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
