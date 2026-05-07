import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:t_rider_services_app/consts/appConst.dart';
import 'package:t_rider_services_app/views/home/widgets/service_mode_tiles_section.dart';

/// Gallery tab — same Ride / Courier / Delivery shortcuts as home.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConst.scaffoldBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          child: const ServiceModeTilesSection(
            layout: ServiceModeTilesLayout.list,
            headerText: 'services',
          ),
        ),
      ),
    );
  }
}
