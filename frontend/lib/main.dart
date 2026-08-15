import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/fcm_service.dart';

void main() async {
  debugPrint('--- FLUTTER STARTUP MAIN ---');
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock to portrait
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (e) {
    debugPrint('Error setting preferred orientations: $e');
  }

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Render UI immediately for instant startup
  runApp(const ProviderScope(child: HealthyHomeFoodsApp()));
  debugPrint('runApp called');

  // Initialize Firebase and FCM asynchronously in background without blocking UI
  if (!kIsWeb) {
    Future.microtask(() async {
      try {
        await Firebase.initializeApp();
        debugPrint('Firebase initialized');
        await FcmService().initialize();
        debugPrint('FcmService initialized');
      } catch (e) {
        debugPrint('Error initializing Firebase/FCM: $e');
      }
    });
  }
}

class HealthyHomeFoodsApp extends StatelessWidget {
  const HealthyHomeFoodsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Healthy Home Foods',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
