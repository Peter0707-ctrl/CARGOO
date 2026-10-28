import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/driver_model.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import 'incoming_order_modal.dart';
import 'driver_wallet_screen.dart';
import 'active_trip_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final MapController _mapController = MapController();

  DriverModel? _driver;
  bool _isOnline = false;
  double _walletDebt = 0.0;
  bool _isDebtLocked = false;
  int _searchRadius = 1; // 1km -> 2km -> 3km -> 4km -> 5km max
  Timer? _searchRadiusTimer;
  Timer? _orderPollerTimer;

  LatLng _currentLocation = const LatLng(-6.7715, 39.2399); // Dar es Salaam default
  List<CargoOrder> _completedTrips = [];
  double _todayCashInPocket = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDriverState();
    _initLocation();
  }

  @override
  void dispose() {
    _searchRadiusTimer?.cancel();
    _orderPollerTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDriverState() async {
    final driver = await SessionManager.getDriver();
    final isOnline = await SessionManager.isOnline();
    final debt = await SessionManager.getWalletDebt();
    final isLocked = await SessionManager.isDebtLimitExceeded();
    final history = await SessionManager.getCompletedTrips();

    if (!mounted) return;

    // Check if active trip exists
    final activeTrip = await SessionManager.getActiveTrip();
    if (activeTrip != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ActiveTripScreen(order: activeTrip)),
      );
      return;
    }

    double totalCash = 0.0;
    for (var trip in history) {
      totalCash += trip.netDriverEarnings;
    }

    setState(() {
      _driver = driver;
      _walletDebt = debt;
      _isDebtLocked = isLocked;
      _completedTrips = history;
      _todayCashInPocket = totalCash;
      _isOnline = isLocked ? false : isOnline;
    });

    if (_isOnline) {
      _startSearchingForOrders();
    }
  }

  Future<void> _initLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 4),
          ),
        );
        if (mounted) {
          setState(() {
            _currentLocation = LatLng(pos.latitude, pos.longitude);
          });
          _mapController.move(_currentLocation, 14.5);
        }
      }
    } catch (_) {
      // Fallback to Dar es Salaam center
    }
  }

  void _toggleOnline(bool value) async {
    if (value && _isDebtLocked) {
      _showDebtLimitAlert();
      return;
    }

    setState(() {
      _isOnline = value;
    });
    await SessionManager.setOnline(value);

    if (!mounted) return;

    if (value) {
      _startSearchingForOrders();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uko HEWANI (Online). Mfumo unatafuta mizigo ya karibu...'),
          backgroundColor: Color(0xFF22C55E),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      _stopSearching();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uko MAPUMZIKONI (Offline).'),
          backgroundColor: Color(0xFF64748B),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _startSearchingForOrders() {
    _searchRadiusTimer?.cancel();
    _orderPollerTimer?.cancel();

    _searchRadius = 1;
    _searchRadiusTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (!mounted) return;
      setState(() {
        if (_searchRadius < 5) {
          _searchRadius++;
        }
      });
    });

    // Check for dispatched orders or trigger periodic simulation
    _orderPollerTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!_isOnline || !mounted) return;
      _triggerIncomingOrderSimulation();
    });
  }

  void _stopSearching() {
    _searchRadiusTimer?.cancel();
    _orderPollerTimer?.cancel();
  }

  void _triggerIncomingOrderSimulation() {
    if (!mounted) return;
    final sampleOrder = ApiService.generateSampleOrder(
      vehicleType: _driver?.vehicleType ?? 'Kirikuu Pick-up',
      currentLat: _currentLocation.latitude,
      currentLng: _currentLocation.longitude,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => IncomingOrderModal(
        order: sampleOrder,
        onDismiss: () {
          // Continue searching
        },
      ),
    );
  }

  void _showDebtLimitAlert() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 28),
            SizedBox(width: 10),
            Text('Kazi Zimefungwa!', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Deni lako la kamasheni ya 7% limefikia TZS ${_walletDebt.toStringAsFixed(0)} (Ukomo ni TZS 10,000).\n\nTafadhali lipia kamasheni kupitia M-Pesa au Tigo Pesa ili uweze kurudi hewani kupokea mizigo.',
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('BAADAYE', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToWallet();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E)),
            child: const Text('LIPA KAMASHENI SASA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _navigateToWallet() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DriverWalletScreen()),
    );
    _loadDriverState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // 1. Live Interactive Flutter Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 14.5,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.google.com/vt/lyrs=m&hl=en&x={x}&y={y}&z={z}',
                subdomains: const ['mt0', 'mt1', 'mt2', 'mt3'],
                userAgentPackageName: 'com.cargoo.driver_app',
                maxZoom: 20,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation,
                    width: 60,
                    height: 60,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _isOnline ? const Color(0x4022C55E) : const Color(0x339E9E9E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _isOnline ? const Color(0xFF22C55E) : const Color(0xFF475569),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                          ),
                          child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. Top Driver Info & Online Toggle Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xF20F172A),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF1E293B)),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        // Driver Avatar / Icon
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
                          ),
                          child: const Icon(Icons.person_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 12),
                        // Driver Name & Plate
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _driver?.name ?? 'Dereva wa CARGOO',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified_rounded, color: Color(0xFF22C55E), size: 15),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_driver?.vehiclePlate ?? "T 482 DWK"} • ${_driver?.vehicleType ?? "Kirikuu"}',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),

                        // Online / Offline Switch
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Switch(
                              value: _isOnline,
                              activeThumbColor: const Color(0xFF22C55E),
                              activeTrackColor: const Color(0x4D22C55E),
                              inactiveThumbColor: const Color(0xFF64748B),
                              inactiveTrackColor: const Color(0xFF334155),
                              onChanged: _toggleOnline,
                            ),
                            Text(
                              _isOnline ? 'HEWANI (Online)' : 'MAPUMZIKO',
                              style: TextStyle(
                                color: _isOnline ? const Color(0xFF22C55E) : const Color(0xFF94A3B8),
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Search Radius Indicator when Online
                  if (_isOnline) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xEB1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x8038BDF8)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Inatafuta mizigo: Umbali wa ${_searchRadius}km kutoka hapa...',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 3. Floating Test Simulator Button (For Developer & User Testing)
          Positioned(
            right: 16,
            bottom: 240,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'recenter_map',
                  backgroundColor: const Color(0xFF1E293B),
                  onPressed: () => _mapController.move(_currentLocation, 15),
                  child: const Icon(Icons.my_location_rounded, color: Colors.white),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'simulate_order_button',
                  backgroundColor: const Color(0xFFF59E0B),
                  onPressed: _triggerIncomingOrderSimulation,
                  icon: const Icon(Icons.bolt_rounded, color: Colors.black),
                  label: const Text(
                    'Pima Oda ya Mzigo',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // 4. Bottom Cockpit Dashboard Card
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, -4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Wallet & Commission Debt Banner (Post-Pay 7%)
                  InkWell(
                    onTap: _navigateToWallet,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isDebtLocked
                            ? const Color(0xFF451A1A)
                            : _walletDebt > 7000
                                ? const Color(0xFF422006)
                                : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _isDebtLocked
                              ? const Color(0xFFEF4444)
                              : _walletDebt > 7000
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF334155),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isDebtLocked ? Icons.lock_clock_rounded : Icons.account_balance_wallet_outlined,
                            color: _isDebtLocked ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Salio la Kamasheni (7%):',
                                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, fontWeight: FontWeight.w600),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'Deni: TZS ${_walletDebt.toStringAsFixed(0)} / 10,000',
                                      style: TextStyle(
                                        color: _isDebtLocked ? const Color(0xFFEF4444) : Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (_walletDebt / 10000.0).clamp(0.0, 1.0),
                                    backgroundColor: const Color(0xFF334155),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _isDebtLocked
                                          ? const Color(0xFFEF4444)
                                          : _walletDebt > 7000
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFF22C55E),
                                    ),
                                    minHeight: 5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF64748B), size: 14),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Today's Earnings Summary
                  Row(
                    children: [
                      // Cash in pocket
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Cash Mkononi (93%)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                              const SizedBox(height: 4),
                              Text(
                                'TZS ${_todayCashInPocket.toStringAsFixed(0)}',
                                style: const TextStyle(color: Color(0xFF22C55E), fontSize: 16, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Trips count
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Safari Zilizokamilika', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                              const SizedBox(height: 4),
                              Text(
                                '${_completedTrips.length} Safari',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
