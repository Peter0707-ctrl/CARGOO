import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/driver_model.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import 'otp_screen.dart';
import 'driver_registration_screen.dart';
import 'main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController(text: '0714 882 109');
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final rawInput = _phoneController.text.trim();
    if (rawInput.isEmpty) {
      setState(() => _errorMessage = 'Tafadhali ingiza namba ya simu');
      return;
    }

    final cleanDigits = rawInput.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.length < 9) {
      setState(() => _errorMessage = 'Namba ya simu inapaswa kuwa na angalau tarakimu 9');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final last9 = cleanDigits.substring(cleanDigits.length - 9);
    final fullPhone = '+255$last9';

    await ApiService.requestOtp(fullPhone);

    if (!mounted) return;
    setState(() => _isLoading = false);

    // Open CARGOO Glassy Diamond-Orbit Animated OTP Screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtpScreen(phoneNumber: fullPhone),
      ),
    );
  }

  void _quickDemoLogin() async {
    final demoDriver = DriverModel(
      id: 'DRV-TZ-1082',
      name: 'Juma Shabani Mussa',
      phone: '+255714882109',
      nida: '19920814-14102-00001-24',
      licenseNumber: 'DL-TZ-772910',
      licenseClass: 'Class C (Kirikuu & Canter)',
      vehicleType: 'Kirikuu Pick-up',
      vehiclePlate: 'T 482 DWK',
      vehicleColor: 'Nyeupe (White)',
      rating: 4.95,
      isPjVerified: true,
      walletDebt: 0.0,
      isOnline: true,
    );

    await SessionManager.saveDriver(demoDriver);
    await SessionManager.setPjVerified(true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
    );
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
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4B7B9F).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'CARGOO',
                  style: TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    color: Color(0xFF4B7B9F),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ),
          leadingWidth: 100,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'DEREVA',
                    style: TextStyle(
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),

                // Main Heading
                const Text(
                  'Ingia Kama Dereva',
                  style: TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E2822),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Beba mizigo, pokea fedha taslimu mkononi (93%) na tukuze kipato chako kila siku.',
                  style: TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    fontSize: 14,
                    color: Color(0xFF6B7E74),
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 32),

                // Phone Input Card
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Country flag & code badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: const [
                            Text('🇹🇿', style: TextStyle(fontSize: 18)),
                            SizedBox(width: 6),
                            Text(
                              '+255',
                              style: TextStyle(
                                fontFamily: 'Segoe UI Variable',
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Color(0xFF1E2822),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Number text field
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(
                            fontFamily: 'Segoe UI Variable',
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E2822),
                            letterSpacing: 0.5,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '714 882 109',
                            hintStyle: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Primary Button: CARGOO Blue
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4B7B9F),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                'ENDELEA NA UTHIBITISHO WA OTP',
                                style: TextStyle(
                                  fontFamily: 'Segoe UI Variable',
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // Register Link
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DriverRegistrationScreen(initialPhone: _phoneController.text.trim()),
                        ),
                      );
                    },
                    child: const Text(
                      'Huna akaunti ya Dereva? Jisajili Hapa',
                      style: TextStyle(
                        fontFamily: 'Segoe UI Variable',
                        color: Color(0xFF4B7B9F),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // Testing Mode Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Jaribio la Haraka (Testing Mode)',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              color: Color(0xFF1E2822),
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ingia moja kwa moja kwenye Dashibodi na Ramani ukitumia akaunti ya dereva wa Kirikuu (T 482 DWK) iliyothibitishwa na AI PJ.',
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          color: Color(0xFF6B7E74),
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: _quickDemoLogin,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'INGIA KAMA DEREVA WA MAJARIBIO',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              color: Color(0xFFD97706),
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
