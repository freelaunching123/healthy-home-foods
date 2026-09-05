import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────────────────
  late AnimationController _logoController;
  late AnimationController _ringController;
  late AnimationController _textController;
  late AnimationController _taglineController;
  late AnimationController _dotsController;
  late AnimationController _bgController;

  // ── Logo animations ───────────────────────────────────────────────────────
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;

  // ── Pulsing ring ─────────────────────────────────────────────────────────
  late Animation<double> _ringScale;
  late Animation<double> _ringOpacity;

  // ── Text slide-up ─────────────────────────────────────────────────────────
  late Animation<Offset> _textSlide;
  late Animation<double> _textFade;

  // ── Tagline fade ─────────────────────────────────────────────────────────
  late Animation<double> _taglineFade;

  // ── Dots loader ───────────────────────────────────────────────────────────
  late Animation<double> _dotsFade;

  // ── Background shimmer rotation ──────────────────────────────────────────
  late Animation<double> _bgRotation;

  bool _navDone = false;

  @override
  void initState() {
    super.initState();

    // Background slow rotation
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _bgRotation = Tween<double>(begin: 0, end: 2 * math.pi)
        .animate(_bgController);

    // Logo: elastic bounce-in over 900ms
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _logoController,
          curve: const Interval(0.0, 0.4, curve: Curves.easeIn)),
    );

    // Ring: continuous pulse
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: false);
    _ringScale = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOut),
    );
    _ringOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOut),
    );

    // Brand name text: slide up from below
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _textFade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));

    // Tagline fade in
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeIn),
    );

    // Dots loader fade in
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _dotsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _dotsController, curve: Curves.easeIn),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Start auth check in parallel — but enforce minimum 3500ms on screen
    final authFuture = _fetchAuthDestination();

    // t=0ms  : logo bounces in
    _logoController.forward();

    // t=700ms: text slides up
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    _textController.forward();

    // t=1100ms: tagline fades in
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _taglineController.forward();

    // t=1500ms: dots appear
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _dotsController.forward();

    // Enforce minimum 3500ms total screen time
    final results = await Future.wait([
      authFuture,
      Future.delayed(const Duration(milliseconds: 3500)),
    ]);

    if (!mounted || _navDone) return;
    _navDone = true;
    final destination = results[0] as String;
    context.go(destination);
  }

  Future<String> _fetchAuthDestination() async {
    final authService = AuthService();
    final isLoggedIn = await authService.isLoggedIn();
    if (!isLoggedIn) return '/login';
    final role = await authService.getUserRole();
    switch (role) {
      case 'super_admin':
      case 'admin':
        return '/admin';
      case 'delivery_partner':
        return '/delivery';
      default:
        return '/home';
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _ringController.dispose();
    _textController.dispose();
    _taglineController.dispose();
    _dotsController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A2E0F),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _bgRotation,
          _logoScale,
          _logoFade,
          _ringScale,
          _ringOpacity,
          _textSlide,
          _textFade,
          _taglineFade,
          _dotsFade,
        ]),
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // ── Rotating radial background ──────────────────────────────
              _buildBackground(),

              // ── Content ─────────────────────────────────────────────────
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),

                  // Glowing ring + logo
                  _buildLogoSection(),

                  const SizedBox(height: 36),

                  // Brand name
                  SlideTransition(
                    position: _textSlide,
                    child: FadeTransition(
                      opacity: _textFade,
                      child: const Text(
                        'Healthy Home Foods',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Tagline
                  FadeTransition(
                    opacity: _taglineFade,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF81C784).withValues(alpha: 0.5),
                            width: 1),
                        color: const Color(0xFF81C784).withValues(alpha: 0.08),
                      ),
                      child: const Text(
                        '✦  Fresh  •  Healthy  •  Delivered  ✦',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFA5D6A7),
                          letterSpacing: 2.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Animated dots loader
                  FadeTransition(
                    opacity: _dotsFade,
                    child: const _DotsLoader(),
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackground() {
    return Transform.rotate(
      angle: _bgRotation.value,
      child: CustomPaint(
        painter: _RadialPainter(),
      ),
    );
  }

  Widget _buildLogoSection() {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse ring
          Transform.scale(
            scale: _ringScale.value,
            child: Opacity(
              opacity: _ringOpacity.value,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF66BB6A),
                    width: 2.5,
                  ),
                ),
              ),
            ),
          ),

          // Inner static glow ring
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF2E7D32).withValues(alpha: 0.6),
                  const Color(0xFF1B5E20).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),

          // Logo card
          ScaleTransition(
            scale: _logoScale,
            child: FadeTransition(
              opacity: _logoFade,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF66BB6A).withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(18),
                child: Image.asset('assets/logo.png', fit: BoxFit.contain),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated three-dot loader ─────────────────────────────────────────────────
class _DotsLoader extends StatefulWidget {
  const _DotsLoader();

  @override
  State<_DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<_DotsLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final t = ((_ctrl.value - delay) % 1.0 + 1.0) % 1.0;
            final scale = 0.6 + 0.4 * math.sin(t * math.pi);
            final opacity = 0.3 + 0.7 * math.sin(t * math.pi);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF81C784),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Radial background painter ─────────────────────────────────────────────────
class _RadialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.longestSide * 0.9;

    for (int i = 5; i >= 1; i--) {
      final fraction = i / 5;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(const Color(0xFF2E7D32), const Color(0xFF0A2E0F),
                    1 - fraction)!
                .withValues(alpha: 0.15 * fraction),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
      canvas.drawCircle(center, maxRadius * fraction, paint);
    }

    // Subtle ray lines
    final rayPaint = Paint()
      ..color = const Color(0xFF388E3C).withValues(alpha: 0.06)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * math.pi;
      canvas.drawLine(
        center,
        Offset(
          center.dx + math.cos(angle) * maxRadius,
          center.dy + math.sin(angle) * maxRadius,
        ),
        rayPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
