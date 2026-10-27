import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/session_manager.dart';
import 'main_navigation_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _driveController;
  late AnimationController _entranceController;
  late Animation<double> _wheelRotation;
  late Animation<double> _roadOffset;
  late Animation<double> _suspensionBounce;
  late Animation<double> _truckEntrance;

  @override
  void initState() {
    super.initState();

    // Continuous driving motion
    _driveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _wheelRotation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(parent: _driveController, curve: Curves.linear));

    _roadOffset = Tween<double>(
      begin: 0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _driveController, curve: Curves.linear));

    // Subtle realistic vehicle suspension bobbing
    _suspensionBounce = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -1.8), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -1.8, end: 0.2), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.2, end: -0.8), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -0.8, end: 0.0), weight: 20),
    ]).animate(_driveController);

    // Smooth entry slide & fade
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _truckEntrance = Tween<double>(begin: -50.0, end: 0.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );

    _entranceController.forward();

    // Auto transition: If already registered, goes DIRECTLY to Live Map like Bolt!
    Future.delayed(const Duration(milliseconds: 2700), () async {
      if (mounted) {
        final isLoggedIn = await SessionManager.isLoggedIn();
        final savedUser = await SessionManager.getUser();

        if (!mounted) return;
        if (isLoggedIn && savedUser != null) {
          // Direct entry to Live Map!
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  MainNavigationScreen(user: savedUser),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) => FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        } else {
          // First time registration flow
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const LoginScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) => FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _driveController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFFF2F5F1),
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F5F1),
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),

              // Center Area: Premium Realistic Cargo Truck & Typography
              Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _driveController,
                    _entranceController,
                  ]),
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        _truckEntrance.value,
                        _suspensionBounce.value,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Truck & Road Stage
                          SizedBox(
                            width: 280,
                            height: 140,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Subtle speed air streams
                                Positioned(
                                  left: 16,
                                  top: 48,
                                  child: Container(
                                    width:
                                        40 +
                                        (math.sin(
                                              _driveController.value *
                                                  math.pi *
                                                  2,
                                            ) *
                                            8),
                                    height: 2,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Color(0xFF94A3B8),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 32,
                                  top: 68,
                                  child: Container(
                                    width:
                                        28 +
                                        (math.cos(
                                              _driveController.value *
                                                  math.pi *
                                                  2,
                                            ) *
                                            6),
                                    height: 1.5,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Color(0xFF94A3B8),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ),

                                // Headlight beam illumination on ground
                                Positioned(
                                  right: 10,
                                  bottom: 22,
                                  child: Opacity(
                                    opacity: 0.65,
                                    child: Container(
                                      width: 65,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            const Color(0xFFFEF08A)
                                                .withValues(alpha: 0.6),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Realistic Vector Truck Graphic
                                CustomPaint(
                                  size: const Size(220, 95),
                                  painter: RealisticTruckPainter(
                                    wheelAngle: _wheelRotation.value,
                                  ),
                                ),

                                // Asphalt Road & Dashed Centerline
                                Positioned(
                                  bottom: 6,
                                  child: SizedBox(
                                    width: 240,
                                    height: 6,
                                    child: CustomPaint(
                                      painter: RealisticRoadPainter(
                                        offset: _roadOffset.value,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 22),

                          // Sleek Brand Typography
                          const Text(
                            'CARGOO',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 5.0,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const Spacer(flex: 3),

              // Footer Motto
              Padding(
                padding: const EdgeInsets.only(bottom: 28.0),
                child: const Text(
                  'EVERY LOAD. EVERY JOURNEY.',
                  style: TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                    color: Color(0xFF475569),
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

/// High-fidelity, modern realistic cargo truck painter (no cartoon look)
class RealisticTruckPainter extends CustomPainter {
  final double wheelAngle;

  RealisticTruckPainter({required this.wheelAngle});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Ambient Drop Shadow underneath truck
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 76, 185, 8),
        const Radius.circular(4),
      ),
      shadowPaint,
    );

    // 2. Chassis Rail & Underbody Mechanicals
    final chassisPaint = Paint()..color = const Color(0xFF1E293B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(26, 62, 168, 8),
        const Radius.circular(2),
      ),
      chassisPaint,
    );

    // Fuel Tank / Tool box (Metallic finish)
    final tankRect = const Rect.fromLTWH(76, 57, 36, 12);
    final tankPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF64748B), Color(0xFF334155), Color(0xFF1E293B)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(tankRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(tankRect, const Radius.circular(3)),
      tankPaint,
    );

    // Fuel tank strap
    final strapPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(85, 57), const Offset(85, 69), strapPaint);
    canvas.drawLine(const Offset(102, 57), const Offset(102, 69), strapPaint);

    // 3. Cargo Box (Semi-trailer body with realistic gradient & panel grooves)
    final boxRect = const Rect.fromLTWH(16, 12, 122, 53);
    final boxPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF5A8EAF), Color(0xFF4B7B9F), Color(0xFF3B6482)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(boxRect);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        boxRect,
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(3),
        bottomLeft: const Radius.circular(3),
        bottomRight: const Radius.circular(3),
      ),
      boxPaint,
    );

    // Top roof fairing highlight
    final roofHighlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 2.0;
    canvas.drawLine(const Offset(18, 13), const Offset(136, 13), roofHighlight);

    // Realistic vertical rib panels on cargo body
    final ribDark = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;
    final ribLight = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 1.0;
    for (double x = 32; x <= 124; x += 15) {
      canvas.drawLine(Offset(x, 14), Offset(x, 63), ribDark);
      canvas.drawLine(Offset(x + 1, 14), Offset(x + 1, 63), ribLight);
    }

    // Modern CARGOO subtle white brand insignia on the side
    final logoBg = Paint()..color = Colors.white.withValues(alpha: 0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(26, 26, 48, 16),
        const Radius.circular(4),
      ),
      logoBg,
    );
    // Speed stripe on cargo box
    final stripePaint = Paint()
      ..color = const Color(0xFF22C55E).withValues(alpha: 0.85)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(28, 48), const Offset(118, 48), stripePaint);

    // 4. Cab Mount / Coupler
    final couplerPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRect(const Rect.fromLTWH(138, 38, 8, 25), couplerPaint);

    // 5. Aerodynamic Modern Truck Cab (Sleek contemporary shape)
    final cabPath = Path();
    cabPath.moveTo(144, 65); // bottom rear
    cabPath.lineTo(144, 18); // rear upright
    cabPath.lineTo(156, 16); // roof wind deflector start
    cabPath.lineTo(175, 18); // roof slope
    cabPath.lineTo(194, 38); // raked aerodynamic windshield
    cabPath.lineTo(198, 45); // front grille angle
    cabPath.lineTo(198, 62); // front bumper
    cabPath.lineTo(188, 65); // lower air dam
    cabPath.close();

    final cabRect = const Rect.fromLTWH(144, 16, 54, 50);
    final cabPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF334155), Color(0xFF1E293B), Color(0xFF0F172A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(cabRect);
    canvas.drawPath(cabPath, cabPaint);

    // Tinted Aero Windshield Glass
    final glassPath = Path();
    glassPath.moveTo(164, 22);
    glassPath.lineTo(174, 22);
    glassPath.lineTo(190, 39);
    glassPath.lineTo(164, 39);
    glassPath.close();

    final glassRect = const Rect.fromLTWH(164, 22, 26, 17);
    final glassPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF93C5FD), Color(0xFF38BDF8), Color(0xFF1E293B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(glassRect);
    canvas.drawPath(glassPath, glassPaint);

    // Windshield reflection diagonal
    final glarePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 2.0;
    canvas.drawLine(const Offset(170, 24), const Offset(182, 38), glarePaint);

    // Side window
    final sideWindow = Path();
    sideWindow.moveTo(150, 24);
    sideWindow.lineTo(161, 24);
    sideWindow.lineTo(161, 38);
    sideWindow.lineTo(150, 38);
    sideWindow.close();
    final sideGlassPaint = Paint()..color = const Color(0xFF334155);
    canvas.drawPath(sideWindow, sideGlassPaint);

    // Aerodynamic Side Mirror
    final mirrorPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(165, 30, 4, 10),
        const Radius.circular(1.5),
      ),
      mirrorPaint,
    );

    // Front Modern LED Headlight & DRL strip
    final headlightPaint = Paint()..color = const Color(0xFFFDE047);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(195, 46, 3.5, 8),
        const Radius.circular(1.5),
      ),
      headlightPaint,
    );

    // Chrome front grille slots
    final grillePaint = Paint()
      ..color = const Color(0xFF64748B)
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(188, 52), const Offset(196, 52), grillePaint);
    canvas.drawLine(const Offset(188, 56), const Offset(196, 56), grillePaint);

    // 6. Realistic Alloy Wheels with disc brakes & bolt patterns
    _drawRealisticWheel(canvas, const Offset(42, 68), 14, wheelAngle);
    _drawRealisticWheel(canvas, const Offset(96, 68), 14, wheelAngle);
    _drawRealisticWheel(canvas, const Offset(168, 68), 14, wheelAngle);
  }

  void _drawRealisticWheel(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
  ) {
    // Tire Rubber (Dark textured charcoal)
    final tirePaint = Paint()..color = const Color(0xFF18181B);
    canvas.drawCircle(center, radius, tirePaint);

    // Tire tread outer ring
    final treadRing = Paint()
      ..color = const Color(0xFF27272A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(center, radius - 1, treadRing);

    // Alloy Rim Outer Lip (Silver/Graphite metallic)
    final rimLipPaint = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0xFFE2E8F0), Color(0xFF94A3B8), Color(0xFF475569)],
        stops: const [0.6, 0.85, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.75));
    canvas.drawCircle(center, radius * 0.72, rimLipPaint);

    // Brake Disc inside
    final discPaint = Paint()..color = const Color(0xFF334155);
    canvas.drawCircle(center, radius * 0.52, discPaint);

    // Rotating 5-Spoke Alloy Rim
    final spokePaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 5; i++) {
      final spokeAngle = angle + (i * 2 * math.pi / 5);
      final innerX = center.dx + math.cos(spokeAngle) * (radius * 0.22);
      final innerY = center.dy + math.sin(spokeAngle) * (radius * 0.22);
      final outerX = center.dx + math.cos(spokeAngle) * (radius * 0.65);
      final outerY = center.dy + math.sin(spokeAngle) * (radius * 0.65);
      canvas.drawLine(
        Offset(innerX, innerY),
        Offset(outerX, outerY),
        spokePaint,
      );
    }

    // Center Hub Nut
    final hubPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawCircle(center, radius * 0.22, hubPaint);
    final hubNut = Paint()..color = const Color(0xFF38BDF8);
    canvas.drawCircle(center, radius * 0.10, hubNut);
  }

  @override
  bool shouldRepaint(covariant RealisticTruckPainter oldDelegate) {
    return oldDelegate.wheelAngle != wheelAngle;
  }
}

/// Realistic Asphalt Road with Moving Dashes
class RealisticRoadPainter extends CustomPainter {
  final double offset;

  RealisticRoadPainter({required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    // Road surface
    final asphaltPaint = Paint()..color = const Color(0xFFCBD5E1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height / 2 - 1.5, size.width, 3),
        const Radius.circular(1.5),
      ),
      asphaltPaint,
    );

    // Dashed center line
    final dashPaint = Paint()
      ..color = const Color(0xFF4B7B9F).withValues(alpha: 0.7)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final dashLength = 16.0;
    final gapLength = 12.0;
    final cycle = dashLength + gapLength;
    final startX = -(offset * cycle);

    for (double x = startX; x < size.width + cycle; x += cycle) {
      if (x + dashLength > 0 && x < size.width) {
        canvas.drawLine(
          Offset(math.max(0, x), size.height / 2),
          Offset(math.min(size.width, x + dashLength), size.height / 2),
          dashPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant RealisticRoadPainter oldDelegate) {
    return oldDelegate.offset != offset;
  }
}
