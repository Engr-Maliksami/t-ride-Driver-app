import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:t_rider_services_app/config/app_theme.dart';
import 'package:t_rider_services_app/controllers/app_language_controller.dart';
import 'package:t_rider_services_app/controllers/app_theme_controller.dart';
import 'package:t_rider_services_app/controllers/firestore_active_orders_listener.dart';
import 'package:t_rider_services_app/firebase_options.dart';
import 'package:t_rider_services_app/translations/app_translations.dart';
import 'package:t_rider_services_app/views/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Keep status bar icons/text fixed to white across the app.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appLanguageController = Get.put(AppLanguageController());
    final appThemeController = Get.put(AppThemeController());
    if (!Get.isRegistered<FirestoreActiveOrdersListener>()) {
      Get.put(FirestoreActiveOrdersListener(), permanent: true);
    }

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Obx(
          () => GetMaterialApp(
              key: ValueKey(appThemeController.themeMode.value),
              title: 'T Ride',
              debugShowCheckedModeBanner: false,
              translations: AppTranslations(),
              locale: appLanguageController.locale.value,
              fallbackLocale: const Locale('en'),
              supportedLocales: const [
                Locale('en'),
                Locale('ar'),
                Locale('es'),
                Locale('fr'),
                Locale('zh'),
              ],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: appThemeController.themeMode.value,
              builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
                value: const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                  statusBarBrightness: Brightness.dark,
                ),
                child: child ?? const SizedBox.shrink(),
              ),
              home: const SplashScreen(),
            ),
        );
      },
    );
  }
}
