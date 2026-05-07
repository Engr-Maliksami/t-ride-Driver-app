import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

/// Reusable top header used instead of the default AppBar.
/// Matches the black header design used on the language and auth screens.
class CustomAppBar extends StatelessWidget {
  final String title;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final double height;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.onBackPressed,
    this.height = 100,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(20.r),
        bottomRight: Radius.circular(20.r),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20.r),
            bottomRight: Radius.circular(20.r),
          ),
        ),
        child: Container(
          alignment: Alignment.bottomLeft,
          height: height.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: [
              if (showBackButton)
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24.sp,
                    ),
                    onPressed: onBackPressed ?? () => Get.back(),
                  ),
                ),
              if (showBackButton) SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  title.tr,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
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

// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:get/get.dart';
// import '../consts/appConst.dart';

// class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
//   final String title;
//   final bool showBackButton;
//   final VoidCallback? onBackPressed;
//   final List<Widget>? actions;
//   final bool showStatusBar;

//   const CustomAppBar({
//     super.key,
//     required this.title,
//     this.showBackButton = true,
//     this.onBackPressed,
//     this.actions,
//     this.showStatusBar = true,
//   });

//   @override
//   Size get preferredSize {
//     // Default size, will be adjusted in build method
//     final statusBarHeight = showStatusBar ? 24.h : 0;
//     final appBarHeight = 56.h;
//     return Size.fromHeight(statusBarHeight + appBarHeight);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final statusBarHeight = MediaQuery.of(context).padding.top;

//     return ClipRRect(
//       borderRadius: BorderRadius.only(
//         bottomLeft: Radius.circular(20.r),
//         bottomRight: Radius.circular(20.r),
//       ),
//       child: Container(
//         decoration: BoxDecoration(
//           color: AppConst.black,
//           borderRadius: BorderRadius.only(
//             bottomLeft: Radius.circular(20.r),
//             bottomRight: Radius.circular(20.r),
//           ),
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             // Status Bar (optional)
//             if (showStatusBar)
//               Container(
//                 height: statusBarHeight > 0 ? statusBarHeight : 24.h,
//                 padding: EdgeInsets.only(
//                   left: 20.w,
//                   right: 20.w,
//                   top: statusBarHeight > 0 ? 0 : 4.h,
//                   bottom: statusBarHeight > 0 ? 0 : 4.h,
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     // Time

//                     // Status Icons
//                   ],
//                 ),
//               ),
//             // AppBar Content
//             Container(
//               height: 56.h,
//               padding: EdgeInsets.symmetric(horizontal: 16.w),
//               child: Row(
//                 children: [
//                   // Back Button
//                   if (showBackButton)
//                     IconButton(
//                       padding: EdgeInsets.zero,
//                       constraints: BoxConstraints(),
//                       icon: Icon(
//                         Icons.arrow_back,
//                         color: AppConst.white,
//                         size: 24.sp,
//                       ),
//                       onPressed: onBackPressed ?? () => Get.back(),
//                     ),
//                   if (showBackButton) SizedBox(width: 12.w),
//                   // Title
//                   Expanded(
//                     child: Text(
//                       title,
//                       style: TextStyle(
//                         color: AppConst.white,
//                         fontSize: 20.sp,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                   // Actions
//                   if (actions != null) ...actions!,
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   String _getCurrentTime() {
//     final now = DateTime.now();
//     final hour = now.hour.toString().padLeft(2, '0');
//     final minute = now.minute.toString().padLeft(2, '0');
//     return '$hour:$minute';
//   }
// }
