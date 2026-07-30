import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.asset('assets/videos/splash.mp4');
    
    try {
      await _videoController.initialize();
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
      _videoController.play();
      
      // Wait for 8 seconds as requested
      await Future.delayed(const Duration(seconds: 8));
      
      if (mounted && !_isNavigating) {
        _isNavigating = true;
        _checkAuth();
      }
    } catch (e) {
      debugPrint('Error playing splash video: $e');
      // Fallback in case video fails to load
      await Future.delayed(const Duration(seconds: 2));
      if (mounted && !_isNavigating) {
        _isNavigating = true;
        _checkAuth();
      }
    }
  }

  Future<void> _checkAuth() async {
    final authService = AuthService();
    final isLoggedIn = await authService.isLoggedIn();

    if (!mounted) return;

    if (isLoggedIn) {
      final role = await authService.getUserRole();
      if (!mounted) return;
      switch (role) {
        case 'super_admin':
        case 'admin':
          context.go('/admin');
          break;
        case 'delivery_partner':
          context.go('/delivery');
          break;
        default:
          context.go('/home');
      }
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _isVideoInitialized 
            ? SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController.value.size.width,
                    height: _videoController.value.size.height,
                    child: VideoPlayer(_videoController),
                  ),
                ),
              )
            : const CircularProgressIndicator(color: AppTheme.primaryGreen),
      ),
    );
  }
}
