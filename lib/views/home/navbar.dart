import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:t_rider_services_app/consts/appConst.dart';
import 'package:t_rider_services_app/views/profile_screen/profile_screen.dart';
import 'home_screen.dart';
import 'gallery_screen.dart';
import 'nearby_firestore_orders_screen.dart';
import 'tasks_screen.dart';

class Navbar extends StatefulWidget {
  const Navbar({super.key});

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  int _currentIndex = 0;

  final GlobalKey<HomeScreenState> _homeScreenKey =
      GlobalKey<HomeScreenState>();

  late final List<Widget> _screens = [
    HomeScreen(key: _homeScreenKey),
    const TasksScreen(),
    const NearbyFirestoreOrdersScreen(),
    const GalleryScreen(),
    // Profile Screen
    ProfileScreen(),
  ];

  void _selectIndex(int index) {
    final switchedTab = _currentIndex != index;
    setState(() {
      _currentIndex = index;
    });
    if (index == 0 && switchedTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _homeScreenKey.currentState?.refreshDashboard();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppConst.white,
          boxShadow: [
            BoxShadow(
              color: AppConst.blackWithOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            height: 55.h,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(icon: Icons.home, index: 0),
                _buildNavItem(icon: Icons.list, index: 1),
                _buildNavItem(icon: Icons.grid_view, index: 3),
                _buildNavItem(icon: Icons.person, index: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required int index}) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _selectIndex(index),
      child: Container(
        padding: EdgeInsets.all(8.w),
        child: Icon(
          icon,
          color: isSelected ? AppConst.black : AppConst.blackWithOpacity(0.5),
          size: 24.sp,
        ),
      ),
    );
  }

  // Widget _buildCenterButton() {
  //   return GestureDetector(
  //     onTap: () => _selectIndex(2),
  //     child: Container(
  //       width: 65.w,
  //       height: 65.w,
  //       decoration: BoxDecoration(
  //         shape: BoxShape.circle,
  //         color: AppConst.black,
  //         boxShadow: [
  //           BoxShadow(
  //             color: AppConst.blackWithOpacity(0.3),
  //             blurRadius: 8,
  //             offset: const Offset(0, 4),
  //           ),
  //         ],
  //       ),
  //       child: Center(
  //         child: Column(
  //           mainAxisAlignment: MainAxisAlignment.center,
  //           children: [
  //             Icon(
  //               Icons.keyboard_arrow_down_sharp,
  //               size: 24.sp,
  //               color: AppConst.white,
  //             ),
  //             Text(
  //               'order'.tr,
  //               textAlign: TextAlign.center,
  //               style: TextStyle(
  //                 color: AppConst.white,
  //                 fontSize: 11.sp,
  //                 fontWeight: FontWeight.w700,
  //               ),
  //             ),
  //             SizedBox(height: 10.h),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }
}
