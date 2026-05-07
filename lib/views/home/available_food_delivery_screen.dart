import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:t_rider_services_app/consts/appConst.dart';
import 'package:t_rider_services_app/data/models/order_active_status_model.dart';
import 'package:t_rider_services_app/data/repositories/rides_repository.dart';
import 'package:t_rider_services_app/views/home/finding_food_delivery_screen.dart';

class AvailableFoodDeliveryScreen extends StatefulWidget {
  const AvailableFoodDeliveryScreen({super.key});

  @override
  State<AvailableFoodDeliveryScreen> createState() =>
      _AvailableFoodDeliveryScreenState();
}

class _AvailableFoodDeliveryScreenState
    extends State<AvailableFoodDeliveryScreen> {
  final RidesRepository _ridesRepository = RidesRepository();
  List<ActiveFoodOrder> _orders = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final list = await _ridesRepository.getActiveFoodOrders();
      if (!mounted) return;
      setState(() {
        _orders = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _orders = [];
        _loading = false;
        _errorMessage = 'could_not_load_delivery_orders'.tr;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConst.scaffoldBackground,
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppConst.brandedHeader,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20.r),
                bottomRight: Radius.circular(20.r),
              ),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8.h,
              left: 8.w,
              right: 16.w,
              bottom: 20.h,
            ),
            child: Row(
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: AppConst.brandedHeaderForeground,
                      size: 24.sp,
                    ),
                    onPressed: () => Get.back(),
                  ),
                ),
                Expanded(
                  child: Text(
                    'available_deliveries'.tr,
                    style: TextStyle(
                      color: AppConst.brandedHeaderForeground,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: AppConst.brandedHeaderForeground,
                    size: 22.sp,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _load();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppConst.black,
              onRefresh: _load,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 120.h),
          Center(
            child: SizedBox(
              width: 32.w,
              height: 32.w,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
        children: [
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppConst.blackWithOpacity(0.75),
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 16.h),
          Align(
            child: TextButton(
              onPressed: _load,
              child: Text(
                'retry'.tr,
                style: TextStyle(
                  color: AppConst.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 15.sp,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 48.h),
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 56.sp,
            color: AppConst.blackWithOpacity(0.35),
          ),
          SizedBox(height: 16.h),
          Text(
            'no_delivery_orders'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppConst.black,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'pull_to_refresh'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppConst.blackWithOpacity(0.55),
              fontSize: 13.sp,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 28.h),
      itemCount: _orders.length,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (context, i) {
        final order = _orders[i];
        return _FoodDeliveryListCard(
          order: order,
          onOpen: () async {
            HapticFeedback.lightImpact();
            await Get.to(() => FindingFoodDeliveryScreen(order: order));
            if (mounted) _load();
          },
        );
      },
    );
  }
}

String _foodDeliveryStatusPillLabel(String? apiStatus) {
  final raw = (apiStatus ?? '').trim();
  if (raw.isEmpty) return 'unknown'.tr;
  if (raw.toLowerCase() == 'searching') return 'pending'.tr;
  return raw
      .split(RegExp(r'[\s_]+'))
      .where((w) => w.isNotEmpty)
      .map(
        (w) =>
            '${w[0].toUpperCase()}${w.length > 1 ? w.substring(1).toLowerCase() : ''}',
      )
      .join(' ');
}

({Color background, Color foreground}) _foodDeliveryStatusPillColors(
  String? apiStatus,
) {
  final s = (apiStatus ?? '').toLowerCase().replaceAll(' ', '_');
  if (s == 'searching' || s == 'pending') {
    return (
      background: AppConst.primaryColorWithOpacity(0.45),
      foreground: AppConst.black,
    );
  }
  if (s == 'accepted' || s == 'in_progress' || s == 'started') {
    return (
      background: const Color(0xFFE8F5E9),
      foreground: const Color(0xFF1B5E20),
    );
  }
  if (s == 'completed' || s == 'done') {
    return (
      background: AppConst.blackWithOpacity(0.08),
      foreground: AppConst.black,
    );
  }
  if (s == 'cancelled' || s == 'canceled' || s == 'rejected') {
    return (
      background: const Color(0xFFFFEBEE),
      foreground: const Color(0xFFB71C1C),
    );
  }
  return (
    background: AppConst.blackWithOpacity(0.07),
    foreground: AppConst.black.withValues(alpha: 0.85),
  );
}

class _FoodDeliveryListCard extends StatelessWidget {
  const _FoodDeliveryListCard({required this.order, required this.onOpen});

  final ActiveFoodOrder order;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final radius = AppConst.borderRadius;
    final pillStyle = _foodDeliveryStatusPillColors(order.status);
    final pillLabel = _foodDeliveryStatusPillLabel(order.status);
    final vendorName = order.vendor?.name;
    final metaParts = <String>[];
    if (order.totalItems != null) {
      metaParts.add('${order.totalItems} items');
    } else if (order.items.isNotEmpty) {
      metaParts.add('${order.items.length} items');
    }
    if ((order.deliveryFee ?? '').trim().isNotEmpty) {
      metaParts.add('fee ${order.deliveryFee!.trim()}');
    }

    final fromParts = <String>[];
    if ((vendorName ?? '').trim().isNotEmpty) {
      fromParts.add(vendorName!.trim());
    }
    if ((order.vendor?.address ?? '').trim().isNotEmpty) {
      fromParts.add(order.vendor!.address!.trim());
    }
    final fromText =
        fromParts.isNotEmpty ? fromParts.join(', ') : 'restaurant'.tr;

    return Material(
      color: AppConst.white,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        splashColor: AppConst.primaryColorWithOpacity(0.35),
        highlightColor: AppConst.blackWithOpacity(0.04),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppConst.primaryColorWithOpacity(0.35),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        order.orderCode ?? 'order'.tr,
                        style: TextStyle(
                          color: AppConst.black,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    order.totalAmount ?? '',
                    style: TextStyle(
                      color: AppConst.black,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Text(
                '${'from'.tr}:',
                style: TextStyle(
                  color: AppConst.blackWithOpacity(0.45),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                fromText,
                style: TextStyle(
                  color: AppConst.blackWithOpacity(0.85),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 10.h),
              Text(
                '${'to'.tr}:',
                style: TextStyle(
                  color: AppConst.blackWithOpacity(0.45),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                (order.deliveryAddress ?? '').trim().isEmpty
                    ? '—'
                    : order.deliveryAddress!.trim(),
                style: TextStyle(
                  color: AppConst.blackWithOpacity(0.85),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (metaParts.isNotEmpty) ...[
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 14.sp,
                      color: AppConst.blackWithOpacity(0.45),
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        metaParts.join(' · '),
                        style: TextStyle(
                          color: AppConst.blackWithOpacity(0.5),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: pillStyle.background,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  pillLabel,
                  style: TextStyle(
                    color: pillStyle.foreground,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Text(
                    order.paymentMethod ?? '',
                    style: TextStyle(
                      color: AppConst.blackWithOpacity(0.5),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'open'.tr,
                    style: TextStyle(
                      color: AppConst.black,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppConst.black, size: 20.sp),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
