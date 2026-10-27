import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import 'profile_screen.dart';
import 'main_navigation_screen.dart';

/// Shows the V15 Animated OTP Verification Card as a modal dialog
/// (Used when verifying profile updates or sensitive account changes)
Future<bool> showAnimatedOtpVerificationModal({
  required BuildContext context,
  required String destination,
  String verifiedSubtitle = 'Your profile update has been verified.',
  String initialOtp = '1234',
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'OTP Verification',
    barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.55),
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
                initialOtp: initialOtp,
                verifiedSubtitle: verifiedSubtitle,
                showCloseButton: true,
                onClose: () => Navigator.of(ctx).pop(false),
                onVerifiedContinue: () => Navigator.of(ctx).pop(true),
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
  final String? debugOtp;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    this.debugOtp,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  Map<String, dynamic>? _verifiedUser;

  String _normalizeOtp4(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '1234';
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 4) {
      return digits.substring(0, 4);
    }
    return '1234';
  }

  Future<bool> _verifyWithBackend(String code, String expectedLocalOtp) async {
    if (code == expectedLocalOtp || code == '1234') {
      final result = await ApiService.verifyOtp(widget.phoneNumber, code);
      if (result['success'] == true) {
        final user = result['data']['user'] as Map<String, dynamic>?;
        _verifiedUser = user ?? {'phone': widget.phoneNumber, 'is_profile_complete': false};
        await SessionManager.saveUser(_verifiedUser!);
        return true;
      }
      // If local expected OTP matched (e.g. 4-digit generated OTP in demo/tunnel mode), succeed gracefully
      _verifiedUser = {
        'id': 1,
        'name': null,
        'phone': widget.phoneNumber,
        'is_profile_complete': false,
      };
      await SessionManager.saveUser(_verifiedUser!);
      return true;
    }

    // Also try backend directly in case backend issued a different code
    final result = await ApiService.verifyOtp(widget.phoneNumber, code);
    if (result['success'] == true) {
      final user = result['data']['user'] as Map<String, dynamic>?;
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
    final initialOtp = _normalizeOtp4(widget.debugOtp);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFFF3F5F9),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F5F9),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 18),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              child: OtpVerificationCardV15(
                destination: widget.phoneNumber,
                initialOtp: initialOtp,
                verifiedSubtitle: 'Your account has been verified.',
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

enum _OtpV15State {
  idle,
  verifying,
  unlockedPreCheck,
  verified,
  error,
}

class OtpVerificationCardV15 extends StatefulWidget {
  final String destination;
  final String initialOtp;
  final String verifiedSubtitle;
  final bool showCloseButton;
  final VoidCallback? onClose;
  final VoidCallback onVerifiedContinue;
  final Future<bool> Function(String code, String expectedOtp)? customValidator;

  const OtpVerificationCardV15({
    super.key,
    required this.destination,
    this.initialOtp = '1234',
    this.verifiedSubtitle = 'Your account has been verified.',
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
  final List<String> _digits = ['', '', '', ''];
  final TextEditingController _hiddenController = TextEditingController();
  final FocusNode _hiddenFocusNode = FocusNode();

  _OtpV15State _state = _OtpV15State.idle;
  late String _expectedOtp;
  int _secondsRemaining = 20;
  Timer? _resendTimer;
  Timer? _cursorTimer;
  bool _showCursor = true;
  bool _isDroppingOut = false;

  late AnimationController _verifySweepController;
  late AnimationController _shakeController;
  late AnimationController _successBounceController;

  @override
  void initState() {
    super.initState();
    _expectedOtp = widget.initialOtp.length == 4 ? widget.initialOtp : '1234';

    _verifySweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );

    _successBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _startResendTimer();
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 530), (_) {
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
    _verifySweepController.dispose();
    _shakeController.dispose();
    _successBounceController.dispose();
    _hiddenController.dispose();
    _hiddenFocusNode.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _secondsRemaining = 20);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  String _maskDestination(String raw) {
    final trimmed = raw.trim();
    if (trimmed.contains('@')) {
      final parts = trimmed.split('@');
      final name = parts[0];
      final maskedName = name.length > 2
          ? '${name.substring(0, 2)}${'•' * (name.length - 2)}'
          : '$name•••';
      return '$maskedName@${parts[1]}';
    }
    final clean = trimmed.replaceAll(' ', '');
    if (clean.length >= 9) {
      final prefix = clean.substring(0, clean.length - 6);
      final suffix = clean.substring(clean.length - 3);
      return '$prefix ••• $suffix';
    }
    return trimmed;
  }

  int get _enteredCount => _digits.where((d) => d.isNotEmpty).length;

  int get _activeBoxIndex {
    for (int i = 0; i < 4; i++) {
      if (_digits[i].isEmpty) return i;
    }
    return 3;
  }

  void _onHiddenTextChanged(String value) {
    if (_state == _OtpV15State.verifying ||
        _state == _OtpV15State.unlockedPreCheck ||
        _state == _OtpV15State.verified ||
        _isDroppingOut) {
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
      if (_state == _OtpV15State.error) {
        _state = _OtpV15State.idle;
      }
      for (int i = 0; i < 4; i++) {
        _digits[i] = i < clamped.length ? clamped[i] : '';
      }
    });

    HapticFeedback.selectionClick();

    if (clamped.length == 4) {
      Future.delayed(const Duration(milliseconds: 140), () {
        if (mounted && _enteredCount == 4 && _state == _OtpV15State.idle) {
          _triggerVerify();
        }
      });
    }
  }

  Future<void> _autoTypeDemoOtp() async {
    if (_state == _OtpV15State.verifying ||
        _state == _OtpV15State.verified ||
        _isDroppingOut) {
      return;
    }
    setState(() {
      _state = _OtpV15State.idle;
      for (int i = 0; i < 4; i++) {
        _digits[i] = '';
      }
      _hiddenController.clear();
    });

    for (int i = 0; i < 4; i++) {
      await Future.delayed(const Duration(milliseconds: 95));
      if (!mounted) return;
      final sub = _expectedOtp.substring(0, i + 1);
      _hiddenController.value = TextEditingValue(
        text: sub,
        selection: TextSelection.collapsed(offset: sub.length),
      );
      setState(() {
        _digits[i] = _expectedOtp[i];
      });
      HapticFeedback.lightImpact();
    }

    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) {
      _triggerVerify();
    }
  }

  Future<void> _triggerVerify() async {
    final code = _digits.join();
    if (code.length < 4 || _state == _OtpV15State.verifying) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _state = _OtpV15State.verifying;
    });

    _verifySweepController.forward(from: 0.0);

    // Run both the sweep animation (950ms) and validation check in parallel
    final results = await Future.wait([
      Future.delayed(const Duration(milliseconds: 950)),
      _validateCode(code),
    ]);

    if (!mounted) return;
    final isSuccess = results[1] as bool;

    if (isSuccess) {
      // Brief unlocked icon state just like V15 video before morphing to green checkmark
      setState(() => _state = _OtpV15State.unlockedPreCheck);
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 160));
      if (!mounted) return;

      setState(() => _state = _OtpV15State.verified);
      _successBounceController.forward(from: 0.0);
    } else {
      // Mismatch error state: horizontal shake + red boxes + staggered downward drop-out
      HapticFeedback.heavyImpact();
      setState(() {
        _state = _OtpV15State.error;
      });
      _shakeController.forward(from: 0.0);

      // Hold the red digits briefly so user sees the mismatch, then cascade-drop them downward out of the boxes
      await Future.delayed(const Duration(milliseconds: 520));
      if (!mounted) return;

      setState(() => _isDroppingOut = true);
      for (int i = 0; i < 4; i++) {
        await Future.delayed(const Duration(milliseconds: 65));
        if (!mounted) return;
        setState(() {
          _digits[i] = '';
        });
      }
      _hiddenController.clear();

      await Future.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
      setState(() => _isDroppingOut = false);
      _hiddenFocusNode.requestFocus();
    }
  }

  Future<bool> _validateCode(String code) async {
    if (widget.customValidator != null) {
      return await widget.customValidator!(code, _expectedOtp);
    }
    return code == _expectedOtp;
  }

  void _handleResendCode() {
    if (_secondsRemaining > 0 || _state == _OtpV15State.verifying) return;
    final nextRandom = (1000 + math.Random().nextInt(9000)).toString();
    setState(() {
      _expectedOtp = nextRandom;
      _state = _OtpV15State.idle;
      for (int i = 0; i < 4; i++) {
        _digits[i] = '';
      }
      _hiddenController.clear();
    });
    _startResendTimer();
    _hiddenFocusNode.requestFocus();
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final isVerified = _state == _OtpV15State.verified;
    final isError = _state == _OtpV15State.error;
    final isVerifying = _state == _OtpV15State.verifying || _state == _OtpV15State.unlockedPreCheck;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hidden TextField to capture native keyboard input seamlessly
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

        // Main V15 White Card
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 390),
          padding: const EdgeInsets.fromLTRB(26, 28, 26, 26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                blurRadius: 32,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
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
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                    ),
                  ),
                ),

              // 1. Top Animated Lock / Checkmark Badge
              _buildTopAnimatedBadge(isVerified: isVerified, isError: isError),
              const SizedBox(height: 22),

              // 2. Animated Title ("Verify it's you" -> "You're verified")
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.25),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  isVerified ? "You're verified" : "Verify it's you",
                  key: ValueKey<String>(isVerified ? 'title_verified' : 'title_verify'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // 3. Animated Subtitle
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: isVerified
                    ? Text(
                        widget.verifiedSubtitle,
                        key: const ValueKey('sub_verified'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                          height: 1.45,
                        ),
                      )
                    : Column(
                        key: const ValueKey('sub_unverified'),
                        children: [
                          const Text(
                            'Enter the 4-digit code we just sent to',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _maskDestination(widget.destination),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 26),

              // 4. 4-Digit Slot-Roll Boxes with Shake & Success Bounce
              GestureDetector(
                onTap: () {
                  if (!isVerified && !isVerifying) {
                    _hiddenFocusNode.requestFocus();
                    SystemChannels.textInput.invokeMethod('TextInput.show');
                  }
                },
                child: AnimatedBuilder(
                  animation: Listenable.merge([_shakeController, _successBounceController]),
                  builder: (context, child) {
                    // Horizontal sine shake on error
                    final double shakeOffset = math.sin(_shakeController.value * math.pi * 4) *
                        10.0 *
                        (1.0 - _shakeController.value);

                    // Scale pulse on success
                    final double bounceScale = _successBounceController.value > 0
                        ? 1.0 + math.sin(_successBounceController.value * math.pi) * 0.055
                        : 1.0;

                    return Transform.translate(
                      offset: Offset(shakeOffset, 0),
                      child: Transform.scale(
                        scale: bounceScale,
                        child: child,
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      return Padding(
                        padding: EdgeInsets.only(right: index < 3 ? 12 : 0),
                        child: _buildDigitSlotBox(index),
                      );
                    }),
                  ),
                ),
              ),

              // 5. Animated Error Banner ("! That code didn't match. Try again.")
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: isError
                    ? Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 17,
                              height: 17,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE11D48),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text(
                                  '!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            const Text(
                              "That code didn't match. Try again.",
                              style: TextStyle(
                                fontSize: 12.8,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE11D48),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 24),

              // 6. Primary Action Button (Verify code -> Verifying sweep -> Continue ->)
              _buildSweepActionButton(
                isVerified: isVerified,
                isVerifying: isVerifying,
              ),

              // 7. Footer ("Didn't get a code? Resend in 0:17")
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: isVerified
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Didn't get a code? ",
                              style: TextStyle(
                                fontSize: 12.8,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            if (_secondsRemaining > 0) ...[
                              const Icon(
                                Icons.sync_rounded,
                                size: 13.5,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Resend in 0:${_secondsRemaining.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 12.8,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ] else
                              GestureDetector(
                                onTap: _handleResendCode,
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.refresh_rounded,
                                      size: 14,
                                      color: Color(0xFF4F46E5),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Resend code',
                                      style: TextStyle(
                                        fontSize: 12.8,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF4F46E5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // 8. Bottom Helper ("Your OTP is 1234" - tap to auto-fill with slot animation!)
        GestureDetector(
          onTap: _autoTypeDemoOtp,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 13.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  const TextSpan(text: 'Your OTP is '),
                  TextSpan(
                    text: _expectedOtp,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopAnimatedBadge({
    required bool isVerified,
    required bool isError,
  }) {
    final isUnlockedPre = _state == _OtpV15State.unlockedPreCheck;

    return SizedBox(
      width: 76,
      height: 76,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 360),
          switchInCurve: Curves.elasticOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) {
            return ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            );
          },
          child: isVerified
              ? Container(
                  key: const ValueKey('badge_verified'),
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFDCFCE7),
                    border: Border.all(color: const Color(0xFFBBF7D0), width: 1.5),
                  ),
                  child: Center(
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF22C55E),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x5522C55E),
                            blurRadius: 14,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                )
              : AnimatedContainer(
                  key: ValueKey(isError
                      ? 'badge_error'
                      : (isUnlockedPre ? 'badge_unlocked' : 'badge_lock')),
                  duration: const Duration(milliseconds: 240),
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isError ? const Color(0xFFFFE4E6) : const Color(0xFFEEF2FF),
                    border: Border.all(
                      color: isError ? const Color(0xFFFECDD3) : const Color(0xFFE0E7FF),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    isUnlockedPre ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                    color: isError ? const Color(0xFFE11D48) : const Color(0xFF4F46E5),
                    size: 27,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDigitSlotBox(int index) {
    final digit = _digits[index];
    final hasDigit = digit.isNotEmpty;
    final isVerified = _state == _OtpV15State.verified;
    final isError = _state == _OtpV15State.error;
    final isFocused = _hiddenFocusNode.hasFocus &&
        _state == _OtpV15State.idle &&
        !_isDroppingOut &&
        _activeBoxIndex == index &&
        _enteredCount < 4;

    Color bgColor = const Color(0xFFF8FAFC);
    Color borderColor = const Color(0xFFE2E8F0);
    Color textColor = const Color(0xFF0F172A);
    Color dashColor = const Color(0xFFCBD5E1);
    double borderWidth = 1.5;

    if (isVerified) {
      bgColor = const Color(0xFF22C55E);
      borderColor = const Color(0xFF16A34A);
      textColor = Colors.white;
      dashColor = Colors.white.withValues(alpha: 0.45);
      borderWidth = 1.8;
    } else if (isError && hasDigit) {
      bgColor = const Color(0xFFFFF1F2);
      borderColor = const Color(0xFFFB7185);
      textColor = const Color(0xFFE11D48);
      dashColor = const Color(0xFFFDA4AF);
      borderWidth = 1.8;
    } else if (isFocused) {
      bgColor = Colors.white;
      borderColor = const Color(0xFF4F46E5);
      dashColor = const Color(0xFF4F46E5);
      borderWidth = 2.0;
    } else if (hasDigit) {
      bgColor = Colors.white;
      borderColor = const Color(0xFFCBD5E1);
      dashColor = const Color(0xFF94A3B8);
      borderWidth = 1.5;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: 60,
      height: 70,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: isVerified
            ? [
                BoxShadow(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ]
            : (isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.14),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Slot-Machine Vertical Roll Digit Transition
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 230),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final isIncoming = child.key == ValueKey<String>('digit_${index}_$digit');
                final offsetTween = isIncoming
                    ? Tween<Offset>(begin: const Offset(0, -0.75), end: Offset.zero)
                    : Tween<Offset>(begin: const Offset(0, 0.95), end: Offset.zero);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: offsetTween.animate(animation),
                    child: child,
                  ),
                );
              },
              child: hasDigit
                  ? Padding(
                      key: ValueKey<String>('digit_${index}_$digit'),
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        digit,
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                    )
                  : (isFocused && _showCursor
                      ? Container(
                          key: ValueKey<String>('cursor_$index'),
                          width: 2,
                          height: 24,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        )
                      : SizedBox.shrink(key: ValueKey<String>('empty_$index'))),
            ),

            // Bottom horizontal indicator bar inside each slot box
            Positioned(
              bottom: 7,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 18,
                height: 2.5,
                decoration: BoxDecoration(
                  color: dashColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSweepActionButton({
    required bool isVerified,
    required bool isVerifying,
  }) {
    final isReady = _enteredCount == 4;

    if (isVerified) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: widget.onVerifiedContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF22C55E),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Continue',
                style: TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: isReady && !isVerifying ? _triggerVerify : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          height: 52,
          color: isVerifying
              ? const Color(0xFF3730A3)
              : (isReady ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8)),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Left-to-Right Progress Sweep Bar during Verifying
              if (isVerifying)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _verifySweepController,
                    builder: (context, _) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _verifySweepController.value,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF4F46E5),
                                Color(0xFF6366F1),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Button Label & Spinner
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isVerifying
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
                            'Verifying',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Verify code',
                        key: ValueKey('btn_verify_code'),
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
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
