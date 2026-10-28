import 'package:flutter/material.dart';
import '../models/driver_model.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import 'driver_registration_screen.dart';
import 'pj_verification_screen.dart';
import 'driver_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController(text: '0714 882 109');
  final TextEditingController _otpController = TextEditingController();
  bool _otpSent = false;
  bool _isLoading = false;
  String? _errorMessage;

  void _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 9) {
      setState(() => _errorMessage = 'Tafadhali ingiza namba sahihi ya simu.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await ApiService.requestOtp(phone);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _otpSent = true;
      _otpController.text = res['otp']?.toString() ?? '1234';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message']?.toString() ?? 'OTP imetumwa kwa SMS'),
        backgroundColor: const Color(0xFF22C55E),
      ),
    );
  }

  void _verifyOtp() async {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      setState(() => _errorMessage = 'Tafadhali ingiza tarakimu 4 za OTP.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await ApiService.verifyOtp(phone, otp);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['status'] == 'success') {
      final existingDriver = await SessionManager.getDriver();
      if (!mounted) return;

      if (existingDriver != null && existingDriver.phone == phone) {
        final isVerified = await SessionManager.isPjVerified();
        if (!mounted) return;

        if (isVerified) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DriverDashboardScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => PjVerificationScreen(driver: existingDriver)),
          );
        }
      } else {
        // Go to registration
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => DriverRegistrationScreen(initialPhone: phone)),
        );
      }
    } else {
      setState(() => _errorMessage = res['message']?.toString() ?? 'Uthibitisho umeshindikana');
    }
  }

  void _quickDemoLogin() async {
    final demoDriver = DriverModel(
      id: 'DRV-TZ-1082',
      name: 'Juma Shabani Mussa',
      phone: '0714 882 109',
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
      MaterialPageRoute(builder: (_) => const DriverDashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x4D22C55E),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 38),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Ingia Kama Dereva',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Beba mizigo, pata pesa taslimu mkononi (93%)',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                ),
              ),
              const SizedBox(height: 36),

              // Phone Field
              const Text(
                'Namba ya Simu',
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  hintText: '0714 882 109',
                  hintStyle: const TextStyle(color: Color(0xFF64748B)),
                  prefixIcon: const Icon(Icons.phone_iphone_rounded, color: Color(0xFF22C55E)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF22C55E), width: 1.5),
                  ),
                ),
              ),

              if (_otpSent) ...[
                const SizedBox(height: 20),
                const Text(
                  'Nambari ya Siri (OTP)',
                  style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 8),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    hintText: '1 2 3 4',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), letterSpacing: 4),
                    prefixIcon: const Icon(Icons.lock_clock_outlined, color: Color(0xFF38BDF8)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                    ),
                  ),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : (_otpSent ? _verifyOtp : _sendOtp),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _otpSent ? 'THIBITISHA NA INGIA' : 'TUMA NAMBA YA SIRI (SMS)',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DriverRegistrationScreen(initialPhone: _phoneController.text.trim()),
                      ),
                    );
                  },
                  child: const Text(
                    'Huna akaunti? Jisajili Kama Dereva Mpya',
                    style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Demo Testing Shortcut
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Jaribio la Haraka (Testing Mode)',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ingia moja kwa moja na akaunti ya majaribio ya dereva wa Kirikuu (T 482 DWK) iliyothibitishwa.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _quickDemoLogin,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFF59E0B)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          'INGIA KAMA DEREVA WA MAJARIBIO',
                          style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 12),
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
    );
  }
}
