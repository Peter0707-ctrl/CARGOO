import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/driver_model.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import 'incoming_order_modal.dart';
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
  Timer? _orderPollerTimer;

  LatLng _currentLocation = const LatLng(-6.7715, 39.2399); // Dar es Salaam default
  double _todayCashInPocket = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDriverState();
    _initLocation();
  }

  @override
  void dispose() {
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
      _todayCashInPocket = totalCash;
      _isOnline = isLocked ? false : isOnline;
    });

    if (_isOnline) {
      if (driver != null) {
        ApiService.updateDriverStatus(
          phone: driver.phone,
          name: driver.name,
          isOnline: true,
          lat: _currentLocation.latitude,
          lng: _currentLocation.longitude,
          vehicleType: driver.vehicleType,
          vehiclePlate: driver.vehiclePlate,
        );
      }
      _startStandbyForOrders();
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
          _mapController.move(_currentLocation, 15.0);
        }
      }
    } catch (_) {
      // Fallback
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

    // Sync online state with CARGOO dispatch server
    final driver = _driver ?? await SessionManager.getDriver();
    if (driver != null) {
      ApiService.updateDriverStatus(
        phone: driver.phone,
        name: driver.name,
        isOnline: value,
        lat: _currentLocation.latitude,
        lng: _currentLocation.longitude,
        vehicleType: driver.vehicleType,
        vehiclePlate: driver.vehiclePlate,
      );
    }

    if (!mounted) return;

    if (value) {
      _startStandbyForOrders();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uko HEWANI (Standby). Chombo kipo tayari kupokea maombi ya mizigo.'),
          backgroundColor: Color(0xFF16A34A),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      _stopStandby();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uko MAPUMZIKONI (Offline).'),
          backgroundColor: Color(0xFF64748B),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _startStandbyForOrders() {
    _orderPollerTimer?.cancel();
    // Dereva anasubiri oda halisi kutoka kwa wateja (ndani ya 5km)
    _orderPollerTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!_isOnline || !mounted) return;
      _checkForPendingCustomerOrders();
    });
  }

  void _stopStandby() {
    _orderPollerTimer?.cancel();
  }

  bool _isModalOpen = false;

  void _checkForPendingCustomerOrders() async {
    if (!mounted || !_isOnline || _isModalOpen || _isDebtLocked) return;

    // KANUNI YA DISPATCH:
    // Dereva anapata oda anapokuwa hana safari inayoendelea (hana route)
    final active = await SessionManager.getActiveTrip();
    if (active != null) return;

    final orders = await ApiService.fetchPendingOrdersForDriver(
      lat: _currentLocation.latitude,
      lng: _currentLocation.longitude,
      vehicleType: _driver?.vehicleType ?? 'Kirikuu Pick-up',
      driverPhone: _driver?.phone ?? '',
      radiusKm: 5.0,
    );

    if (orders.isNotEmpty && mounted && !_isModalOpen) {
      _isModalOpen = true;
      if (!mounted) {
        _isModalOpen = false;
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => IncomingOrderModal(
          order: orders.first,
          onDismiss: () {
            _isModalOpen = false;
          },
        ),
      ).then((_) {
        _isModalOpen = false;
      });
    }
  }

  void _showDebtLimitAlert() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 28),
            SizedBox(width: 10),
            Text(
              'Kazi Zimefungwa!',
              style: TextStyle(
                fontFamily: 'Segoe UI Variable',
                color: Color(0xFF1E2822),
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Deni lako la kamasheni ya 7% limefikia TZS ${_walletDebt.toStringAsFixed(0)} (Ukomo ni TZS 10,000).\n\nTafadhali lipia kamasheni kupitia Pochi ya Dereva (M-Pesa au Tigo Pesa) ili uweze kurudi hewani kupokea mizigo.',
          style: const TextStyle(
            fontFamily: 'Segoe UI Variable',
            color: Color(0xFF6B7E74),
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('SAWA', style: TextStyle(color: Color(0xFF64748B))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F1),
      body: Stack(
        children: [
          // 1. Google Maps Standard Roadmap Tiles (Identical to Customer App)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 15.0,
              minZoom: 11.0,
              maxZoom: 19.0,
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
                            color: _isOnline ? const Color(0x3316A34A) : const Color(0x2064748B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _isOnline ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. Top Header Bar: Clean White Card & Standby Status
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5EEF5),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF4B7B9F), width: 1.5),
                          ),
                          child: const Icon(Icons.person_rounded, color: Color(0xFF4B7B9F), size: 26),
                        ),
                        const SizedBox(width: 12),
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
                                      style: const TextStyle(
                                        fontFamily: 'Segoe UI Variable',
                                        color: Color(0xFF1E2822),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 15),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_driver?.vehiclePlate ?? "T 482 DWK"} • ${_driver?.vehicleType ?? "Kirikuu"}',
                                style: const TextStyle(
                                  fontFamily: 'Segoe UI Variable',
                                  color: Color(0xFF6B7E74),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
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
                              activeThumbColor: const Color(0xFF16A34A),
                              activeTrackColor: const Color(0x3316A34A),
                              inactiveThumbColor: const Color(0xFF94A3B8),
                              inactiveTrackColor: const Color(0xFFE2E8F0),
                              onChanged: _toggleOnline,
                            ),
                            Text(
                              _isOnline ? 'HEWANI' : 'MAPUMZIKO',
                              style: TextStyle(
                                fontFamily: 'Segoe UI Variable',
                                color: _isOnline ? const Color(0xFF16A34A) : const Color(0xFF6B7E74),
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Floating Recenter Button
          Positioned(
            right: 16,
            bottom: 120,
            child: FloatingActionButton.small(
              heroTag: 'recenter_map',
              backgroundColor: Colors.white,
              onPressed: () => _mapController.move(_currentLocation, 15),
              child: const Icon(Icons.my_location_rounded, color: Color(0xFF4B7B9F)),
            ),
          ),

          // 4. Quick Today Summary Banner
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Cash Mkononi Leo (93%):',
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          color: Color(0xFF6B7E74),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'TZS ${_todayCashInPocket.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          color: Color(0xFF16A34A),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 30,
                    width: 1,
                    color: const Color(0xFFE2E8F0),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Deni la Kamasheni (7%):',
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          color: Color(0xFF6B7E74),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'TZS ${_walletDebt.toStringAsFixed(0)} / 10k',
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          color: _isDebtLocked ? const Color(0xFFEF4444) : const Color(0xFF1E2822),
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
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
