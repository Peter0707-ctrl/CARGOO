import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/order_model.dart';
import '../services/session_manager.dart';
import 'main_navigation_screen.dart';

class TripCompletedScreen extends StatefulWidget {
  final CargoOrder order;

  const TripCompletedScreen({super.key, required this.order});

  @override
  State<TripCompletedScreen> createState() => _TripCompletedScreenState();
}

class _TripCompletedScreenState extends State<TripCompletedScreen> {
  double _newTotalDebt = 0.0;

  @override
  void initState() {
    super.initState();
    _recordCompletion();
  }

  Future<void> _recordCompletion() async {
    final updatedDebt = await SessionManager.addCommissionDebt(widget.order.commissionAmount);
    await SessionManager.saveCompletedTrip(widget.order);

    if (mounted) {
      setState(() {
        _newTotalDebt = updatedDebt;
      });
    }
  }

  void _returnToDashboard() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFFF2F5F1),
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F5F1),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                const Spacer(),
                // Green Check Circle
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF16A34A), width: 3),
                  ),
                  child: const Center(
                    child: Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 52),
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  'SAFARI IMEKAMILIKA!',
                  style: TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    color: Color(0xFF1E2822),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Mzigo umeshushwa salama kwa mteja.',
                  style: TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    color: Color(0xFF6B7E74),
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 28),

                // Cash Collection Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'FEDHA TASLIMU YA KUPOKEA MKONONI:',
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          color: Color(0xFF6B7E74),
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        order.fareAmount,
                        style: const TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          color: Color(0xFF16A34A),
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Divider(color: Color(0xFFE2E8F0), height: 28),

                      // 7% CARGOO Commission
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '✂️ Kamasheni ya CARGOO (7%):',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              color: Color(0xFF1E2822),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '- TZS ${order.commissionAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              color: Color(0xFFEF4444),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // 93% Net Driver
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '💵 Faida Yako Halisi (93%):',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              color: Color(0xFF16A34A),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'TZS ${order.netDriverEarnings.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              color: Color(0xFF16A34A),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),

                      const Divider(color: Color(0xFFE2E8F0), height: 24),

                      // Wallet debt status
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFF4B7B9F), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Deni jipya la kamasheni kwenye pochi: TZS ${_newTotalDebt.toStringAsFixed(0)} / 10,000.',
                                style: const TextStyle(
                                  fontFamily: 'Segoe UI Variable',
                                  color: Color(0xFF6B7E74),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Primary Action: Return to Dashboard
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _returnToDashboard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'RUDI KWENYE KAZI (HEWANI)',
                          style: TextStyle(
                            fontFamily: 'Segoe UI Variable',
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, color: Colors.white),
                      ],
                    ),
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
