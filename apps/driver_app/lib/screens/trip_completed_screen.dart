import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../services/session_manager.dart';
import 'driver_dashboard_screen.dart';

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
    // Add 7% commission to driver's post-pay wallet debt
    final updatedDebt = await SessionManager.addCommissionDebt(widget.order.commissionAmount);
    // Save to completed trips history
    await SessionManager.saveCompletedTrip(widget.order);

    if (mounted) {
      setState(() {
        _newTotalDebt = updatedDebt;
      });
    }
  }

  void _returnToDashboard() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DriverDashboardScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
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
                  color: const Color(0x3322C55E),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF22C55E), width: 3),
                ),
                child: const Center(
                  child: Icon(Icons.check_rounded, color: Color(0xFF22C55E), size: 52),
                ),
              ),

              const SizedBox(height: 20),
              const Text(
                'SAFARI IMEKAMILIKA!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Mzigo umeshushwa salama kwa mteja.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
              ),

              const SizedBox(height: 28),

              // Cash Collection Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'FEDHA TASLIMU YA KUPOKEA MKONONI:',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      order.fareAmount,
                      style: const TextStyle(
                        color: Color(0xFF22C55E),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Divider(color: Color(0xFF334155), height: 28),

                    // 7% CARGOO Commission
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '✂️ Kamasheni ya CARGOO (7%):',
                          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
                        ),
                        Text(
                          '- TZS ${order.commissionAmount.toStringAsFixed(0)}',
                          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // 93% Net Driver
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '💵 Faida Yako Halisi (93%):',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'TZS ${order.netDriverEarnings.toStringAsFixed(0)}',
                          style: const TextStyle(color: Color(0xFF22C55E), fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),

                    const Divider(color: Color(0xFF334155), height: 24),

                    // Wallet debt status
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Deni jipya la kamasheni kwenye pochi: TZS ${_newTotalDebt.toStringAsFixed(0)} / 10,000.',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
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
                    backgroundColor: const Color(0xFF22C55E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'RUDI KWENYE KAZI (HEWANI)',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
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
    );
  }
}
