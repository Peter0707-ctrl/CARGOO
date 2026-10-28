import 'dart:async';
import 'package:flutter/material.dart';
import '../models/driver_model.dart';
import '../services/session_manager.dart';
import 'driver_dashboard_screen.dart';

class PjVerificationScreen extends StatefulWidget {
  final DriverModel driver;

  const PjVerificationScreen({super.key, required this.driver});

  @override
  State<PjVerificationScreen> createState() => _PjVerificationScreenState();
}

class _PjVerificationScreenState extends State<PjVerificationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  int _currentStep = 0;
  bool _isVerifying = true;
  String _pjSpeech = 'Habari! Naitwa PJ, Afisa wa AI wa CARGOO. Nipo tayari kufanya uhakiki wa usajili wako sasa...';

  final List<Map<String, dynamic>> _checks = [
    {
      'title': 'Uhakiki wa Kitambulisho cha NIDA',
      'detail': 'Inakagua namba 20 za NIDA kwenye mfumo wa uhakiki wa Taifa...',
      'successMsg': 'NIDA Imethibitishwa: Namba ni halali na haina dosari.',
      'done': false,
      'icon': Icons.badge_outlined,
    },
    {
      'title': 'Leseni ya Udereva (LATRA / Police)',
      'detail': 'Inathibitisha daraja la leseni kulingana na aina ya chombo...',
      'successMsg': 'Leseni Imethibitishwa: Daraja linaruhusu kubeba mizigo ya kibiashara.',
      'done': false,
      'icon': Icons.drive_eta_outlined,
    },
    {
      'title': 'Namba ya Usajili wa Chombo (TRA)',
      'detail': 'Inathibitisha namba ya bati, kadi ya gari na bima...',
      'successMsg': 'Chombo Kimethibitishwa: Kadi na usajili wa TRA viko hai.',
      'done': false,
      'icon': Icons.local_shipping_outlined,
    },
    {
      'title': 'Usalama & Rekodi ya Uaminifu ya Dereva',
      'detail': 'Inakagua rekodi za usalama, uzoefu na ulinzi wa mizigo ya wateja...',
      'successMsg': 'AI Trust Score: 99.4% • Rekodi safi ya uaminifu!',
      'done': false,
      'icon': Icons.verified_user_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startAiVerificationProcess();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startAiVerificationProcess() async {
    await Future.delayed(const Duration(milliseconds: 1200));

    for (int i = 0; i < _checks.length; i++) {
      if (!mounted) return;
      setState(() {
        _currentStep = i;
        _pjSpeech = 'Hatua ${i + 1}/4: ${_checks[i]['detail']}';
      });

      await Future.delayed(const Duration(milliseconds: 1800));

      if (!mounted) return;
      setState(() {
        _checks[i]['done'] = true;
        _pjSpeech = '✓ ${_checks[i]['successMsg']}';
      });

      await Future.delayed(const Duration(milliseconds: 800));
    }

    if (!mounted) return;
    setState(() {
      _isVerifying = false;
      _pjSpeech =
          'Hongera ${widget.driver.name}! Mfumo wa AI wa PJ umethibitisha nyaraka na chombo chako. Una sifa kamili za kuwa dereva wa CARGOO. Karibu barabarani!';
    });

    // Save PJ verification in session
    await SessionManager.setPjVerified(true);
  }

  void _proceedToDashboard() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DriverDashboardScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isVerifying ? const Color(0xFF38BDF8) : const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isVerifying ? 'AI PJ INAHAKIKI...' : 'AI PJ: IMETHIBITISHWA ✓',
                          style: TextStyle(
                            color: _isVerifying ? const Color(0xFF38BDF8) : const Color(0xFF22C55E),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'HATUA YA 1 YA USAJILI',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // AI Avatar & Glowing Holographic Orb
            Center(
              child: ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: _isVerifying
                          ? [const Color(0xFF38BDF8), const Color(0xFF0284C7), const Color(0xFF0F172A)]
                          : [const Color(0xFF22C55E), const Color(0xFF16A34A), const Color(0xFF0F172A)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isVerifying ? const Color(0x6638BDF8) : const Color(0x6622C55E),
                        blurRadius: 30,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 86,
                      height: 86,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0B132B),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          _isVerifying ? Icons.psychology_rounded : Icons.verified_rounded,
                          size: 46,
                          color: _isVerifying ? const Color(0xFF38BDF8) : const Color(0xFF22C55E),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Text(
              'AFISA PJ • CARGOO AI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const Text(
              'Uhakiki wa Kiotomatiki wa Nyaraka & Usalama',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),

            const SizedBox(height: 16),

            // Speech Bubble from PJ
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isVerifying ? const Color(0x8038BDF8) : const Color(0x8022C55E),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: _isVerifying ? const Color(0xFF38BDF8) : const Color(0xFF22C55E),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _pjSpeech,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Step List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _checks.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final check = _checks[index];
                  final isDone = check['done'] as bool;
                  final isCurrent = index == _currentStep && _isVerifying;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDone
                          ? const Color(0xFF13271F)
                          : isCurrent
                              ? const Color(0xFF1A2A44)
                              : const Color(0xFF161F30),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDone
                            ? const Color(0x8022C55E)
                            : isCurrent
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFF334155),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDone
                                ? const Color(0x3322C55E)
                                : isCurrent
                                    ? const Color(0x3338BDF8)
                                    : const Color(0x33334155),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: isDone
                                ? const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 24)
                                : isCurrent
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                                        ),
                                      )
                                    : Icon(check['icon'] as IconData, color: const Color(0xFF64748B), size: 20),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                check['title'] as String,
                                style: TextStyle(
                                  color: isDone || isCurrent ? Colors.white : const Color(0xFF94A3B8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isDone ? check['successMsg'] as String : check['detail'] as String,
                                style: TextStyle(
                                  color: isDone
                                      ? const Color(0xFF4ADE80)
                                      : isCurrent
                                          ? const Color(0xFF93C5FD)
                                          : const Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Action Area
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                border: Border(top: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Column(
                children: [
                  if (_isVerifying)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Afisa PJ anamalizia uhakiki wa usalama...',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _proceedToDashboard,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'ENDELEA KWENYE DASHBOARD',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
