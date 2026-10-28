import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import 'main_navigation_screen.dart';
import 'trip_completed_screen.dart';

enum TripStage {
  enRoutePickup,
  arrivedPickup,
  cargoLoaded,
  inTransit,
  arrivedDropoff,
}

class ActiveTripScreen extends StatefulWidget {
  final CargoOrder order;

  const ActiveTripScreen({super.key, required this.order});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  final MapController _mapController = MapController();
  TripStage _stage = TripStage.enRoutePickup;

  late LatLng _driverLocation;
  late LatLng _pickupLocation;
  late LatLng _dropoffLocation;

  double _distanceToDropoffMeters = 3500.0;
  bool _canFinishTrip = false; // Must be <= 250 meters from dropoff

  Timer? _motionSimulationTimer;
  Timer? _customerCancellationPoller;
  final List<Map<String, dynamic>> _chatMessages = [];
  final TextEditingController _chatInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pickupLocation = LatLng(widget.order.pickupLat, widget.order.pickupLng);
    _dropoffLocation = LatLng(widget.order.dropoffLat, widget.order.dropoffLng);
    _driverLocation = LatLng(widget.order.pickupLat - 0.005, widget.order.pickupLng - 0.004);

    _initDefaultChat();
    _calculateDistanceToDropoff();
    _startSimulatedGpsMotion();
    _listenForCustomerCancellation();
  }

  @override
  void dispose() {
    _motionSimulationTimer?.cancel();
    _customerCancellationPoller?.cancel();
    _chatInputController.dispose();
    super.dispose();
  }

  void _listenForCustomerCancellation() {
    _customerCancellationPoller = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!mounted) return;
      try {
        final res = await http.get(Uri.parse('${ApiService.baseUrl}/orders/${widget.order.tripId}')).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['order'] != null && data['order']['status'] == 'cancelled') {
            timer.cancel();
            await SessionManager.clearActiveTrip();
            if (!mounted) return;
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  children: const [
                    Icon(Icons.info_rounded, color: Color(0xFFEF4444)),
                    SizedBox(width: 8),
                    Text('Safari Imeahirishwa', style: TextStyle(fontFamily: 'Segoe UI Variable', fontWeight: FontWeight.bold)),
                  ],
                ),
                content: const Text(
                  'Mteja ameamua kuahirisha safari hii. Chombo chako kimerudishwa kwenye hali ya utayari kupokea mizigo mingine.',
                  style: TextStyle(fontFamily: 'Segoe UI Variable', color: Color(0xFF64748B)),
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                    child: const Text('SAWA, NIMEFAHAMU', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }
        }
      } catch (_) {}
    });
  }

  void _initDefaultChat() {
    _chatMessages.add({
      'sender': 'mteja',
      'text': 'Habari dereva! Mzigo uko tayari hapa getini.',
      'time': 'Sasa hivi',
    });
  }

  void _calculateDistanceToDropoff() {
    final dist = Geolocator.distanceBetween(
      _driverLocation.latitude,
      _driverLocation.longitude,
      _dropoffLocation.latitude,
      _dropoffLocation.longitude,
    );

    setState(() {
      _distanceToDropoffMeters = dist;
      // GEOFENCE: 250 meters threshold
      _canFinishTrip = dist <= 250.0 || _stage == TripStage.arrivedDropoff;
    });
  }

  void _startSimulatedGpsMotion() {
    _motionSimulationTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      if (_stage == TripStage.inTransit) {
        // Move gradually towards dropoff
        final latDiff = (_dropoffLocation.latitude - _driverLocation.latitude) * 0.15;
        final lngDiff = (_dropoffLocation.longitude - _driverLocation.longitude) * 0.15;

        setState(() {
          _driverLocation = LatLng(_driverLocation.latitude + latDiff, _driverLocation.longitude + lngDiff);
        });
        _calculateDistanceToDropoff();
      }
    });
  }

  void _nextStage() async {
    if (_stage == TripStage.enRoutePickup) {
      setState(() => _stage = TripStage.arrivedPickup);
      await ApiService.updateTripStatus(tripId: widget.order.tripId, status: 'arrived_pickup');
    } else if (_stage == TripStage.arrivedPickup) {
      // CARGO LOADED - CANNOT CANCEL AFTER THIS
      setState(() => _stage = TripStage.cargoLoaded);
      await ApiService.updateTripStatus(tripId: widget.order.tripId, status: 'cargo_loaded');
    } else if (_stage == TripStage.cargoLoaded) {
      setState(() => _stage = TripStage.inTransit);
      await ApiService.updateTripStatus(tripId: widget.order.tripId, status: 'en_route');
    } else if (_stage == TripStage.inTransit) {
      // Simulate fast arrival within geofence for testing
      setState(() {
        _stage = TripStage.arrivedDropoff;
        _driverLocation = _dropoffLocation;
        _distanceToDropoffMeters = 40.0;
        _canFinishTrip = true;
      });
      _mapController.move(_dropoffLocation, 16);
      await ApiService.updateTripStatus(tripId: widget.order.tripId, status: 'arrived_dropoff');
    } else if (_stage == TripStage.arrivedDropoff) {
      _finishTrip();
    }
  }

  void _finishTrip() async {
    if (!_canFinishTrip) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Huwezi kumaliza safari ukiwa mbali! Uko mita ${_distanceToDropoffMeters.toStringAsFixed(0)} kutoka eneo la kushusha (Unatakiwa uwe ndani ya mita 250).',
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    // Complete trip
    await ApiService.updateTripStatus(tripId: widget.order.tripId, status: 'delivered');
    await SessionManager.clearActiveTrip();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TripCompletedScreen(order: widget.order),
      ),
    );
  }

  void _makePhoneCall() async {
    final uri = Uri.parse('tel:${widget.order.customerPhone.replaceAll(' ', '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Piga namba: ${widget.order.customerPhone}')),
      );
    }
  }

  void _openChatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SizedBox(
              height: 480,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFF22C55E),
                            radius: 18,
                            child: Icon(Icons.person, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.order.customerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              const Text('Mteja wa Mzigo • Yuko Hewani', style: TextStyle(color: Color(0xFF22C55E), fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF1E293B)),

                  // Chat history
                  Expanded(
                    child: ListView.builder(
                      itemCount: _chatMessages.length,
                      itemBuilder: (context, idx) {
                        final msg = _chatMessages[idx];
                        final isMe = msg['sender'] == 'dereva';
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMe ? const Color(0xFF22C55E) : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg['text'] as String,
                                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  msg['time'] as String,
                                  style: TextStyle(
                                    color: isMe ? Colors.white70 : const Color(0xFF94A3B8),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Quick reply chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _quickChip('Nipo njiani nakuja', setSheetState),
                        _quickChip('Nimefika getini', setSheetState),
                        _quickChip('Mzigo umepakiwa salama', setSheetState),
                        _quickChip('Nakaribia eneo la kushusha', setSheetState),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Input bar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatInputController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Andika ujumbe kwa mteja...',
                            hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(backgroundColor: const Color(0xFF22C55E)),
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        onPressed: () {
                          final text = _chatInputController.text.trim();
                          if (text.isEmpty) return;
                          _sendMessage(text, setSheetState);
                          _chatInputController.clear();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _quickChip(String text, void Function(void Function()) setSheetState) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        backgroundColor: const Color(0xFF1E293B),
        label: Text(text, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11)),
        onPressed: () {
          _sendMessage(text, setSheetState);
        },
      ),
    );
  }

  void _sendMessage(String text, void Function(void Function()) setSheetState) {
    final now = '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';
    setSheetState(() {
      _chatMessages.add({'sender': 'dereva', 'text': text, 'time': now});
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    String stageTitle = 'Elekea Eneo la Mzigo';
    String actionBtnLabel = 'NIMEFIKA ENEO LA MZIGO';
    Color actionBtnColor = const Color(0xFF22C55E);

    if (_stage == TripStage.arrivedPickup) {
      stageTitle = 'Umefika Eneo la Mzigo';
      actionBtnLabel = 'MZIGO UMEPAKIWA • ANZA SAFARI';
      actionBtnColor = const Color(0xFF38BDF8);
    } else if (_stage == TripStage.cargoLoaded) {
      stageTitle = 'Mzigo Umepakiwa';
      actionBtnLabel = 'ANZA KUELEKEA KUSHUSHA';
      actionBtnColor = const Color(0xFF22C55E);
    } else if (_stage == TripStage.inTransit) {
      stageTitle = 'Upo Safarini na Mzigo';
      actionBtnLabel = 'SIMULATE KUFIKA (TEST 250M GEOFENCE)';
      actionBtnColor = const Color(0xFFF59E0B);
    } else if (_stage == TripStage.arrivedDropoff) {
      stageTitle = 'Umefika Eneo la Kushusha';
      actionBtnLabel = 'MALIZA SAFARI & POKEA CASH';
      actionBtnColor = const Color(0xFF22C55E);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Huwezi kuondoka kwenye safari inayoendelea!'),
              backgroundColor: Color(0xFFEF4444),
              duration: Duration(seconds: 2),
            ),
          );
        },
        child: Stack(
        children: [
          // 1. Live Flutter Map with Route Markers
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pickupLocation,
              initialZoom: 14.0,
            ),
            children: [
              // Google Maps Standard Roadmap Tiles (Identical to Customer App)
              TileLayer(
                urlTemplate: 'https://{s}.google.com/vt/lyrs=m&hl=en&x={x}&y={y}&z={z}',
                subdomains: const ['mt0', 'mt1', 'mt2', 'mt3'],
                userAgentPackageName: 'com.cargoo.driver_app',
                maxZoom: 20,
              ),

              // Polyline Route Layer
              PolylineLayer(
                polylines: [
                  // Outer soft glow casing
                  Polyline(
                    points: [
                      _driverLocation,
                      if (_stage == TripStage.enRoutePickup || _stage == TripStage.arrivedPickup) _pickupLocation,
                      _dropoffLocation,
                    ],
                    color: const Color(0x4D22C55E),
                    strokeWidth: 8.5,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                  // Core route line
                  Polyline(
                    points: [
                      _driverLocation,
                      if (_stage == TripStage.enRoutePickup || _stage == TripStage.arrivedPickup) _pickupLocation,
                      _dropoffLocation,
                    ],
                    color: const Color(0xFF22C55E),
                    strokeWidth: 5.5,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ],
              ),

              MarkerLayer(
                markers: [
                  // Driver Marker with Vehicle Icon & Live Pulse
                  Marker(
                    point: _driverLocation,
                    width: 52,
                    height: 52,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3))],
                      ),
                      child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 26),
                    ),
                  ),

                  // Pickup Marker with CARGOO Pill
                  Marker(
                    point: _pickupLocation,
                    width: 120,
                    height: 64,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                          ),
                          child: const Text(
                            'MZIGO • PICKUP',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Icon(Icons.location_on_rounded, color: Color(0xFF38BDF8), size: 30),
                      ],
                    ),
                  ),

                  // Dropoff Marker with Destination Pill
                  Marker(
                    point: _dropoffLocation,
                    width: 120,
                    height: 64,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                          ),
                          child: const Text(
                            'KUSHUSHA',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Icon(Icons.flag_rounded, color: Color(0xFFEF4444), size: 30),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. Top Stage Status Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Container(
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: actionBtnColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.route_rounded, color: actionBtnColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            stageTitle.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              color: actionBtnColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _stage == TripStage.inTransit || _stage == TripStage.arrivedDropoff
                                ? 'Kuelekea: ${order.dropoffName}'
                                : 'Eneo la Mzigo: ${order.pickupName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              color: Color(0xFF1E2822),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.my_location_rounded, color: Color(0xFF4B7B9F)),
                      onPressed: () => _mapController.move(_driverLocation, 15),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Customer Info & Quick Communication Bar
          Positioned(
            left: 16,
            right: 16,
            bottom: 220,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFE5EEF5),
                    radius: 20,
                    child: Icon(Icons.person, color: Color(0xFF4B7B9F), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          order.customerName,
                          style: const TextStyle(
                            fontFamily: 'Segoe UI Variable',
                            color: Color(0xFF1E2822),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          order.customerPhone,
                          style: const TextStyle(
                            fontFamily: 'Segoe UI Variable',
                            color: Color(0xFF6B7E74),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Call button
                  IconButton(
                    onPressed: _makePhoneCall,
                    style: IconButton.styleFrom(backgroundColor: const Color(0x2016A34A)),
                    icon: const Icon(Icons.call_rounded, color: Color(0xFF16A34A), size: 22),
                  ),
                  const SizedBox(width: 6),
                  // Chat button
                  IconButton(
                    onPressed: _openChatSheet,
                    style: IconButton.styleFrom(backgroundColor: const Color(0x204B7B9F)),
                    icon: const Icon(Icons.chat_rounded, color: Color(0xFF4B7B9F), size: 22),
                  ),
                ],
              ),
            ),
          ),

          // 4. Bottom Action & Geofence Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Fare summary strip
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.payments_rounded, color: Color(0xFF16A34A), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Nauli ya Cash: ${order.fareAmount}',
                            style: const TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              color: Color(0xFF1E2822),
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Kamasheni 7%: TZS ${order.commissionAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          color: Color(0xFF6B7E74),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Geofence Distance Warning if at Dropoff Stage
                  if (_stage == TripStage.inTransit || _stage == TripStage.arrivedDropoff) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _canFinishTrip ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _canFinishTrip ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _canFinishTrip ? Icons.check_circle_rounded : Icons.location_off_rounded,
                            color: _canFinishTrip ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _canFinishTrip
                                  ? 'Ndani ya Mita 250 (Geofenced): Unaweza kumaliza safari sasa!'
                                  : 'Uko mita ${_distanceToDropoffMeters.toStringAsFixed(0)} kutoka eneo la kushusha (Kumaliza inaruhusiwa ndani ya 250m tu).',
                              style: TextStyle(
                                fontFamily: 'Segoe UI Variable',
                                color: _canFinishTrip ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Primary Stage Progression Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_stage == TripStage.arrivedDropoff && !_canFinishTrip) ? null : _nextStage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: actionBtnColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                      ),
                      child: Text(
                        actionBtnLabel,
                        style: const TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  // Anti-fraud: Driver cannot cancel once trip is accepted (Only customer has cancel authority)
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.shield_rounded, color: Color(0xFF6B7E74), size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Safari inaendelea. Ni mteja pekee anayeruhusiwa kughairi.',
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          color: Color(0xFF6B7E74),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
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
    ),
  );
  }
}
