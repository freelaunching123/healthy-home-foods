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
  debugPrint('WidgetsFlutterBinding initialized');
  
  // Initialize Firebase and FCM
  try {
    if (!kIsWeb) {
      await Firebase.initializeApp();
      debugPrint('Firebase initialized');
      await FcmService().initialize();
      debugPrint('FcmService initialized');
    } else {
      debugPrint('Firebase/FCM is bypassed on Web platform');
    }
  } catch (e) {
    debugPrint('Error initializing Firebase/FCM: $e');
  }
  
  // Lock to portrait
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    debugPrint('Preferred orientations set');
  } catch (e) {
    debugPrint('Error setting preferred orientations: $e');
  }

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  debugPrint('SystemUIOverlayStyle set');

  runApp(const ProviderScope(child: HealthyHomeFoodsApp()));
  debugPrint('runApp called');
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
