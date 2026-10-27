import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
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
      setState(() {
        _errorMessage = 'Please enter your phone number';
      });
      return;
    }

    final cleanDigits = rawInput.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.length < 9) {
      setState(() {
        _errorMessage = 'Phone number must have at least 9 digits (e.g. 0673190931)';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Strictly normalize any format (0673..., 255673..., +255673..., 673...) into +255XXXXXXXXX
    final last9 = cleanDigits.substring(cleanDigits.length - 9);
    final fullPhone = '+255$last9';

    final result = await ApiService.requestOtp(fullPhone);

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpScreen(
            phoneNumber: fullPhone,
          ),
        ),
      );
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Network error. Please try again.';
      });
    }
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
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              const Text(
                'Enter phone number',
                style: TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E2822),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'We will send a 4-digit verification code via SMS to confirm your account.',
                style: TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF6B7E74),
                ),
              ),

              const SizedBox(height: 32),

              // Phone Number Input Container
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _errorMessage != null
                        ? Colors.red.shade300
                        : const Color(0xFFCAD4CC),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    // Clean Code Container without colored emoji
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F5F1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.phone_android_rounded, size: 16, color: Color(0xFF4B7B9F)),
                          SizedBox(width: 6),
                          Text(
                            '+255',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF1E2822),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Number Input Field
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        autofocus: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(13),
                        ],
                        style: const TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E2822),
                          letterSpacing: 1.2,
                        ),
                        decoration: const InputDecoration(
                          hintText: '0673 190 931',
                          hintStyle: TextStyle(
                            color: Color(0xFFA0AEC0),
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (_) => _handleContinue(),
                      ),
                    ),

                    if (_phoneController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _phoneController.clear();
                            _errorMessage = null;
                          });
                        },
                      ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              // Feature badges
              const Row(
                children: [
                  Icon(Icons.verified_user_outlined, size: 16, color: Color(0xFF4B7B9F)),
                  SizedBox(width: 6),
                  Text(
                    'Verified Identity & Secure Cargo Transit',
                    style: TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7E74),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Continue Button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4B7B9F),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF4B7B9F).withValues(alpha: 0.6),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Continue',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
              ),

              const SizedBox(height: 16),

              const Text(
                'By continuing, you agree to the Terms of Service and Privacy Policy of CARGOO.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 11,
                  color: Color(0xFF8C9B92),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    ),
  );
}
}
