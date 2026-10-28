import 'dart:async';
import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../services/session_manager.dart';
import 'active_trip_screen.dart';

class IncomingOrderModal extends StatefulWidget {
  final CargoOrder order;
  final VoidCallback onDismiss;

  const IncomingOrderModal({
    super.key,
    required this.order,
    required this.onDismiss,
  });

  @override
  State<IncomingOrderModal> createState() => _IncomingOrderModalState();
}

class _IncomingOrderModalState extends State<IncomingOrderModal>
    with SingleTickerProviderStateMixin {
  int _secondsLeft = 30;
  Timer? _timer;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        widget.onDismiss();
      } else {
        setState(() {
          _secondsLeft--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _acceptOrder() async {
    _timer?.cancel();
    await SessionManager.saveActiveTrip(widget.order);

    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss modal
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveTripScreen(order: widget.order),
      ),
    );
  }

  void _declineOrder() {
    _timer?.cancel();
    Navigator.of(context).pop();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF22C55E), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4D22C55E),
              blurRadius: 30,
              spreadRadius: 4,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top alert & timer bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0x3322C55E),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.notifications_active_rounded, color: Color(0xFF22C55E), size: 16),
                          SizedBox(width: 6),
                          Text(
                            'MZIGO MPYA WA KUBEBA!',
                            style: TextStyle(color: Color(0xFF22C55E), fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),

                    // Countdown Ring
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            value: _secondsLeft / 30.0,
                            strokeWidth: 3.5,
                            backgroundColor: const Color(0xFF334155),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _secondsLeft > 10 ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                        Text(
                          '$_secondsLeft',
                          style: TextStyle(
                            color: _secondsLeft > 10 ? Colors.white : const Color(0xFFEF4444),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 4 KEY FACTS AS REQUESTED:
                // 1. PICKUP
                _buildFactRow(
                  icon: Icons.my_location_rounded,
                  iconColor: const Color(0xFF38BDF8),
                  title: 'Eneo la Kuchukua Mzigo (Pickup)',
                  headline: order.pickupName,
                  subtitle: 'Mita 800 kutoka hapa (Dakika 3 kufika)',
                ),

                const SizedBox(height: 14),

                // 2. DROPOFF
                _buildFactRow(
                  icon: Icons.location_on_rounded,
                  iconColor: const Color(0xFFEF4444),
                  title: 'Eneo la Kushusha Mzigo (Dropoff)',
                  headline: order.dropoffName,
                  subtitle: '${order.distanceKm} km kutoka eneo la mzigo',
                ),

                const SizedBox(height: 14),

                // 3. CARGO NOTES
                _buildFactRow(
                  icon: Icons.inventory_2_outlined,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Maelezo ya Mzigo',
                  headline: order.cargoNotes.isNotEmpty ? order.cargoNotes : 'Vifaa vya ujenzi na mifuko ya saruji',
                  subtitle: 'Aina: ${order.vehicleType}',
                ),

                const SizedBox(height: 18),

                // 4. CASH BREAKDOWN (7% CARGOO / 93% DEREVA)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '💰 Nauli ya Mteja (Taslimu):',
                            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            order.fareAmount,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '✂️ Kamasheni ya CARGOO (7%):',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                          ),
                          Text(
                            '- TZS ${order.commissionAmount.toStringAsFixed(0)}',
                            style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(color: Color(0xFF334155), height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '💵 Pesa Yako Mkononi (93%):',
                            style: TextStyle(color: Color(0xFF22C55E), fontSize: 13.5, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'TZS ${order.netDriverEarnings.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Color(0xFF22C55E),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ACTION BUTTONS: [ KATAA ] vs [ POKEA SAFARI ]
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _declineOrder,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF64748B)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text(
                            'KATAA',
                            style: TextStyle(color: Color(0xFFCBD5E1), fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _acceptOrder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22C55E),
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'POKEA SAFARI',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFactRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String headline,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0x2638BDF8),
            shape: BoxShape.circle,
          ),
          child: Center(child: Icon(icon, color: iconColor, size: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                headline,
                style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
