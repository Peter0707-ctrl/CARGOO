import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import 'profile_screen.dart';
import 'main_navigation_screen.dart';

/// Shows the CARGOO Glassy Diamond-Orbit OTP Verification Modal
/// (Used when updating user profile details or verifying sensitive financial actions)
Future<bool> showAnimatedOtpVerificationModal({
  required BuildContext context,
  required String destination,
  String verifiedSubtitle = 'Your security verification code has been confirmed.',
  Future<bool> Function(String code)? customValidator,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'OTP Verification',
    barrierColor: const Color(0xFF1E2822).withValues(alpha: 0.62),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (ctx, anim1, anim2) {
      return SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Material(
              color: Colors.transparent,
              child: OtpVerificationCardV15(
                destination: destination,
                verifiedSubtitle: verifiedSubtitle,
                showCloseButton: true,
                onClose: () => Navigator.of(ctx).pop(false),
                onVerifiedContinue: () => Navigator.of(ctx).pop(true),
                customValidator: customValidator,
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim1, anim2, child) {
      final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
  return result == true;
}

class OtpScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  Map<String, dynamic>? _verifiedUser;

  Future<bool> _verifyWithBackend(String code) async {
    final result = await ApiService.verifyOtp(widget.phoneNumber, code);
    if (result['success'] == true) {
      final user = result['data']?['user'] as Map<String, dynamic>?;
      _verifiedUser = user ?? {'phone': widget.phoneNumber, 'is_profile_complete': false};
      await SessionManager.saveUser(_verifiedUser!);
      return true;
    }
    return false;
  }

  void _handleContinueAfterVerified() {
    if (!mounted) return;
    final user = _verifiedUser ?? {'phone': widget.phoneNumber, 'is_profile_complete': false};
    final isComplete = user['is_profile_complete'] == true;

    if (isComplete) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => MainNavigationScreen(user: user)),
        (route) => false,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ProfileScreen(phoneNumber: widget.phoneNumber)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFFF2F5F1),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F5F1),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFCAD4CC)),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E2822), size: 18),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              child: OtpVerificationCardV15(
                destination: widget.phoneNumber,
                verifiedSubtitle: 'Your security verification code has been confirmed.',
                customValidator: _verifyWithBackend,
                onVerifiedContinue: _handleContinueAfterVerified,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _OrbitOtpPhase {
  typing,
  orbitingAndMerging,
  centerSpinning,
  verifiedSuccess,
  wrongError,
}

class OtpVerificationCardV15 extends StatefulWidget {
  final String destination;
  final String verifiedSubtitle;
  final bool showCloseButton;
  final VoidCallback? onClose;
  final VoidCallback onVerifiedContinue;
  final Future<bool> Function(String code)? customValidator;

  const OtpVerificationCardV15({
    super.key,
    required this.destination,
    this.verifiedSubtitle = 'Your security verification code has been confirmed.',
    this.showCloseButton = false,
    this.onClose,
    required this.onVerifiedContinue,
    this.customValidator,
  });

  @override
  State<OtpVerificationCardV15> createState() => _OtpVerificationCardV15State();
}

class _OtpVerificationCardV15State extends State<OtpVerificationCardV15>
    with TickerProviderStateMixin {
  // CARGOO Brand Palette
  static const Color _cargooBlue = Color(0xFF4B7B9F);
  static const Color _cargooDarkNavy = Color(0xFF2C4A63);
  static const Color _cargooSoftBlue = Color(0xFFE5EEF5);
  static const Color _cargooDarkText = Color(0xFF1E2822);
  static const Color _cargooMutedText = Color(0xFF6B7E74);
  static const Color _cargooGreen = Color(0xFF16A34A);
  static const Color _cargooRed = Color(0xFFE11D48);

  final List<String> _digits = ['', '', '', ''];
  final TextEditingController _hiddenController = TextEditingController();
  final FocusNode _hiddenFocusNode = FocusNode();

  _OrbitOtpPhase _phase = _OrbitOtpPhase.typing;
  int _secondsRemaining = 45;
  Timer? _resendTimer;
  Timer? _cursorTimer;
  bool _showCursor = true;
  bool _hasNavigated = false;

  late AnimationController _orbitController;
  late AnimationController _shakeController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _startResendTimer();
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 520), (_) {
      if (mounted) {
        setState(() => _showCursor = !_showCursor);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _hiddenFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _cursorTimer?.cancel();
    _orbitController.dispose();
    _shakeController.dispose();
    _pulseController.dispose();
    _hiddenController.dispose();
    _hiddenFocusNode.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _secondsRemaining = 45);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  int get _enteredCount => _digits.where((d) => d.isNotEmpty).length;

  int get _activeBoxIndex {
    for (int i = 0; i < 4; i++) {
      if (_digits[i].isEmpty) return i;
    }
    return 3;
  }

  void _onHiddenTextChanged(String value) {
    if (_phase != _OrbitOtpPhase.typing && _phase != _OrbitOtpPhase.wrongError) {
      return;
    }

    final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    final clamped = clean.length > 4 ? clean.substring(0, 4) : clean;

    if (clamped != value) {
      _hiddenController.value = TextEditingValue(
        text: clamped,
        selection: TextSelection.collapsed(offset: clamped.length),
      );
    }

    setState(() {
      _phase = _OrbitOtpPhase.typing;
      for (int i = 0; i < 4; i++) {
        _digits[i] = i < clamped.length ? clamped[i] : '';
      }
    });

    HapticFeedback.selectionClick();

    if (clamped.length == 4) {
      Future.delayed(const Duration(milliseconds: 140), () {
        if (mounted && _enteredCount == 4 && _phase == _OrbitOtpPhase.typing) {
          _startOrbitVerification();
        }
      });
    }
  }

  Future<void> _startOrbitVerification() async {
    final code = _digits.join();
    if (code.length < 4 || _phase != _OrbitOtpPhase.typing) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _phase = _OrbitOtpPhase.orbitingAndMerging;
    });

    // Start the Diamond Formation -> 360° Orbit -> Center Merge animation
    final orbitFuture = _orbitController.forward(from: 0.0);
    final validateFuture = _validateCode(code);

    await orbitFuture;
    if (!mounted) return;

    // Center spinning phase while awaiting backend response
    setState(() {
      _phase = _OrbitOtpPhase.centerSpinning;
    });

    final isSuccess = await validateFuture;
    await Future.delayed(const Duration(milliseconds: 360));
    if (!mounted) return;

    if (isSuccess) {
      HapticFeedback.mediumImpact();
      setState(() {
        _phase = _OrbitOtpPhase.verifiedSuccess;
      });
      _pulseController.forward(from: 0.0);

      // Strictly auto-enter next screen on real verification success
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted && !_hasNavigated) {
          _hasNavigated = true;
          widget.onVerifiedContinue();
        }
      });
    } else {
      // Wrong OTP code
      HapticFeedback.heavyImpact();
      setState(() {
        _phase = _OrbitOtpPhase.wrongError;
      });
      _shakeController.forward(from: 0.0);

      await Future.delayed(const Duration(milliseconds: 850));
      if (!mounted) return;

      await _orbitController.reverse(from: 0.85);
      if (!mounted) return;

      setState(() {
        for (int i = 0; i < 4; i++) {
          _digits[i] = '';
        }
        _hiddenController.clear();
      });
      _hiddenFocusNode.requestFocus();
    }
  }

  Future<bool> _validateCode(String code) async {
    if (widget.customValidator != null) {
      return await widget.customValidator!(code);
    }
    return false;
  }

  Future<void> _handleResendCode() async {
    if (_secondsRemaining > 0 ||
        _phase == _OrbitOtpPhase.orbitingAndMerging ||
        _phase == _OrbitOtpPhase.centerSpinning) {
      return;
    }

    _orbitController.reset();
    setState(() {
      _phase = _OrbitOtpPhase.typing;
      for (int i = 0; i < 4; i++) {
        _digits[i] = '';
      }
      _hiddenController.clear();
    });
    _startResendTimer();
    _hiddenFocusNode.requestFocus();

    // Trigger real carrier SMS dispatch via Africa's Talking API
    await ApiService.requestOtp(widget.destination);
  }

  @override
  Widget build(BuildContext context) {
    final isVerified = _phase == _OrbitOtpPhase.verifiedSuccess;
    final isWrong = _phase == _OrbitOtpPhase.wrongError;
    final isVerifying = _phase == _OrbitOtpPhase.orbitingAndMerging ||
        _phase == _OrbitOtpPhase.centerSpinning;

    Color cardBorderColor = _cargooBlue.withValues(alpha: 0.35);
    Color glowColor = _cargooBlue.withValues(alpha: 0.12);
    if (isVerified) {
      cardBorderColor = _cargooGreen.withValues(alpha: 0.65);
      glowColor = _cargooGreen.withValues(alpha: 0.18);
    } else if (isWrong) {
      cardBorderColor = _cargooRed.withValues(alpha: 0.65);
      glowColor = _cargooRed.withValues(alpha: 0.16);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hidden native keyboard input receiver
        SizedBox(
          width: 1,
          height: 1,
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: _hiddenController,
              focusNode: _hiddenFocusNode,
              keyboardType: TextInputType.number,
              maxLength: 4,
              autofocus: true,
              enableSuggestions: false,
              autocorrect: false,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: _onHiddenTextChanged,
            ),
          ),
        ),

        // Main Glassy CARGOO Card
        AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 390),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: cardBorderColor, width: 1.6),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                isVerified
                    ? const Color(0xFFF0FDF4)
                    : (isWrong ? const Color(0xFFFFF1F2) : const Color(0xFFF4F8FB)),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor,
                blurRadius: 32,
                spreadRadius: 2,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: _cargooDarkText.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showCloseButton)
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: _cargooSoftBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 18, color: _cargooDarkNavy),
                    ),
                  ),
                ),

              // 1. Top 45° Rotated Diamond Badge (Key -> Shield Check -> Alert)
              _buildDiamondTopBadge(isVerified: isVerified, isWrong: isWrong),
              const SizedBox(height: 22),

              // 2. Animated Header Title
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: isVerified
                    ? RichText(
                        key: const ValueKey('hdr_verified'),
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: TextStyle(
                            fontFamily: 'Segoe UI Variable',
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                          children: [
                            TextSpan(
                              text: 'Verified ',
                              style: TextStyle(color: _cargooDarkText),
                            ),
                            TextSpan(
                              text: 'Successfully',
                              style: TextStyle(color: _cargooGreen),
                            ),
                          ],
                        ),
                      )
                    : (isWrong
                        ? RichText(
                            key: const ValueKey('hdr_wrong'),
                            textAlign: TextAlign.center,
                            text: const TextSpan(
                              style: TextStyle(
                                fontFamily: 'Segoe UI Variable',
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Wrong ',
                                  style: TextStyle(color: _cargooRed),
                                ),
                                TextSpan(
                                  text: 'OTP Code',
                                  style: TextStyle(color: _cargooDarkText),
                                ),
                              ],
                            ),
                          )
                        : RichText(
                            key: const ValueKey('hdr_verify'),
                            textAlign: TextAlign.center,
                            text: const TextSpan(
                              style: TextStyle(
                                fontFamily: 'Segoe UI Variable',
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Verify ',
                                  style: TextStyle(color: _cargooDarkText),
                                ),
                                TextSpan(
                                  text: 'OTP',
                                  style: TextStyle(color: _cargooBlue),
                                ),
                              ],
                            ),
                          )),
              ),
              const SizedBox(height: 8),

              // 3. Subtitle
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: Text(
                  isVerified
                      ? widget.verifiedSubtitle
                      : (isWrong
                          ? 'Wrong verification code entered. Please try again.'
                          : 'Enter the 4-digit security code sent to ${widget.destination}'),
                  key: ValueKey(isVerified ? 'sub_ok' : (isWrong ? 'sub_err' : 'sub_idle')),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.8,
                    fontWeight: isWrong ? FontWeight.w700 : FontWeight.w500,
                    color: isWrong ? _cargooRed : _cargooMutedText,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 4. Center Stage: 4 Boxes -> Diamond Cross -> 360° Orbit -> Center Merge Square
              GestureDetector(
                onTap: () {
                  if (!isVerifying && !isVerified) {
                    _hiddenFocusNode.requestFocus();
                    SystemChannels.textInput.invokeMethod('TextInput.show');
                  }
                },
                child: SizedBox(
                  height: 176,
                  width: double.infinity,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _orbitController,
                      _shakeController,
                      _pulseController,
                    ]),
                    builder: (context, _) {
                      final shakeDx = math.sin(_shakeController.value * math.pi * 4) *
                          10.0 *
                          (1.0 - _shakeController.value);
                      return Transform.translate(
                        offset: Offset(shakeDx, 0),
                        child: _buildOrbitStage(),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // 5. Resend Timer Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Didn't receive the code? ",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: _cargooMutedText,
                    ),
                  ),
                  if (_secondsRemaining > 0)
                    Text(
                      'Resend in 00:${_secondsRemaining.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: isVerified ? _cargooGreen : _cargooBlue,
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: _handleResendCode,
                      child: const Text(
                        'Resend Now',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: _cargooBlue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 22),

              // 6. Bottom Status / Action Button
              _buildBottomActionButton(
                isVerified: isVerified,
                isWrong: isWrong,
                isVerifying: isVerifying,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Top 45-degree rotated rounded square Diamond Badge
  Widget _buildDiamondTopBadge({
    required bool isVerified,
    required bool isWrong,
  }) {
    Color bg = _cargooSoftBlue;
    Color border = _cargooBlue.withValues(alpha: 0.45);
    Color iconColor = _cargooBlue;
    IconData iconData = Icons.vpn_key_rounded;

    if (isVerified) {
      bg = const Color(0xFFDCFCE7);
      border = _cargooGreen.withValues(alpha: 0.55);
      iconColor = _cargooGreen;
      iconData = Icons.verified_user_rounded;
    } else if (isWrong) {
      bg = const Color(0xFFFFE4E6);
      border = _cargooRed.withValues(alpha: 0.55);
      iconColor = _cargooRed;
      iconData = Icons.gpp_bad_rounded;
    }

    return SizedBox(
      width: 68,
      height: 68,
      child: Center(
        child: Transform.rotate(
          angle: math.pi / 4,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Transform.rotate(
              angle: -math.pi / 4,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  iconData,
                  key: ValueKey(iconData.codePoint),
                  color: iconColor,
                  size: 25,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the 4-box horizontal row that morphs into a Diamond Cross,
  /// orbits 360 degrees, and merges into a single center box
  Widget _buildOrbitStage() {
    final t = _orbitController.value;

    if (_phase == _OrbitOtpPhase.centerSpinning ||
        _phase == _OrbitOtpPhase.verifiedSuccess ||
        (_phase == _OrbitOtpPhase.wrongError && t > 0.8)) {
      return Center(child: _buildMergedCenterBox());
    }

    const List<Offset> rowPositions = [
      Offset(-99, 0),
      Offset(-33, 0),
      Offset(33, 0),
      Offset(99, 0),
    ];

    const List<double> diamondBaseAngles = [
      math.pi,
      -math.pi / 2,
      math.pi / 2,
      0.0,
    ];
    const double diamondRadius = 54.0;

    return Stack(
      alignment: Alignment.center,
      children: List.generate(4, (i) {
        Offset pos;
        double boxRotation = 0.0;
        double scale = 1.0;
        double opacity = 1.0;

        if (t <= 0.25) {
          final p = Curves.easeInOutCubic.transform(t / 0.25);
          final targetX = math.cos(diamondBaseAngles[i]) * diamondRadius;
          final targetY = math.sin(diamondBaseAngles[i]) * diamondRadius;
          pos = Offset.lerp(rowPositions[i], Offset(targetX, targetY), p)!;
        } else if (t <= 0.78) {
          final p = Curves.easeInOutSine.transform((t - 0.25) / 0.53);
          final currentAngle = diamondBaseAngles[i] + (p * math.pi * 2.0);
          pos = Offset(
            math.cos(currentAngle) * diamondRadius,
            math.sin(currentAngle) * diamondRadius,
          );
          boxRotation = p * math.pi * 2.0;
        } else {
          final p = Curves.easeInBack.transform(((t - 0.78) / 0.22).clamp(0.0, 1.0));
          final radius = diamondRadius * (1.0 - p);
          final currentAngle = diamondBaseAngles[i] + math.pi * 2.0;
          pos = Offset(
            math.cos(currentAngle) * radius,
            math.sin(currentAngle) * radius,
          );
          scale = 1.0 - (p * 0.25);
          opacity = (1.0 - (p * 0.65)).clamp(0.0, 1.0);
        }

        return Transform.translate(
          offset: pos,
          child: Transform.rotate(
            angle: boxRotation,
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: _buildSingleDigitBox(i),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSingleDigitBox(int index) {
    final digit = _digits[index];
    final hasDigit = digit.isNotEmpty;
    final isWrong = _phase == _OrbitOtpPhase.wrongError;
    final isFocused = _hiddenFocusNode.hasFocus &&
        (_phase == _OrbitOtpPhase.typing || _phase == _OrbitOtpPhase.wrongError) &&
        _orbitController.value == 0.0 &&
        _activeBoxIndex == index &&
        _enteredCount < 4;

    Color borderColor = const Color(0xFFCAD4CC);
    Color bgColor = Colors.white;
    Color textColor = _cargooDarkText;
    double borderWidth = 1.5;

    if (isWrong) {
      borderColor = _cargooRed;
      bgColor = const Color(0xFFFFF1F2);
      textColor = _cargooRed;
      borderWidth = 2.0;
    } else if (isFocused || _orbitController.value > 0.0) {
      borderColor = _cargooBlue;
      bgColor = _cargooSoftBlue.withValues(alpha: 0.55);
      borderWidth = 2.0;
    } else if (hasDigit) {
      borderColor = _cargooBlue.withValues(alpha: 0.65);
      bgColor = Colors.white;
      borderWidth = 1.8;
    }

    return Container(
      width: 54,
      height: 56,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          if (isFocused || _orbitController.value > 0.0)
            BoxShadow(
              color: _cargooBlue.withValues(alpha: 0.20),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Center(
        child: hasDigit
            ? Text(
                digit,
                style: TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              )
            : (isFocused && _showCursor
                ? Container(
                    width: 2.2,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _cargooBlue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )
                : const SizedBox.shrink()),
      ),
    );
  }

  /// The single central square shown after the 4 boxes converge in the middle
  Widget _buildMergedCenterBox() {
    final isVerified = _phase == _OrbitOtpPhase.verifiedSuccess;
    final isWrong = _phase == _OrbitOtpPhase.wrongError;

    Color borderColor = _cargooBlue;
    Color bgColor = _cargooSoftBlue;
    if (isVerified) {
      borderColor = _cargooGreen;
      bgColor = const Color(0xFFDCFCE7);
    } else if (isWrong) {
      borderColor = _cargooRed;
      bgColor = const Color(0xFFFFE4E6);
    }

    final pulseScale = 1.0 + math.sin(_pulseController.value * math.pi) * 0.12;

    return Transform.scale(
      scale: pulseScale,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2.2),
          boxShadow: [
            BoxShadow(
              color: borderColor.withValues(alpha: 0.28),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: isVerified
              ? const Icon(
                  Icons.check_rounded,
                  color: _cargooGreen,
                  size: 34,
                )
              : (isWrong
                  ? const Icon(
                      Icons.close_rounded,
                      color: _cargooRed,
                      size: 34,
                    )
                  : const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: _cargooBlue,
                      ),
                    )),
        ),
      ),
    );
  }

  Widget _buildBottomActionButton({
    required bool isVerified,
    required bool isWrong,
    required bool isVerifying,
  }) {
    final isReady = _enteredCount == 4;

    Color btnBg = _cargooBlue;
    if (isVerified) {
      btnBg = _cargooGreen;
    } else if (isWrong) {
      btnBg = _cargooRed;
    } else if (!isReady && !isVerifying) {
      btnBg = _cargooBlue.withValues(alpha: 0.55);
    }

    return GestureDetector(
      onTap: () {
        if (isVerified) {
          if (!_hasNavigated) {
            _hasNavigated = true;
            widget.onVerifiedContinue();
          }
        } else if (isReady && !isVerifying) {
          _startOrbitVerification();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: btnBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: btnBg.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: isVerified
                ? const Row(
                    key: ValueKey('btn_verified'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 19),
                      SizedBox(width: 8),
                      Text(
                        'Verified & Secured',
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : (isWrong
                    ? const Row(
                        key: ValueKey('btn_wrong'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, color: Colors.white, size: 19),
                          SizedBox(width: 8),
                          Text(
                            'Wrong Code — Try Again',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : (isVerifying
                        ? const Row(
                            key: ValueKey('btn_verifying'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Verifying Code ...',
                                style: TextStyle(
                                  fontFamily: 'Segoe UI Variable',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : const Row(
                            key: ValueKey('btn_proceed'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Verify & Proceed',
                                style: TextStyle(
                                  fontFamily: 'Segoe UI Variable',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                            ],
                          ))),
          ),
        ),
      ),
    );
  }
}
