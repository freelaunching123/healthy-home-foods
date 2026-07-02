import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

void main() async {
  debugPrint('--- FLUTTER STARTUP MAIN ---');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('WidgetsFlutterBinding initialized');
  
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
