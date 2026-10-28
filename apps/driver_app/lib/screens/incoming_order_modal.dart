import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';
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
  Timer? _vibrationSoundTimer;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..forward();

    // High priority alert: Ringing sound and repeating vibration
    _startAlertNotification();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _stopAlert();
        timer.cancel();
        _declineOrder();
      } else {
        setState(() {
          _secondsLeft--;
        });
      }
    });
  }

  void _startAlertNotification() {
    // Immediate vibration and chime
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);

    // Continuous pulsating vibration until driver responds
    _vibrationSoundTimer = Timer.periodic(const Duration(milliseconds: 650), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    });
  }

  void _stopAlert() {
    _vibrationSoundTimer?.cancel();
    _vibrationSoundTimer = null;
  }

  @override
  void dispose() {
    _stopAlert();
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _acceptOrder() async {
    _stopAlert();
    _timer?.cancel();

    final driver = await SessionManager.getDriver();
    await ApiService.acceptOrder(
      tripId: widget.order.tripId,
      driverName: driver?.name ?? 'Dereva wa CARGOO',
      driverPhone: driver?.phone ?? '',
      driverPlate: driver?.vehiclePlate ?? '',
    );
    await SessionManager.saveActiveTrip(widget.order);

    if (!mounted) return;
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveTripScreen(order: widget.order),
      ),
    );
  }

  void _declineOrder() async {
    _stopAlert();
    _timer?.cancel();

    final driver = await SessionManager.getDriver();
    await ApiService.declineOrder(
      tripId: widget.order.tripId,
      driverPhone: driver?.phone ?? '',
    );

    if (!mounted) return;
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF16A34A), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
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
                        color: const Color(0x2016A34A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.notifications_active_rounded, color: Color(0xFF16A34A), size: 16),
                          SizedBox(width: 6),
                          Text(
                            'MZIGO MPYA WA KUBEBA!',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              color: Color(0xFF16A34A),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
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
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _secondsLeft > 10 ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                        Text(
                          '$_secondsLeft',
                          style: TextStyle(
                            fontFamily: 'Segoe UI Variable',
                            color: _secondsLeft > 10 ? const Color(0xFF1E2822) : const Color(0xFFEF4444),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Customer Info Bar (Real contact details)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFFE2E8F0),
                        child: Icon(Icons.person, size: 16, color: Color(0xFF4B7B9F)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mteja: ${order.customerName} • ${order.customerPhone}',
                          style: const TextStyle(
                            fontFamily: 'Segoe UI Variable',
                            color: Color(0xFF334155),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 1. UNATOKA WAPI (PICKUP)
                _buildFactRow(
                  icon: Icons.my_location_rounded,
                  iconColor: const Color(0xFF4B7B9F),
                  title: 'Unatoka Wapi (Eneo la Mzigo)',
                  headline: order.pickupName,
                  subtitle: 'Ndani ya radius ya 5km (Dakika 3-5 kufika)',
                ),

                const SizedBox(height: 14),

                // 2. UNAENDA WAPI (DROPOFF)
                _buildFactRow(
                  icon: Icons.location_on_rounded,
                  iconColor: const Color(0xFFEF4444),
                  title: 'Unaenda Wapi (Eneo la Kushusha)',
                  headline: order.dropoffName,
                  subtitle: '${order.distanceKm} km umbali wa safari',
                ),

                const SizedBox(height: 18),

                // 3. BEI / NAULI YA SAFARI
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '💰 Nauli ya Mteja (Taslimu):',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              color: Color(0xFF1E2822),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            order.fareAmount,
                            style: const TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              color: Color(0xFF1E2822),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '✂️ Kamasheni ya CARGOO (7%):',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              color: Color(0xFF6B7E74),
                              fontSize: 12.5,
                            ),
                          ),
                          Text(
                            '- TZS ${order.commissionAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              color: Color(0xFFEF4444),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Color(0xFFE2E8F0), height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '💵 Pesa Yako Mkononi (93%):',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              color: Color(0xFF16A34A),
                              fontSize: 13.5,
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
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // BUTTONS: KATAA vs POKEA SAFARI
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _declineOrder,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text(
                            'KATAA',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
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
                            backgroundColor: const Color(0xFF16A34A),
                            elevation: 2,
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
                                  fontFamily: 'Segoe UI Variable',
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
            color: iconColor.withValues(alpha: 0.15),
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
                style: const TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  color: Color(0xFF6B7E74),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                headline,
                style: const TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  color: Color(0xFF1E2822),
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  color: Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
