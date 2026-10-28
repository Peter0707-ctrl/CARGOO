import 'dart:async';
import 'package:flutter/material.dart';
import '../services/session_manager.dart';
import 'login_screen.dart';
import 'pj_verification_screen.dart';
import 'driver_dashboard_screen.dart';
import 'active_trip_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkNavigation();
  }

  Future<void> _checkNavigation() async {
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    final driver = await SessionManager.getDriver();
    if (!mounted) return;

    if (driver == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    final isPjVerified = await SessionManager.isPjVerified();
    if (!mounted) return;

    if (!isPjVerified) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PjVerificationScreen(driver: driver)),
      );
      return;
    }

    final activeTrip = await SessionManager.getActiveTrip();
    if (!mounted) return;

    if (activeTrip != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ActiveTripScreen(order: activeTrip)),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DriverDashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x5922C55E),
                    blurRadius: 28,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_shipping_rounded,
                size: 52,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'CARGOO DEREVA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mfumo Rasmi wa Madereva wa Mizigo Tanzania',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
