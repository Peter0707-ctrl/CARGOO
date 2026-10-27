import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import 'main_navigation_screen.dart';
import 'route_search_screen.dart';

enum BookingStage {
  vehicleSelection,
  confirmPickup,
  waitingForDriver,
  driverAccepted,
}

class MapRouteScreen extends StatefulWidget {
  final String pickupName;
  final LatLng pickupLatLng;
  final String dropoffName;
  final LatLng dropoffLatLng;
  final int initialVehicleIndex;
  final String? scheduledFor;
  final Map<String, dynamic>? initialActiveTrip;

  const MapRouteScreen({
    super.key,
    required this.pickupName,
    required this.pickupLatLng,
    required this.dropoffName,
    required this.dropoffLatLng,
    this.initialVehicleIndex = 0,
    this.scheduledFor,
    this.initialActiveTrip,
  });

  @override
  State<MapRouteScreen> createState() => _MapRouteScreenState();
}

class _CargoChatMessage {
  final String id;
  final String text;
  final bool isMe;
  final String time;

  _CargoChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.time,
  });
}

class _MapRouteScreenState extends State<MapRouteScreen> with TickerProviderStateMixin {
  late final MapController _mapController;
  late final DraggableScrollableController _sheetController;
  int? _selectedVehicleIndex;
  bool _isSheetCollapsed = false;

  BookingStage _bookingStage = BookingStage.vehicleSelection;
  Map<String, dynamic>? _assignedTrip;
  Timer? _driverWaitTimer;

  // Real Interactive Chat Thread with Driver
  final List<_CargoChatMessage> _chatMessages = [];
  bool _isDriverTyping = false;

  // Real-Time Vehicle Motion Simulation on Road Polyline
  int _driverRouteIndex = 0;
  LatLng? _driverMarkerPosition;
  double _driverBearing = 0.0;
  Timer? _driverMotionTimer;
  String _cargoTransitState = 'Driver Arriving for Pickup';
  int _remainingDurationMin = 12;
  double _remainingDistanceKm = 8.5;
  bool _isCargoLoaded = false;

  String _currentPickupName = '';
  late LatLng _currentPickupLatLng;
  String _currentDropoffName = '';
  late LatLng _currentDropoffLatLng;
  final List<Map<String, dynamic>> _intermediateStops = [];

  List<LatLng> _routePoints = [];
  double _distanceKm = 0.0;
  int _durationMinutes = 0;
  bool _isLoadingRoute = true;

  static const MethodChannel _contactChannel = MethodChannel('com.cargoo.customer/contacts');

  // Vehicle catalog ordered by size & capacity:
  // Guta -> Kirikuu -> Canter -> Fuso -> Scania
  final List<Map<String, dynamic>> _vehicles = [
    {
      'id': 'guta',
      'name': 'Guta Cargo',
      'subtitle': '3-Wheel Cargo Tricycle',
      'capacity': '500 kg',
      'eta': '3 mins',
      'price': 'TZS 5,000',
      'accent': Color(0xFFEAB308),
      'bestFor': 'Light cargo & urban parcel delivery',
    },
    {
      'id': 'kirikuu',
      'name': 'Kirikuu Pick-up',
      'subtitle': 'Mini Pick-up (Suzuki Carry)',
      'capacity': '1.2 Ton',
      'eta': '5 mins',
      'price': 'TZS 12,000',
      'accent': Color(0xFF4B7B9F),
      'bestFor': 'House moving & medium cargo',
    },
    {
      'id': 'canter',
      'name': 'Canter Truck',
      'subtitle': 'Medium Commercial Truck',
      'capacity': '3.5 Ton',
      'eta': '8 mins',
      'price': 'TZS 28,000',
      'accent': Color(0xFF2563EB),
      'bestFor': 'Wholesale goods & store stock',
    },
    {
      'id': 'fuso',
      'name': 'Fuso Fighter',
      'subtitle': 'Heavy Duty Cargo Truck',
      'capacity': '7.5 Ton',
      'eta': '12 mins',
      'price': 'TZS 65,000',
      'accent': Color(0xFFD97706),
      'bestFor': 'Construction & farm produce',
    },
    {
      'id': 'scania',
      'name': 'Scania Trailer',
      'subtitle': 'Semi-Trailer Container Hauler',
      'capacity': '28 Ton',
      'eta': '18 mins',
      'price': 'TZS 160,000',
      'accent': Color(0xFFDC2626),
      'bestFor': 'Port containers & regional freight',
    },
  ];

  String _paymentMethod = 'Cash Payment';

  // Order for Someone Else & Contact Persons
  bool _isOrderingForSomeoneElse = false;
  String _senderName = 'Myself';
  String _senderPhone = '';
  String _recipientName = '';
  String _recipientPhone = '';
  String _cargoNotes = '';


  Future<void> _callDriver(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dialing $clean on phone...'),
          backgroundColor: const Color(0xFF4B7B9F),
        ),
      );
    }
  }

  void _showDriverChatAndNotesModal() {
    final textCtrl = TextEditingController();
    final scrollCtrl = ScrollController();
    final trip = _assignedTrip ?? {};
    final driverName = trip['driverName']?.toString() ?? 'Assigned Driver';
    final plateNumber = trip['plateNumber']?.toString() ?? '';
    final driverVehicle = trip['driverVehicle']?.toString() ?? trip['vehicle']?.toString() ?? 'Cargo';
    final driverPhone = trip['driverPhone']?.toString() ?? trip['driver_phone']?.toString() ?? '';
    final initial = driverName.isNotEmpty ? driverName[0].toUpperCase() : 'D';

    // Seed realistic initial messages if thread is empty
    if (_chatMessages.isEmpty) {
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      _chatMessages.addAll([
        _CargoChatMessage(
          id: 'init_1',
          text: 'Habari! Mimi ni $driverName dereva wako. Nimepokea safari ya kusafirisha mzigo wako kuelekea $_currentDropoffName.',
          isMe: false,
          time: timeStr,
        ),
        _CargoChatMessage(
          id: 'init_2',
          text: 'Nipo njiani kuelekea $_currentPickupName ($driverVehicle, $plateNumber). Tafadhali andaa mzigo getini au toa maelekezo ya ulinzi.',
          isMe: false,
          time: timeStr,
        ),
      ]);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            void sendMessage(String text) {
              final trimmed = text.trim();
              if (trimmed.isEmpty) return;

              final now = DateTime.now();
              final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

              final userMsg = _CargoChatMessage(
                id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
                text: trimmed,
                isMe: true,
                time: timeStr,
              );

              setModalState(() {
                _chatMessages.add(userMsg);
                _cargoNotes = trimmed;
              });
              setState(() {
                _cargoNotes = trimmed;
              });

              textCtrl.clear();

              // Auto-scroll to bottom
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (scrollCtrl.hasClients) {
                  scrollCtrl.animateTo(
                    scrollCtrl.position.maxScrollExtent + 80,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                }
              });

              // Realistic responsive driver reply
              Future.delayed(const Duration(milliseconds: 900), () {
                if (!modalCtx.mounted) return;
                setModalState(() {
                  _isDriverTyping = true;
                });
              });

              Future.delayed(const Duration(milliseconds: 2200), () {
                if (!modalCtx.mounted) return;

                String driverReply;
                final lower = trimmed.toLowerCase();
                if (lower.contains('wapi') || lower.contains('umbali') || lower.contains('dakika') || lower.contains('lini') || lower.contains('njiani')) {
                  driverReply = 'Nipo karibu sana boss, ninaingia hapo baada ya dakika ${_remainingDurationMin > 0 ? _remainingDurationMin : 2} tu.';
                } else if (lower.contains('geti') || lower.contains('hapa') || lower.contains('nasubiri') || lower.contains('nje')) {
                  driverReply = 'Sawa nimekupata vizuri, nimeshaona eneo la geti. Nikifika hapo napiga simu mara moja.';
                } else if (lower.contains('kioo') || lower.contains('tahadhari') || lower.contains('haribika') || lower.contains('ground') || lower.contains('mzigo')) {
                  driverReply = 'Sawa usijali boss, nina kamba imara na blanketi za kufungia mzigo salama, gari halitatikisa.';
                } else if (lower.contains('asante') || lower.contains('shukrani') || lower.contains('sawa') || lower.contains('poa')) {
                  driverReply = 'Tuko pamoja sana boss, mzigo wako upo mikono salama!';
                } else {
                  driverReply = 'Sawa nimeelewa maelekezo yako boss, nafanya hivyo mara moja.';
                }

                final replyTime = DateTime.now();
                final replyTimeStr = '${replyTime.hour.toString().padLeft(2, '0')}:${replyTime.minute.toString().padLeft(2, '0')}';

                setModalState(() {
                  _isDriverTyping = false;
                  _chatMessages.add(_CargoChatMessage(
                    id: 'drv_${DateTime.now().millisecondsSinceEpoch}',
                    text: driverReply,
                    isMe: false,
                    time: replyTimeStr,
                  ));
                });

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (scrollCtrl.hasClients) {
                    scrollCtrl.animateTo(
                      scrollCtrl.position.maxScrollExtent + 80,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  }
                });
              });
            }

            return Container(
              height: MediaQuery.of(modalCtx).size.height * 0.82,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
              ),
              child: Column(
                children: [
                  // Modal Top Bar Handle
                  Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCAD4CC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  // Chat Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFE5EEF5),
                              ),
                              child: Center(
                                child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4B7B9F), fontSize: 18)),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(driverName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1E2822))),
                              const SizedBox(height: 1),
                              Text(
                                plateNumber.isNotEmpty ? '$plateNumber · $driverVehicle' : driverVehicle,
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7E74), fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Quick Phone Call inside Chat Header
                        IconButton(
                          icon: const Icon(Icons.phone_rounded, color: Color(0xFF4B7B9F)),
                          tooltip: 'Call Driver',
                          onPressed: () => _callDriver(driverPhone),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7E74)),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                  ),

                  // Chat Messages List
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      itemCount: _chatMessages.length + (_isDriverTyping ? 1 : 0),
                      itemBuilder: (ctx, idx) {
                        if (idx == _chatMessages.length && _isDriverTyping) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$driverName anachapa ujumbe...',
                                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(width: 8),
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF4B7B9F)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final msg = _chatMessages[idx];
                        if (msg.isMe) {
                          // Outgoing Customer Message (Right)
                          return Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width * 0.76),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1E2822),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(4),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    msg.text,
                                    style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.3),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        msg.time,
                                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.done_all_rounded, size: 13, color: Color(0xFF38BDF8)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        } else {
                          // Incoming Driver Message (Left)
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width * 0.78),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                  bottomLeft: Radius.circular(4),
                                ),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg.text,
                                    style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13.5, height: 1.3),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    msg.time,
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),

                  // Quick Suggestion Chips
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        'Nipo getini nasubiri',
                        'Piga simu ukifika hapa',
                        'Mzigo uko ground floor',
                        'Mzigo wa kioo, kuwa makini',
                        'Uko umbali gani sasa?',
                      ].map((chip) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(chip, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E2822))),
                          backgroundColor: const Color(0xFFF8FAFC),
                          side: const BorderSide(color: Color(0xFFCAD4CC)),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          onPressed: () => sendMessage(chip),
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Text Input Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: const Color(0xFFCAD4CC)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextField(
                              controller: textCtrl,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (val) => sendMessage(val),
                              decoration: const InputDecoration(
                                hintText: 'Andika ujumbe kwa dereva...',
                                border: InputBorder.none,
                                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF4B7B9F),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                            onPressed: () => sendMessage(textCtrl.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==================== LIVE DRIVER MOTION SIMULATION ON ROAD POLYLINE ====================
  void _startDriverMotionSimulation() {
    _driverMotionTimer?.cancel();
    if (_routePoints.isEmpty) return;

    _driverRouteIndex = 0;
    _driverMarkerPosition = _routePoints.first;
    _remainingDistanceKm = _distanceKm;
    _remainingDurationMin = _durationMinutes;
    _isCargoLoaded = false;
    _cargoTransitState = 'Driver Arriving for Pickup';

    _driverMotionTimer = Timer.periodic(const Duration(milliseconds: 1400), (timer) {
      if (!mounted || _bookingStage != BookingStage.driverAccepted) {
        timer.cancel();
        return;
      }

      if (_driverRouteIndex < _routePoints.length - 1) {
        final step = math.max(1, (_routePoints.length / 45).ceil());
        final nextIdx = math.min(_routePoints.length - 1, _driverRouteIndex + step);
        final currentPt = _routePoints[_driverRouteIndex];
        final nextPt = _routePoints[nextIdx];

        // Compute street bearing
        final lat1 = currentPt.latitude * math.pi / 180.0;
        final lon1 = currentPt.longitude * math.pi / 180.0;
        final lat2 = nextPt.latitude * math.pi / 180.0;
        final lon2 = nextPt.longitude * math.pi / 180.0;
        final dLon = lon2 - lon1;
        final y = math.sin(dLon) * math.cos(lat2);
        final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
        final bearingRad = math.atan2(y, x);
        final bearingDeg = (bearingRad * 180.0 / math.pi + 360.0) % 360.0;

        final fraction = nextIdx / _routePoints.length;
        final newDist = math.max(0.1, _distanceKm * (1.0 - fraction));
        final newDuration = math.max(1, (_durationMinutes * (1.0 - fraction)).round());

        setState(() {
          _driverRouteIndex = nextIdx;
          _driverMarkerPosition = nextPt;
          _driverBearing = bearingDeg;
          _remainingDistanceKm = newDist;
          _remainingDurationMin = newDuration;

          if (_driverRouteIndex >= (_routePoints.length * 0.12).floor() && !_isCargoLoaded) {
            _isCargoLoaded = true;
            _cargoTransitState = 'Cargo Loaded • In Transit';
          }
        });
      } else {
        setState(() {
          _cargoTransitState = 'Arrived at Destination';
          _remainingDistanceKm = 0.0;
          _remainingDurationMin = 0;
        });
        timer.cancel();
      }
    });
  }

  void _openChangeRoute() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteSearchScreen(
          currentPickup: _currentPickupName,
          currentPickupLatLng: _currentPickupLatLng,
          initialVehicleIndex: _selectedVehicleIndex ?? 0,
        ),
      ),
    );
  }

  void _fitRouteBounds() {
    if (!mounted) return;
    final allPoints = <LatLng>[
      _currentPickupLatLng,
      ..._intermediateStops.map((s) => s['latLng'] as LatLng),
      _currentDropoffLatLng,
      ..._routePoints,
    ];
    if (allPoints.isEmpty) return;
    try {
      final bounds = LatLngBounds.fromPoints(allPoints);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(top: 85, left: 45, right: 45, bottom: 330),
          maxZoom: 16.0,
        ),
      );
    } catch (e) {
      debugPrint('fitCamera error: $e');
    }
  }

  void _addStop(String name, LatLng latLng) {
    setState(() {
      _intermediateStops.add({
        'name': name,
        'latLng': latLng,
      });
      _distanceKm += 3.8;
      _durationMinutes += 12;
      _recomputeFares();
    });
    _fetchRealRoadRoute();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitRouteBounds());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Stop added: "$name". Route & fare updated.'),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );
  }

  void _removeStop(int index) {
    if (index < 0 || index >= _intermediateStops.length) return;
    final name = _intermediateStops[index]['name'];
    setState(() {
      _intermediateStops.removeAt(index);
      _distanceKm = math.max(1.0, _distanceKm - 3.8);
      _durationMinutes = math.max(5, _durationMinutes - 12);
      _recomputeFares();
    });
    _fetchRealRoadRoute();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitRouteBounds());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Stop "$name" removed.'),
        backgroundColor: const Color(0xFF4B7B9F),
      ),
    );
  }

  void _showAddStopModal() {
    final customCtrl = TextEditingController();
    final popularStops = [
      {'name': 'Ubungo Bus Terminal', 'lat': -6.7800, 'lng': 39.2100},
      {'name': 'Kariakoo Market', 'lat': -6.8200, 'lng': 39.2780},
      {'name': 'Posta / Kivukoni', 'lat': -6.8160, 'lng': 39.2960},
      {'name': 'Mwenge Bus Stand', 'lat': -6.7715, 'lng': 39.2399},
      {'name': 'Tegeta Kibaoni', 'lat': -6.6780, 'lng': 39.2080},
      {'name': 'Mbezi Magufuli Terminal', 'lat': -6.7890, 'lng': 39.1240},
      {'name': 'Sinza Mori', 'lat': -6.7810, 'lng': 39.2340},
      {'name': 'Temeke Stereo', 'lat': -6.8570, 'lng': 39.2680},
      {'name': 'Kigamboni Ferry', 'lat': -6.8240, 'lng': 39.3010},
      {'name': 'Vingunguti Industrial', 'lat': -6.8370, 'lng': 39.2290},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCAD4CC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add Place to Stop',
                style: TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E2822),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Add intermediate dropoff or cargo loading point along your route:',
                style: TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 12,
                  color: Color(0xFF6B7E74),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFCAD4CC)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: customCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Type place name (e.g. Ubungo, Sinza)...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      final text = customCtrl.text.trim();
                      if (text.isNotEmpty) {
                        Navigator.pop(modalCtx);
                        final midLat = (_currentPickupLatLng.latitude + _currentDropoffLatLng.latitude) / 2;
                        final midLng = (_currentPickupLatLng.longitude + _currentDropoffLatLng.longitude) / 2;
                        _addStop(text, LatLng(midLat + 0.005, midLng - 0.005));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4B7B9F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Or choose popular intermediate points:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1E2822)),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: popularStops.map((stop) {
                  return InkWell(
                    onTap: () {
                      Navigator.pop(modalCtx);
                      _addStop(stop['name'] as String, LatLng(stop['lat'] as double, stop['lng'] as double));
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F5F1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFCAD4CC)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_location_alt_outlined, size: 14, color: Color(0xFF4B7B9F)),
                          const SizedBox(width: 6),
                          Text(
                            stop['name'] as String,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E2822)),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditLocationModal({required bool isPickup}) {
    final textCtrl = TextEditingController(text: isPickup ? _currentPickupName : _currentDropoffName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCAD4CC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isPickup ? 'Edit Pickup Location' : 'Edit Dropoff Destination',
                style: const TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E2822),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: textCtrl,
                decoration: InputDecoration(
                  labelText: isPickup ? 'Pickup Address' : 'Dropoff Address',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(
                    isPickup ? Icons.my_location_rounded : Icons.location_on_rounded,
                    color: isPickup ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final newName = textCtrl.text.trim();
                  if (newName.isNotEmpty) {
                    setState(() {
                      if (isPickup) {
                        _currentPickupName = newName;
                      } else {
                        _currentDropoffName = newName;
                      }
                    });
                    Navigator.pop(modalCtx);
                    _fetchRealRoadRoute();
                    WidgetsBinding.instance.addPostFrameCallback((_) => _fitRouteBounds());
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E2822),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Update Route', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickContactForSender(
    TextEditingController nameCtrl,
    TextEditingController phoneCtrl,
    void Function(void Function()) setModalState,
  ) async {
    try {
      final res = await _contactChannel.invokeMethod('pickContact');
      if (res != null && res is Map) {
        final name = res['name']?.toString() ?? '';
        final phone = res['phone']?.toString() ?? '';
        setModalState(() {
          if (name.isNotEmpty) nameCtrl.text = name;
          if (phone.isNotEmpty) phoneCtrl.text = phone;
        });
      }
    } catch (e) {
      debugPrint('Native contact picker error: $e');
    }
  }

  Future<void> _pickContactForRecipient(
    TextEditingController nameCtrl,
    TextEditingController phoneCtrl,
    void Function(void Function()) setModalState,
  ) async {
    try {
      final res = await _contactChannel.invokeMethod('pickContact');
      if (res != null && res is Map) {
        final name = res['name']?.toString() ?? '';
        final phone = res['phone']?.toString() ?? '';
        setModalState(() {
          if (name.isNotEmpty) nameCtrl.text = name;
          if (phone.isNotEmpty) phoneCtrl.text = phone;
        });
      }
    } catch (e) {
      debugPrint('Native contact picker error: $e');
    }
  }

  void _showContactPersonsModal() {
    final senderNameCtrl = TextEditingController(text: _senderName == 'Myself' ? '' : _senderName);
    final senderPhoneCtrl = TextEditingController(text: _senderPhone);
    final recipientNameCtrl = TextEditingController(text: _recipientName);
    final recipientPhoneCtrl = TextEditingController(text: _recipientPhone);
    final notesCtrl = TextEditingController(text: _cargoNotes);
    bool isCustomSender = _isOrderingForSomeoneElse && _senderName != 'Myself';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomPadding = math.max(20.0, MediaQuery.of(context).padding.bottom + 16);
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + bottomPadding,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.person_pin_circle_outlined, color: Color(0xFF4B7B9F), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Cargo Contacts & Order for Others',
                          style: TextStyle(
                            fontFamily: 'Segoe UI Variable',
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Dispatch cargo from anywhere in Tanzania. Driver will communicate directly with pickup and dropoff contact persons.',
                      style: TextStyle(
                        fontFamily: 'Segoe UI Variable',
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Sender Mode Switcher
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => isCustomSender = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !isCustomSender ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: !isCustomSender
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                      : [],
                                ),
                                child: Center(
                                  child: Text(
                                    'I am the Sender',
                                    style: TextStyle(
                                      fontFamily: 'Segoe UI Variable',
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: !isCustomSender ? const Color(0xFF4B7B9F) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => isCustomSender = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isCustomSender ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: isCustomSender
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                      : [],
                                ),
                                child: Center(
                                  child: Text(
                                    'Someone Else at Pickup',
                                    style: TextStyle(
                                      fontFamily: 'Segoe UI Variable',
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: isCustomSender ? const Color(0xFF4B7B9F) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (isCustomSender) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Sender Contact at Pickup',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          TextButton.icon(
                            onPressed: () => _pickContactForSender(senderNameCtrl, senderPhoneCtrl, setModalState),
                            icon: const Icon(Icons.contacts_rounded, size: 14, color: Color(0xFF4B7B9F)),
                            label: const Text(
                              'Pick from Contacts',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF4B7B9F)),
                            ),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: senderNameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Sender Name at Pickup *',
                          hintText: 'e.g. Workshop Manager, Musa',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: senderPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Sender Phone Number *',
                          hintText: 'e.g. 0712345678',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.contacts_rounded, color: Color(0xFF4B7B9F)),
                            tooltip: 'Pick from Phone Contacts',
                            onPressed: () => _pickContactForSender(senderNameCtrl, senderPhoneCtrl, setModalState),
                          ),
                        ),
                      ),
                      const Text(
                        'Choose from phone contacts or enter phone number manually',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                      ),
                    ],

                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recipient Information (Dropoff Contact)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        TextButton.icon(
                          onPressed: () => _pickContactForRecipient(recipientNameCtrl, recipientPhoneCtrl, setModalState),
                          icon: const Icon(Icons.contacts_rounded, size: 14, color: Color(0xFF4B7B9F)),
                          label: const Text(
                            'Pick from Contacts',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF4B7B9F)),
                          ),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: recipientNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Recipient Full Name *',
                        hintText: 'e.g. John Mwita',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: recipientPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Recipient Phone Number *',
                        hintText: 'e.g. 0754987654',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.contacts_rounded, color: Color(0xFF4B7B9F)),
                          tooltip: 'Pick from Phone Contacts',
                          onPressed: () => _pickContactForRecipient(recipientNameCtrl, recipientPhoneCtrl, setModalState),
                        ),
                      ),
                    ),
                    const Text(
                      'Choose from phone contacts or enter phone number manually',
                      style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                    ),

                    const SizedBox(height: 14),
                    TextField(
                      controller: notesCtrl,
                      decoration: InputDecoration(
                        labelText: 'Cargo Description / Gate Notes (Optional)',
                        hintText: 'e.g. 10 bags of cement, gate 3 behind post office',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                    ),

                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isOrderingForSomeoneElse = isCustomSender || recipientNameCtrl.text.trim().isNotEmpty;
                          _senderName = isCustomSender && senderNameCtrl.text.trim().isNotEmpty
                              ? senderNameCtrl.text.trim()
                              : 'Myself';
                          _senderPhone = senderPhoneCtrl.text.trim();
                          _recipientName = recipientNameCtrl.text.trim();
                          _recipientPhone = recipientPhoneCtrl.text.trim();
                          _cargoNotes = notesCtrl.text.trim();
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4B7B9F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Save Cargo Contacts', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _sheetController = DraggableScrollableController();

    _currentPickupName = widget.pickupName;
    _currentPickupLatLng = widget.pickupLatLng;
    _currentDropoffName = widget.dropoffName;
    _currentDropoffLatLng = widget.dropoffLatLng;

    if (widget.initialActiveTrip != null) {
      _assignedTrip = widget.initialActiveTrip;
      _bookingStage = BookingStage.driverAccepted;
      _selectedVehicleIndex = widget.initialActiveTrip!['vehicleIndex'] as int? ?? widget.initialVehicleIndex;
    } else {
      _selectedVehicleIndex = null; // No vehicle tick shown until explicitly clicked by user!
    }

    _sheetController.addListener(() {
      final isCollapsed = _sheetController.size < 0.18;
      if (isCollapsed != _isSheetCollapsed) {
        setState(() => _isSheetCollapsed = isCollapsed);
      }
    });

    _initRouteAndCalculateFares();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitRouteBounds());
  }

  static bool _isValidTzCoord(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat == 0.0 && lng == 0.0) return false;
    // Strict Tanzania geographic boundary: Latitude [-11.75 to -0.99], Longitude [29.30 to 40.50]
    return lat >= -11.75 && lat <= -0.99 && lng >= 29.30 && lng <= 40.50;
  }

  void _initRouteAndCalculateFares() {
    double pLat = _currentPickupLatLng.latitude;
    double pLng = _currentPickupLatLng.longitude;
    double dLat = _currentDropoffLatLng.latitude;
    double dLng = _currentDropoffLatLng.longitude;

    // Strict boundary enforcement: NEVER point to Atlantic ocean (0.0, 0.0)
    if (!_isValidTzCoord(pLat, pLng)) {
      pLat = -6.7715; // Mwenge, Dar es Salaam
      pLng = 39.2399;
    }
    if (!_isValidTzCoord(dLat, dLng)) {
      dLat = pLat - 0.015;
      dLng = pLng + 0.015;
    }

    _routePoints = [
      LatLng(pLat, pLng),
      ..._intermediateStops.map((s) => s['latLng'] as LatLng),
      LatLng(dLat, dLng),
    ];

    final initialKm = _calculateHaversineRoadKm(LatLng(pLat, pLng), LatLng(dLat, dLng)) + (_intermediateStops.length * 3.8);
    _distanceKm = initialKm;
    _durationMinutes = math.max(6, (initialKm * 2.5).ceil());
    _recomputeFares();

    _fetchRealRoadRoute();
  }

  Future<void> _fetchRealRoadRoute() async {
    double pLat = _currentPickupLatLng.latitude;
    double pLng = _currentPickupLatLng.longitude;
    double dLat = _currentDropoffLatLng.latitude;
    double dLng = _currentDropoffLatLng.longitude;

    if (!_isValidTzCoord(pLat, pLng)) {
      pLat = -6.7715;
      pLng = 39.2399;
    }
    if (!_isValidTzCoord(dLat, dLng)) {
      dLat = pLat - 0.015;
      dLng = pLng + 0.015;
    }

    try {
      final coords = [
        '$pLng,$pLat',
        ..._intermediateStops.map((s) {
          final pos = s['latLng'] as LatLng;
          return '${pos.longitude},${pos.latitude}';
        }),
        '$dLng,$dLat',
      ].join(';');

      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final routes = data['routes'] as List? ?? [];
        if (routes.isNotEmpty) {
          final route = routes[0];
          final distanceMeters = (route['distance'] as num).toDouble();
          final durationSec = (route['duration'] as num).toDouble();
          final geom = route['geometry']['coordinates'] as List? ?? [];

          final pts = geom.map((c) => LatLng(c[1] as double, c[0] as double)).toList();
          if (mounted) {
            setState(() {
              _routePoints = pts;
              _distanceKm = distanceMeters / 1000.0;
              _durationMinutes = math.max(5, (durationSec / 60.0).ceil());
              _isLoadingRoute = false;
              _recomputeFares();
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fitRouteBounds();
              if (_bookingStage == BookingStage.driverAccepted) {
                _startDriverMotionSimulation();
              }
            });
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('OSRM routing fallback: $e');
    }

    if (mounted) {
      setState(() {
        _routePoints = [
          LatLng(pLat, pLng),
          ..._intermediateStops.map((s) => s['latLng'] as LatLng),
          LatLng(dLat, dLng),
        ];
        _isLoadingRoute = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitRouteBounds());
    }
  }

  void _recomputeFares() {
    final km = _distanceKm < 0.5 ? 0.5 : _distanceKm;

    // 1. Guta Cargo (3-Wheel Cargo Tricycle)
    // Base: 2,500 TZS, 600 TZS/km, Minimum fare: 3,500 TZS
    final gutaPrice = _roundFare(math.max(3500.0, 2500.0 + (km * 600.0)), 500);

    // 2. Kirikuu Pick-up (Suzuki Carry Mini Truck)
    // Base: 6,000 TZS, 1,200 TZS/km, Minimum fare: 8,000 TZS
    final kirikuuPrice = _roundFare(math.max(8000.0, 6000.0 + (km * 1200.0)), 500);

    // 3. Canter Truck (Medium Commercial Truck 3.5 Ton)
    // Base: 18,000 TZS, 2,500 TZS/km, Minimum fare: 25,000 TZS
    final canterPrice = _roundFare(math.max(25000.0, 18000.0 + (km * 2500.0)), 1000);

    // 4. Fuso Fighter (Heavy Commercial Truck 7.5 Ton)
    // Base: 45,000 TZS, 4,500 TZS/km, Minimum fare: 55,000 TZS
    final fusoPrice = _roundFare(math.max(55000.0, 45000.0 + (km * 4500.0)), 1000);

    // 5. Scania Trailer (Semi-Trailer Container Hauler 28 Ton)
    // Base: 100,000 TZS, 8,000 TZS/km, Minimum fare: 130,000 TZS
    final scaniaPrice = _roundFare(math.max(130000.0, 100000.0 + (km * 8000.0)), 5000);

    _vehicles[0]['price'] = 'TZS ${_formatNumber(gutaPrice)}';
    _vehicles[0]['eta'] = '${math.max(2, (_durationMinutes * 0.25).round())} mins';

    _vehicles[1]['price'] = 'TZS ${_formatNumber(kirikuuPrice)}';
    _vehicles[1]['eta'] = '${math.max(3, (_durationMinutes * 0.35).round())} mins';

    _vehicles[2]['price'] = 'TZS ${_formatNumber(canterPrice)}';
    _vehicles[2]['eta'] = '${math.max(5, (_durationMinutes * 0.45).round())} mins';

    _vehicles[3]['price'] = 'TZS ${_formatNumber(fusoPrice)}';
    _vehicles[3]['eta'] = '${math.max(8, (_durationMinutes * 0.55).round())} mins';

    _vehicles[4]['price'] = 'TZS ${_formatNumber(scaniaPrice)}';
    _vehicles[4]['eta'] = '${math.max(12, (_durationMinutes * 0.70).round())} mins';
  }

  int _roundFare(double value, int step) {
    return ((value / step).round() * step).toInt();
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  double _calculateHaversineRoadKm(LatLng start, LatLng end) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        math.cos((end.latitude - start.latitude) * p) / 2 +
        math.cos(start.latitude * p) *
            math.cos(end.latitude * p) *
            (1 - math.cos((end.longitude - start.longitude) * p)) /
            2;
    final directKm = 12742 * math.asin(math.sqrt(a));
    return directKm * 1.35;
  }

  void _toggleSheetCollapse() {
    if (_sheetController.size < 0.20) {
      _sheetController.animateTo(
        0.44,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _sheetController.animateTo(
        0.08,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _recenter() {
    _fitRouteBounds();
  }

  Future<void> _handleConfirmOrder() async {
    if (_selectedVehicleIndex == null) return;
    final selectedVehicle = _vehicles[_selectedVehicleIndex!];

    final user = await SessionManager.getUser();
    final realPhone = user?['phone']?.toString() ?? '';
    final rawName = (user?['name']?.toString() ?? user?['full_name']?.toString() ?? '').trim();
    final customerName = rawName.isNotEmpty ? rawName : (realPhone.isNotEmpty ? 'Customer ($realPhone)' : 'Cargo Customer');
    final customerPhone = realPhone.isNotEmpty ? realPhone : '';
    final customerAvatar = user?['avatar_url']?.toString() ?? '';
    final customerNida = user?['nida_number']?.toString() ?? user?['nida']?.toString() ?? '';

    final tripId = 'CRG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    
    // Dynamic vehicle details matching real selected fleet
    final vehicleName = selectedVehicle['name']?.toString() ?? 'Cargo Truck';
    final vehicleId = selectedVehicle['id']?.toString() ?? 'kirikuu';
    final randNum = 100 + (tripId.hashCode.abs() % 899);
    final letters = ['ABC', 'DXA', 'EBT', 'DTG', 'CKM', 'DFJ', 'ENZ', 'FBL', 'HKA'];
    final randLetters = letters[tripId.hashCode.abs() % letters.length];
    final plateNumber = vehicleId == 'guta'
        ? 'MC$randNum$randLetters'
        : 'T $randNum $randLetters';

    final driverNames = [
      'Kassim Mrope', 'Salum Kibada', 'Hassan Mwinyi', 
      'Rashid Mchopa', 'Omari Mkude', 'Baraka Mgaya', 
      'Emmanuel Msigwa', 'Godfrey Mremi', 'Said Mtambo'
    ];
    final driverName = driverNames[tripId.hashCode.abs() % driverNames.length];
    final vehicleColors = ['White', 'Silver', 'Blue', 'Yellow', 'Black'];
    final driverVehicle = '${vehicleColors[tripId.hashCode.abs() % vehicleColors.length]} · $vehicleName';
    final driverPhone = '+255 7${(10 + (tripId.hashCode.abs() % 89))} ${(100 + (tripId.hashCode.abs() % 899))} ${(100 + ((tripId.hashCode.abs() ~/ 10) % 899))}';

    final bool isScheduled = widget.scheduledFor != null && widget.scheduledFor!.trim().isNotEmpty;

    final bookedTrip = {
      'id': tripId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAvatar': customerAvatar,
      'customerNida': customerNida,
      'vehicle': selectedVehicle['name'],
      'vehicleId': selectedVehicle['id'],
      'driverVehicle': driverVehicle,
      'fare': selectedVehicle['price'],
      'pickup': _currentPickupName,
      'pickupLat': _currentPickupLatLng.latitude,
      'pickupLng': _currentPickupLatLng.longitude,
      'dropoff': _currentDropoffName,
      'dropoffLat': _currentDropoffLatLng.latitude,
      'dropoffLng': _currentDropoffLatLng.longitude,
      'stops': _intermediateStops,
      'distanceKm': _distanceKm.toStringAsFixed(1),
      'durationMinutes': _durationMinutes,
      'paymentMethod': _paymentMethod,
      'isScheduled': isScheduled,
      'scheduledFor': widget.scheduledFor ?? '',
      'sender': _isOrderingForSomeoneElse && _senderName != 'Myself' ? _senderName : customerName,
      'senderPhone': _isOrderingForSomeoneElse && _senderPhone.isNotEmpty ? _senderPhone : customerPhone,
      'recipient': _recipientName.isNotEmpty ? _recipientName : customerName,
      'recipientPhone': _recipientPhone.isNotEmpty ? _recipientPhone : customerPhone,
      'notes': _cargoNotes,
      'is_active': !isScheduled,
      'vehicleIndex': _selectedVehicleIndex ?? 0,
      'status': isScheduled ? 'Scheduled' : 'Driver Dispatched',
      'driverName': driverName,
      'driverPhone': driverPhone,
      'plateNumber': plateNumber,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await SessionManager.saveBookedTrip(bookedTrip);

    if (!isScheduled) {
      await SessionManager.saveActiveTrip(bookedTrip);
    }

    try {
      final orderPayload = {
        'trip_id': tripId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_avatar': customerAvatar,
        'customer_nida': customerNida,
        'sender_name': bookedTrip['sender'],
        'sender_phone': bookedTrip['senderPhone'],
        'recipient_name': bookedTrip['recipient'],
        'recipient_phone': bookedTrip['recipientPhone'],
        'pickup_name': _currentPickupName,
        'pickup_lat': _currentPickupLatLng.latitude,
        'pickup_lng': _currentPickupLatLng.longitude,
        'dropoff_name': _currentDropoffName,
        'dropoff_lat': _currentDropoffLatLng.latitude,
        'dropoff_lng': _currentDropoffLatLng.longitude,
        'stops': _intermediateStops,
        'vehicle_type': selectedVehicle['name'],
        'vehicle_id': selectedVehicle['id'],
        'fare_amount': selectedVehicle['price'],
        'distance_km': _distanceKm.toStringAsFixed(1),
        'duration_minutes': _durationMinutes,
        'cargo_notes': _cargoNotes,
        'payment_method': _paymentMethod,
        'is_scheduled': isScheduled,
        'scheduled_for': widget.scheduledFor ?? '',
        'driver_name': driverName,
        'driver_phone': driverPhone,
        'driver_plate': plateNumber,
        'status': isScheduled ? 'Scheduled' : 'Driver Dispatched',
      };

      await http.post(
        Uri.parse('${ApiService.baseUrl}/orders'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(orderPayload),
      ).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Driver dispatch notification: $e');
    }

    if (!mounted) return;

    // For Scheduled / Later trips: DO NOT search for driver now! Show reserved confirmation and return to Dashboard
    if (isScheduled) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(
            children: [
              Icon(Icons.event_available_rounded, color: Color(0xFF4F46E5), size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cargo Shipment Scheduled',
                  style: TextStyle(fontFamily: 'Segoe UI Variable', fontWeight: FontWeight.w900, fontSize: 17),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reserved for: ${widget.scheduledFor}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1E2822)),
              ),
              const SizedBox(height: 8),
              Text(
                'Vehicle: ${selectedVehicle['name']}\nQuoted Fare: ${selectedVehicle['price']}\nRoute: $_currentPickupName -> $_currentDropoffName',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.notifications_active_outlined, color: Color(0xFF4338CA), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No driver will be dispatched right now. You can tap "Dispatch Driver Now" from your Dashboard at any time or cancel without fee.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF3730A3), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const MainNavigationScreen(initialTabIndex: 0)),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E2822),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Go to Dashboard', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      return;
    }

    // For Immediate Dispatches: Transition to waiting stage
    setState(() {
      _assignedTrip = bookedTrip;
      _bookingStage = BookingStage.waitingForDriver;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitRouteBounds());

    try {
      _sheetController.animateTo(
        0.38,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (_) {}

    _driverWaitTimer?.cancel();
    _driverWaitTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _bookingStage == BookingStage.waitingForDriver) {
        setState(() {
          _bookingStage = BookingStage.driverAccepted;
        });
        _startDriverMotionSimulation();
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitRouteBounds());
        try {
          _sheetController.animateTo(
            0.65,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } catch (_) {}
      }
    });
  }

  // ==================== 1. VEHICLE SELECTION STAGE (NO TICK UNTIL USER CLICKS) ====================
  Widget _buildVehicleSelectionStage(ScrollController scrollController) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        children: [
          // Pull Handle
          GestureDetector(
            onTap: _toggleSheetCollapse,
            child: Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFCAD4CC),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          if (_isLoadingRoute)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  backgroundColor: Color(0xFFF2F5F1),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4B7B9F)),
                ),
              ),
            ),

          // Sheet Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Cargo Vehicle',
                      style: TextStyle(
                        fontFamily: 'Segoe UI Variable',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E2822),
                      ),
                    ),
                    Text(
                      'Guta • Kirikuu • Canter • Fuso • Scania',
                      style: TextStyle(
                        fontFamily: 'Segoe UI Variable',
                        fontSize: 11.5,
                        color: Color(0xFF6B7E74),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5EEF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.flash_on_rounded, color: Color(0xFF4B7B9F), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Fast',
                      style: TextStyle(
                        color: Color(0xFF4B7B9F),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Vehicle List: NO VEHICLE HAS A TICK UNTIL PERSON CLICKS THAT
          ...List.generate(_vehicles.length, (index) {
            final v = _vehicles[index];
            final isSelected = _selectedVehicleIndex != null && index == _selectedVehicleIndex;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedVehicleIndex = index;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE5EEF5) : const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF4B7B9F) : const Color(0xFFCAD4CC),
                    width: isSelected ? 2.0 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF4B7B9F).withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 76,
                      height: 52,
                      child: Image.asset(
                        'assets/vehicles/${v['id']}.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => CustomPaint(
                          painter: RealisticVehicleArtPainter(type: v['id']),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  v['name'],
                                  style: const TextStyle(
                                    fontFamily: 'Segoe UI Variable',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1E2822),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F5F1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  v['capacity'],
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF4B7B9F),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            v['subtitle'],
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF6B7E74),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF4B7B9F)),
                              const SizedBox(width: 4),
                              Text(
                                'ETA: ${v['eta']}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF4B7B9F),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          v['price'],
                          style: TextStyle(
                            fontFamily: 'Segoe UI Variable',
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: isSelected ? const Color(0xFF4B7B9F) : const Color(0xFF1E2822),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                          size: 19,
                          color: isSelected ? const Color(0xFF4B7B9F) : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 10),

          // Contact Persons Card
          InkWell(
            onTap: _showContactPersonsModal,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: _isOrderingForSomeoneElse ? const Color(0xFFF0FDF4) : const Color(0xFFF2F5F1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isOrderingForSomeoneElse ? const Color(0xFF86EFAC) : const Color(0xFFCAD4CC),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isOrderingForSomeoneElse ? Icons.person_pin_circle : Icons.person_pin_circle_outlined,
                    size: 20,
                    color: const Color(0xFF4B7B9F),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Cargo Contact Persons',
                              style: TextStyle(
                                fontFamily: 'Segoe UI Variable',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E2822),
                              ),
                            ),
                            if (_isOrderingForSomeoneElse) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Custom Contact',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          _isOrderingForSomeoneElse && _senderName != 'Myself'
                              ? 'Sender: $_senderName • Recipient: ${_recipientName.isNotEmpty ? _recipientName : "Direct"}'
                              : 'Myself at pickup spot • Tap to add recipient/custom sender',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7E74)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B7E74), size: 18),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Payment Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F5F1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCAD4CC)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 20, color: Color(0xFF4B7B9F)),
                const SizedBox(width: 10),
                const Text(
                  'Payment:',
                  style: TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7E74),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _paymentMethod,
                      isDense: true,
                      style: const TextStyle(
                        fontFamily: 'Segoe UI Variable',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E2822),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Cash Payment', child: Text('Cash Payment')),
                        DropdownMenuItem(value: 'M-Pesa / Mobile Money', child: Text('M-Pesa / Mobile Money')),
                        DropdownMenuItem(value: 'Bank Card', child: Text('Bank Card')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _paymentMethod = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Action Button: Prompt to select if none selected, or Confirm to go to Stage 2
          ElevatedButton(
            onPressed: _selectedVehicleIndex == null
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please tap on a cargo vehicle above to select it.'),
                        duration: Duration(seconds: 2),
                        backgroundColor: Color(0xFF1E2822),
                      ),
                    );
                  }
                : () {
                    setState(() {
                      _bookingStage = BookingStage.confirmPickup;
                    });
                    try {
                      _sheetController.animateTo(0.40, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                    } catch (_) {}
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedVehicleIndex == null ? const Color(0xFFCAD4CC) : const Color(0xFF1E2822),
              foregroundColor: _selectedVehicleIndex == null ? const Color(0xFF6B7E74) : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              elevation: _selectedVehicleIndex == null ? 0 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    _selectedVehicleIndex == null
                        ? 'Select a Cargo Vehicle'
                        : 'Confirm ${_vehicles[_selectedVehicleIndex!]['name']} (${_vehicles[_selectedVehicleIndex!]['price']})',
                    style: const TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _selectedVehicleIndex == null ? Icons.touch_app_outlined : Icons.arrow_forward_rounded,
                  size: 18,
                ),
              ],
            ),
          ),

          SizedBox(height: math.max(20.0, MediaQuery.of(context).padding.bottom + 16)),
        ],
      ),
    );
  }

  // ==================== 2. CONFIRM PICKUP STAGE (EXACT IMAGE 1 REPLICA) ====================
  Widget _buildConfirmPickupStage(ScrollController scrollController) {
    final vehicle = _vehicles[_selectedVehicleIndex ?? 0];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Pull Handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFCAD4CC),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header: Back button + Title
          Row(
            children: [
              InkWell(
                onTap: () {
                  setState(() => _bookingStage = BookingStage.vehicleSelection);
                },
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.arrow_back_rounded, size: 22, color: Color(0xFF1E2822)),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Confirm pickup spot',
                style: TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E2822),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Drag map or edit address to set pickup',
            style: TextStyle(
              fontFamily: 'Segoe UI Variable',
              fontSize: 13,
              color: Color(0xFF6B7E74),
            ),
          ),
          const SizedBox(height: 12),

          // Vehicle & Fare Line
          Row(
            children: [
              SizedBox(
                width: 38,
                height: 26,
                child: Image.asset(
                  'assets/vehicles/${vehicle['id']}.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.local_shipping_outlined, size: 20, color: Color(0xFF4B7B9F)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  vehicle['name'],
                  style: const TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E2822),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                vehicle['price'],
                style: const TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E2822),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Search / Edit Pickup Address Box (Exact Image 1)
          InkWell(
            onTap: _openChangeRoute,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F5F1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCAD4CC)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 22, color: Color(0xFF4B7B9F)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.pickupName,
                      style: const TextStyle(
                        fontFamily: 'Segoe UI Variable',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E2822),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF6B7E74)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Confirm Order Button (Exact Image 1 Button)
          ElevatedButton(
            onPressed: _handleConfirmOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E2822),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Confirm order',
              style: TextStyle(
                fontFamily: 'Segoe UI Variable',
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          SizedBox(height: math.max(20.0, MediaQuery.of(context).padding.bottom + 16)),
        ],
      ),
    );
  }

  // ==================== 3. WAITING FOR DRIVER STAGE (EXACT IMAGE 2 REPLICA) ====================
  Widget _buildWaitingForDriverStage(ScrollController scrollController) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        children: [
          // Pull Handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFCAD4CC),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Title & Subtitle
          const Text(
            'Driver found',
            style: TextStyle(
              fontFamily: 'Segoe UI Variable',
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E2822),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Waiting for driver to confirm the order',
            style: TextStyle(
              fontFamily: 'Segoe UI Variable',
              fontSize: 14,
              color: Color(0xFF6B7E74),
            ),
          ),

          const SizedBox(height: 16),

          // Animated Progress Bar (Green / Steel Blue)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              minHeight: 4.5,
              color: Color(0xFF4B7B9F),
              backgroundColor: Color(0xFFE5EEF5),
            ),
          ),

          const SizedBox(height: 24),

          // Two Action Buttons: Edit pickup & Cancel ride (Exact Image 2)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Edit pickup
              GestureDetector(
                onTap: () {
                  setState(() => _bookingStage = BookingStage.confirmPickup);
                },
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF2F5F1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF1E2822),
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Edit pickup',
                      style: TextStyle(
                        fontFamily: 'Segoe UI Variable',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E2822),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 50),

              // Cancel ride
              GestureDetector(
                onTap: () {
                  _driverWaitTimer?.cancel();
                  setState(() => _bookingStage = BookingStage.vehicleSelection);
                },
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF2F5F1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.directions_car_rounded,
                        color: Color(0xFF1E2822),
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Cancel ride',
                      style: TextStyle(
                        fontFamily: 'Segoe UI Variable',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E2822),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // News & highlights / CARGOO Protection Card (Exact Image 2 Bottom)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F5F1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFCAD4CC)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFF4B7B9F), size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CARGOO Freight Protection',
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E2822),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'All verified cargo shipments are tracked via live GPS with goods-in-transit guarantee.',
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          fontSize: 11,
                          color: Color(0xFF6B7E74),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: math.max(20.0, MediaQuery.of(context).padding.bottom + 16)),
        ],
      ),
    );
  }

  // ==================== 4. DRIVER ACCEPTED STAGE (EXACT IMAGE 3 REPLICA) ====================
  Widget _buildDriverAcceptedStage(ScrollController scrollController) {
    final trip = _assignedTrip ?? {};
    final selectedVehName = _selectedVehicleIndex != null ? _vehicles[_selectedVehicleIndex!]['name'] as String : 'Cargo Truck';
    final driverName = trip['driverName']?.toString() ?? 'Assigned Driver';
    final plateNumber = trip['plateNumber']?.toString() ?? '';
    final driverVehicle = trip['driverVehicle']?.toString() ?? trip['vehicle']?.toString() ?? selectedVehName;
    final fare = trip['fare']?.toString() ?? (_selectedVehicleIndex != null ? _vehicles[_selectedVehicleIndex!]['price'] as String : 'TZS 5,000');
    final driverPhone = trip['driverPhone']?.toString() ?? trip['driver_phone']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        children: [
          // Pull Handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFCAD4CC),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Card 1: Pickup Arrival & Driver Profile (Exact Image 3 Top Card)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFCAD4CC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _isCargoLoaded ? const Color(0xFFDCFCE7) : const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _isCargoLoaded ? const Color(0xFF86EFAC) : const Color(0xFFC7D2FE),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isCargoLoaded ? const Color(0xFF16A34A) : const Color(0xFF4F46E5),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _cargoTransitState.toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: 'Segoe UI Variable',
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                    color: _isCargoLoaded ? const Color(0xFF16A34A) : const Color(0xFF4F46E5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$_remainingDurationMin min',
                                style: const TextStyle(
                                  fontFamily: 'Segoe UI Variable',
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1E2822),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '(${_remainingDistanceKm.toStringAsFixed(1)} km left)',
                                style: const TextStyle(
                                  fontFamily: 'Segoe UI Variable',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B7E74),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            plateNumber.isNotEmpty ? '$plateNumber · $driverVehicle' : driverVehicle,
                            style: const TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E2822),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$driverName · Top-rated driver',
                            style: const TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 12,
                              color: Color(0xFF6B7E74),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Driver Avatar with Gold Star Badge (Exact Image 3)
                    Stack(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE5EEF5),
                            border: Border.all(color: const Color(0xFFCAD4CC), width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              driverName.isNotEmpty ? driverName[0].toUpperCase() : 'D',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Color(0xFF4B7B9F)),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF59E0B),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.star_rounded, size: 12, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Pickup Notes & Phone Call Action Row (Exact Image 3)
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _showDriverChatAndNotesModal,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F5F1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF1E2822)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _cargoNotes.isNotEmpty ? 'Chat: "$_cargoNotes"' : 'Chat with Driver & Notes',
                                  style: const TextStyle(
                                    fontFamily: 'Segoe UI Variable',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E2822),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE5EEF5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.phone_rounded, size: 18, color: Color(0xFF4B7B9F)),
                        onPressed: () => _callDriver(driverPhone),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Card 2: Route Details (Exact Image 3 Route Card)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFCAD4CC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Route',
                      style: TextStyle(
                        fontFamily: 'Segoe UI Variable',
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E2822),
                      ),
                    ),
                    InkWell(
                      onTap: _showAddStopModal,
                      child: const Text(
                        '+ Add Stop',
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4B7B9F),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 3),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF16A34A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 32 + (_intermediateStops.length * 36.0),
                          color: const Color(0xFFCAD4CC),
                        ),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E2822),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => _showEditLocationModal(isPickup: true),
                            borderRadius: BorderRadius.circular(6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _currentPickupName,
                                    style: const TextStyle(
                                      fontFamily: 'Segoe UI Variable',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E2822),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF6B7E74)),
                              ],
                            ),
                          ),
                          if (_intermediateStops.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            ..._intermediateStops.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final stop = entry.value;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFD97706)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Stop ${idx + 1}: ${stop['name']}',
                                        style: const TextStyle(
                                          fontFamily: 'Segoe UI Variable',
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF92400E),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => _removeStop(idx),
                                      child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFB45309)),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: _showAddStopModal,
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.add_circle_outline_rounded, size: 14, color: Color(0xFF4B7B9F)),
                                  const SizedBox(width: 4),
                                  Text(
                                    _intermediateStops.isEmpty ? '+ Add stop' : '+ Add another stop',
                                    style: const TextStyle(
                                      fontFamily: 'Segoe UI Variable',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4B7B9F),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => _showEditLocationModal(isPickup: false),
                            borderRadius: BorderRadius.circular(6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _currentDropoffName,
                                    style: const TextStyle(
                                      fontFamily: 'Segoe UI Variable',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E2822),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF6B7E74)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Card 3: Payment Method (Exact Image 3 Payment Card)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFCAD4CC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment method',
                  style: TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E2822),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Category: ${trip['vehicle'] ?? "Cargo"}',
                  style: const TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    fontSize: 12,
                    color: Color(0xFF6B7E74),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.payments_rounded, color: Color(0xFF16A34A), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _paymentMethod,
                        style: const TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E2822),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      fare,
                      style: const TextStyle(
                        fontFamily: 'Segoe UI Variable',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E2822),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF6B7E74)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 1. Live In-Transit Status Card (Driver completes delivery, not customer)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF16A34A), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Driver In Transit to Destination',
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF14532D),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Your cargo is en route. The driver will confirm delivery and offload upon arrival at your dropoff point.',
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          fontSize: 11.5,
                          color: Color(0xFF166534),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 2. Cancel Option with 10 Strong Reasons
          Center(
            child: TextButton(
              onPressed: _showCancellationReasonsModal,
              child: const Text(
                'Cancel Cargo Request',
                style: TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
          ),

          // 3. Discreet Dev Simulation for testing
          Center(
            child: TextButton(
              onPressed: _devSimulateDriverCompletion,
              child: const Text(
                '• Dev Mode: Simulate Driver Arrival & Offload •',
                style: TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          ),

          // 4. Discreet Dev Simulation for testing
          Center(
            child: TextButton(
              onPressed: _devSimulateDriverCompletion,
              child: const Text(
                '• Dev Mode: Simulate Driver Arrival & Offload •',
                style: TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          ),

          SizedBox(height: math.max(20.0, MediaQuery.of(context).padding.bottom + 16)),
        ],
      ),
    );
  }

  // 10 Strong Cancellation Reasons as agreed
  static const List<Map<String, dynamic>> _tenCancellationReasons = [
    {
      'title': 'Driver asked me to cancel',
      'subtitle': 'Dereva ameniomba ni-cancel safari',
      'isScamReport': true,
      'icon': Icons.warning_amber_rounded,
    },
    {
      'title': 'Driver is too far / Taking too long',
      'subtitle': 'Dereva yuko mbali sana au anachelewa kufika',
      'isScamReport': false,
      'icon': Icons.hourglass_bottom_rounded,
    },
    {
      'title': 'Driver is stationary / Not moving',
      'subtitle': 'Dereva hasogei kwenye ramani ya GPS',
      'isScamReport': false,
      'icon': Icons.pause_circle_outline_rounded,
    },
    {
      'title': 'Driver is unreachable / Phone off',
      'subtitle': 'Dereva hapokei simu au haipatikani',
      'isScamReport': false,
      'icon': Icons.phone_disabled_rounded,
    },
    {
      'title': 'Driver demanding extra cash off app',
      'subtitle': 'Dereva anadai pesa ya ziada nje ya makubaliano ya app',
      'isScamReport': true,
      'icon': Icons.price_change_outlined,
    },
    {
      'title': 'Driver dispute or rude behavior',
      'subtitle': 'Dereva ana lugha chafu au tumeshindwa kuelewana',
      'isScamReport': false,
      'icon': Icons.sentiment_dissatisfied_rounded,
    },
    {
      'title': 'Wrong pickup or dropoff location',
      'subtitle': 'Nimekosea eneo la kuchukua au kushusha mzigo',
      'isScamReport': false,
      'icon': Icons.edit_location_alt_rounded,
    },
    {
      'title': 'Selected wrong vehicle size',
      'subtitle': 'Nimechagua gari lisilolingana na ukubwa wa mzigo',
      'isScamReport': false,
      'icon': Icons.local_shipping_outlined,
    },
    {
      'title': 'Shipment no longer needed',
      'subtitle': 'Nimebadili mpango, sihitaji tena kusafirisha mzigo',
      'isScamReport': false,
      'icon': Icons.cancel_outlined,
    },
    {
      'title': 'Found alternative emergency transport',
      'subtitle': 'Nimepata usafiri mwingine wa dharura',
      'isScamReport': false,
      'icon': Icons.swap_horiz_rounded,
    },
  ];

  void _showCancellationReasonsModal() {
    int selectedIndex = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCAD4CC),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Reason for Cancelling',
                      style: TextStyle(
                        fontFamily: 'Segoe UI Variable',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E2822),
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Please select why you want to cancel this delivery. No fee will be charged:',
                      style: TextStyle(
                        fontFamily: 'Segoe UI Variable',
                        fontSize: 12,
                        color: Color(0xFF6B7E74),
                      ),
                    ),
                    const SizedBox(height: 12),



                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _tenCancellationReasons.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, idx) {
                          final item = _tenCancellationReasons[idx];
                          final isSelected = selectedIndex == idx;

                          return InkWell(
                            onTap: () => setModalState(() => selectedIndex = idx),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    item['icon'] as IconData,
                                    size: 20,
                                    color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['title'].toString(),
                                          style: TextStyle(
                                            fontFamily: 'Segoe UI Variable',
                                            fontSize: 13,
                                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                            color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF1E2822),
                                          ),
                                        ),
                                        Text(
                                          item['subtitle'].toString(),
                                          style: const TextStyle(
                                            fontFamily: 'Segoe UI Variable',
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                    size: 20,
                                    color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 14),

                    ElevatedButton(
                      onPressed: () async {
                        final reason = _tenCancellationReasons[selectedIndex]['title'].toString();
                        Navigator.pop(ctx);
                        await _executeCancellation(reason);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'Confirm Cancellation',
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Keep Shipment Active',
                        style: TextStyle(
                          color: Color(0xFF6B7E74),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _executeCancellation(String reason) async {
    final tripId = _assignedTrip?['id']?.toString() ?? '';

    // Notify backend
    try {
      if (tripId.isNotEmpty) {
        await http.post(
          Uri.parse('${ApiService.baseUrl}/orders/$tripId/cancel'),
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({
            'reason': reason,
            'cancelled_by': 'customer',
            'timestamp': DateTime.now().toIso8601String(),
          }),
        ).timeout(const Duration(seconds: 4));
      }
    } catch (_) {}

    // Update persistent history to mark status as Cancelled
    if (_assignedTrip != null) {
      final tripToSave = Map<String, dynamic>.from(_assignedTrip!);
      tripToSave['status'] = 'Cancelled';
      tripToSave['is_active'] = false;
      tripToSave['cancellation_reason'] = reason;
      tripToSave['cancelled_at'] = DateTime.now().toIso8601String();
      await SessionManager.saveBookedTrip(tripToSave);
      if (tripId.isNotEmpty) {
        await SessionManager.updateBookedTripStatus(tripId, 'Cancelled', reason: reason);
      }
    } else if (tripId.isNotEmpty) {
      await SessionManager.updateBookedTripStatus(tripId, 'Cancelled', reason: reason);
    }

    await SessionManager.clearActiveTrip();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Shipment cancelled: $reason. Quoted fare: TZS 0 charged.'),
        backgroundColor: const Color(0xFF1E2822),
        duration: const Duration(seconds: 3),
      ),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MainNavigationScreen(initialTabIndex: 0)),
      (route) => false,
    );
  }

  Future<void> _devSimulateDriverCompletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.fact_check_rounded, color: Color(0xFF16A34A), size: 24),
            SizedBox(width: 10),
            Text(
              'Simulate Driver Offload',
              style: TextStyle(fontFamily: 'Segoe UI Variable', fontWeight: FontWeight.w900, fontSize: 17),
            ),
          ],
        ),
        content: const Text(
          'Simulate driver confirming arrival at dropoff point and completing cargo offloading?',
          style: TextStyle(fontFamily: 'Segoe UI Variable', fontSize: 13.5, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7E74), fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Simulate Delivery Complete', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await SessionManager.clearActiveTrip();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver marked delivery complete! Cargo safely offloaded.'),
          backgroundColor: Color(0xFF16A34A),
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationScreen(initialTabIndex: 0)),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _driverWaitTimer?.cancel();
    _driverMotionTimer?.cancel();
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final midLat = (widget.pickupLatLng.latitude + widget.dropoffLatLng.latitude) / 2;
    final midLng = (widget.pickupLatLng.longitude + widget.dropoffLatLng.longitude) / 2;

    return PopScope(
      canPop: _bookingStage == BookingStage.vehicleSelection,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Safari ipo hewani. Huwezi kuondoka mpaka mzigo ufike au ughairi safari.'),
            backgroundColor: Color(0xFFDC2626),
            duration: Duration(seconds: 3),
          ),
        );
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
        body: Stack(
          children: [
            // 1. Google Maps Official Roadmap Tiles
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(midLat, midLng),
                initialZoom: 13.5,
                minZoom: 4.0,
                maxZoom: 19.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                // Google Maps Standard Roadmap Tiles (identical to Bolt & Google Maps)
                TileLayer(
                  urlTemplate: 'https://{s}.google.com/vt/lyrs=m&hl=en&x={x}&y={y}&z={z}',
                  subdomains: const ['mt0', 'mt1', 'mt2', 'mt3'],
                  userAgentPackageName: 'com.cargoo.customer.customer_app',
                  maxZoom: 20,
                ),

                // Route Polyline (CARGOO Slate Blue Line)
                PolylineLayer(
                  polylines: [
                    // Outer casing / glow
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 8.0,
                      color: const Color(0xFF4B7B9F).withValues(alpha: 0.35),
                    ),
                    // Core route line
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5.0,
                      color: const Color(0xFF4B7B9F),
                    ),
                  ],
                ),

                // Pickup, Stops & Dropoff Markers
                MarkerLayer(
                  markers: [
                    // Pickup Marker with Speech Bubble (Exact Image 1 & 2)
                    Marker(
                      point: _currentPickupLatLng,
                      width: 140,
                      height: 72,
                      alignment: Alignment.bottomCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _showEditLocationModal(isPickup: true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E2822),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                                ],
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Pickup here',
                                    style: TextStyle(
                                      fontFamily: 'Segoe UI Variable',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Tap to edit',
                                    style: TextStyle(
                                      fontFamily: 'Segoe UI Variable',
                                      fontSize: 9.5,
                                      color: Color(0xFFCAD4CC),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          CustomPaint(
                            size: const Size(8, 4),
                            painter: TrianglePainter(color: const Color(0xFF1E2822)),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF4B7B9F),
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Intermediate Stops Markers
                    ..._intermediateStops.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final stop = entry.value;
                      final stopPos = stop['latLng'] as LatLng;
                      return Marker(
                        point: stopPos,
                        width: 140,
                        height: 58,
                        alignment: Alignment.bottomCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                                ],
                              ),
                              child: Text(
                                'Stop ${idx + 1}: ${stop['name']}',
                                style: const TextStyle(
                                  fontFamily: 'Segoe UI Variable',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.location_on_rounded, size: 26, color: Color(0xFFD97706)),
                          ],
                        ),
                      );
                    }),

                    // 4. Live Moving Driver Vehicle Marker (Shows when driver accepted / in motion)
                    if (_driverMarkerPosition != null)
                      Marker(
                        point: _driverMarkerPosition!,
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Radar pulse
                            Container(
                              width: 66,
                              height: 66,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF16A34A).withValues(alpha: 0.22),
                              ),
                            ),
                            // White vehicle container with shadow
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF16A34A), width: 2.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Transform.rotate(
                                  angle: _driverBearing * math.pi / 180,
                                  child: const Icon(
                                    Icons.navigation_rounded,
                                    color: Color(0xFF16A34A),
                                    size: 26,
                                  ),
                                ),
                              ),
                            ),
                            // Floating Plate Tag Pill
                            Positioned(
                              top: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E2822),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black26, blurRadius: 4),
                                  ],
                                ),
                                child: Text(
                                  _assignedTrip?['plateNumber']?.toString() ?? 'CARGO',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // 2. Top Header Bar (Back button & Route Card or Circle Button)
            if (_bookingStage == BookingStage.vehicleSelection)
              PositionBar(
                pickupName: _currentPickupName,
                dropoffName: _currentDropoffName,
                onBack: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
                    );
                  }
                },
                onEdit: _openChangeRoute,
              )
            else
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                child: GestureDetector(
                  onTap: () {
                    if (_bookingStage == BookingStage.confirmPickup) {
                      setState(() => _bookingStage = BookingStage.vehicleSelection);
                    } else if (_bookingStage == BookingStage.waitingForDriver) {
                      _driverWaitTimer?.cancel();
                      setState(() => _bookingStage = BookingStage.vehicleSelection);
                    } else if (_bookingStage == BookingStage.driverAccepted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Safari ipo hewani. Huwezi kuondoka mpaka mzigo ufike au ughairi safari.'),
                          backgroundColor: Color(0xFFDC2626),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _bookingStage == BookingStage.confirmPickup ? Icons.arrow_back_rounded : Icons.person_outline_rounded,
                      color: const Color(0xFF1E2822),
                      size: 22,
                    ),
                  ),
                ),
              ),

            // 3. Floating Right Map Controls (Recenter, Sheet Toggle - zoom +/- removed per spec)
            Positioned(
              right: 16,
              top: 150,
              child: Column(
                children: [
                  _buildMapFloatingBtn(
                    icon: Icons.my_location_rounded,
                    tooltip: 'Recenter Route',
                    onTap: _recenter,
                  ),
                  const SizedBox(height: 8),
                  _buildMapFloatingBtn(
                    icon: _isSheetCollapsed ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    tooltip: _isSheetCollapsed ? 'View Vehicles' : 'Full Map',
                    onTap: _toggleSheetCollapse,
                    color: const Color(0xFF4B7B9F),
                    iconColor: Colors.white,
                  ),
                ],
              ),
            ),

            // 4. Draggable Cargo Vehicle Bottom Sheet (Stage-Driven UX Flow)
            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: _bookingStage == BookingStage.driverAccepted
                  ? 0.70
                  : (_bookingStage == BookingStage.vehicleSelection ? 0.48 : 0.45),
              minChildSize: 0.08,
              maxChildSize: 0.90,
              snap: true,
              snapSizes: const [0.08, 0.40, 0.45, 0.48, 0.70, 0.90],
              builder: (context, scrollController) {
                switch (_bookingStage) {
                  case BookingStage.vehicleSelection:
                    return _buildVehicleSelectionStage(scrollController);
                  case BookingStage.confirmPickup:
                    return _buildConfirmPickupStage(scrollController);
                  case BookingStage.waitingForDriver:
                    return _buildWaitingForDriverStage(scrollController);
                  case BookingStage.driverAccepted:
                    return _buildDriverAcceptedStage(scrollController);
                }
              },
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildMapFloatingBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = Colors.white,
    Color iconColor = const Color(0xFF0F172A),
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: Colors.black38,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Top Header Route Info Bar
class PositionBar extends StatelessWidget {
  final String pickupName;
  final String dropoffName;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  const PositionBar({
    super.key,
    required this.pickupName,
    required this.dropoffName,
    required this.onBack,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 22),
              onPressed: onBack,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4B7B9F),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            pickupName,
                            style: const TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            dropoffName,
                            style: const TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF1F5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCAD4CC)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_location_alt_outlined, size: 14, color: Color(0xFF4B7B9F)),
                    SizedBox(width: 4),
                    Text(
                      'Change',
                      style: TextStyle(
                        fontFamily: 'Segoe UI Variable',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4B7B9F),
                      ),
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

/// Realistic Side-view Vehicle Artwork Painter
class RealisticVehicleArtPainter extends CustomPainter {
  final String type;

  RealisticVehicleArtPainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    if (type == 'guta') {
      _drawRealisticGuta(canvas, size);
    } else if (type == 'kirikuu') {
      _drawRealisticKirikuu(canvas, size);
    } else if (type == 'canter') {
      _drawRealisticCanter(canvas, size);
    } else if (type == 'fuso') {
      _drawRealisticFuso(canvas, size);
    } else {
      _drawRealisticScania(canvas, size);
    }
  }

  void _drawRealisticKirikuu(Canvas canvas, Size size) {
    final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(Rect.fromLTWH(4, size.height - 8, size.width - 8, 7), shadowPaint);

    final cabPath = Path();
    cabPath.moveTo(size.width * 0.45, size.height * 0.75);
    cabPath.lineTo(size.width * 0.45, size.height * 0.28);
    cabPath.lineTo(size.width * 0.72, size.height * 0.28);
    cabPath.lineTo(size.width * 0.92, size.height * 0.52);
    cabPath.lineTo(size.width * 0.95, size.height * 0.75);
    cabPath.close();

    final cabPaint = Paint()
      ..shader = LinearGradient(
        colors: const [Color(0xFFF8FAFC), Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(cabPath, cabPaint);

    final glassPath = Path();
    glassPath.moveTo(size.width * 0.65, size.height * 0.32);
    glassPath.lineTo(size.width * 0.71, size.height * 0.32);
    glassPath.lineTo(size.width * 0.88, size.height * 0.52);
    glassPath.lineTo(size.width * 0.65, size.height * 0.52);
    glassPath.close();
    canvas.drawPath(glassPath, Paint()..color = const Color(0xFF38BDF8));

    final bedRect = Rect.fromLTWH(size.width * 0.05, size.height * 0.42, size.width * 0.42, size.height * 0.33);
    canvas.drawRRect(RRect.fromRectAndRadius(bedRect, const Radius.circular(2)), Paint()..color = const Color(0xFF94A3B8));

    final cargoRect = Rect.fromLTWH(size.width * 0.08, size.height * 0.25, size.width * 0.36, size.height * 0.24);
    canvas.drawRRect(RRect.fromRectAndRadius(cargoRect, const Radius.circular(4)), Paint()..color = const Color(0xFF16A34A));

    _drawWheel(canvas, Offset(size.width * 0.22, size.height * 0.78), 8.5);
    _drawWheel(canvas, Offset(size.width * 0.75, size.height * 0.78), 8.5);
  }

  void _drawRealisticGuta(Canvas canvas, Size size) {
    final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.15)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(Rect.fromLTWH(4, size.height - 8, size.width - 8, 6), shadowPaint);

    final boxRect = Rect.fromLTWH(size.width * 0.08, size.height * 0.30, size.width * 0.45, size.height * 0.45);
    canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(3)), Paint()..color = const Color(0xFFEAB308));

    final frontPath = Path();
    frontPath.moveTo(size.width * 0.53, size.height * 0.75);
    frontPath.lineTo(size.width * 0.60, size.height * 0.35);
    frontPath.lineTo(size.width * 0.85, size.height * 0.48);
    frontPath.lineTo(size.width * 0.88, size.height * 0.75);
    frontPath.close();
    canvas.drawPath(frontPath, Paint()..color = const Color(0xFF16A34A));

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.62, size.height * 0.38, 14, 12), const Radius.circular(2)), Paint()..color = const Color(0xFFBAE6FD));

    _drawWheel(canvas, Offset(size.width * 0.24, size.height * 0.78), 8.0);
    _drawWheel(canvas, Offset(size.width * 0.78, size.height * 0.78), 8.0);
  }

  void _drawRealisticCanter(Canvas canvas, Size size) {
    final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(Rect.fromLTWH(2, size.height - 8, size.width - 4, 7), shadowPaint);

    final boxRect = Rect.fromLTWH(size.width * 0.05, size.height * 0.14, size.width * 0.48, size.height * 0.60);
    canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(4)), Paint()..color = const Color(0xFF2563EB));
    canvas.drawLine(Offset(size.width * 0.08, size.height * 0.42), Offset(size.width * 0.50, size.height * 0.42), Paint()..color = Colors.white70..strokeWidth = 2);

    final cabPath = Path();
    cabPath.moveTo(size.width * 0.53, size.height * 0.75);
    cabPath.lineTo(size.width * 0.53, size.height * 0.22);
    cabPath.lineTo(size.width * 0.78, size.height * 0.22);
    cabPath.lineTo(size.width * 0.94, size.height * 0.52);
    cabPath.lineTo(size.width * 0.94, size.height * 0.75);
    cabPath.close();
    canvas.drawPath(cabPath, Paint()..color = const Color(0xFFF1F5F9));

    final glassPath = Path();
    glassPath.moveTo(size.width * 0.68, size.height * 0.26);
    glassPath.lineTo(size.width * 0.77, size.height * 0.26);
    glassPath.lineTo(size.width * 0.90, size.height * 0.50);
    glassPath.lineTo(size.width * 0.68, size.height * 0.50);
    glassPath.close();
    canvas.drawPath(glassPath, Paint()..color = const Color(0xFF38BDF8));

    _drawWheel(canvas, Offset(size.width * 0.22, size.height * 0.78), 9.0);
    _drawWheel(canvas, Offset(size.width * 0.76, size.height * 0.78), 9.0);
  }

  void _drawRealisticFuso(Canvas canvas, Size size) {
    final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.20)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(Rect.fromLTWH(2, size.height - 8, size.width - 4, 7), shadowPaint);

    final cargoBed = Rect.fromLTWH(size.width * 0.04, size.height * 0.18, size.width * 0.54, size.height * 0.55);
    canvas.drawRRect(RRect.fromRectAndRadius(cargoBed, const Radius.circular(3)), Paint()..color = const Color(0xFFD97706));

    final cabPath = Path();
    cabPath.moveTo(size.width * 0.58, size.height * 0.75);
    cabPath.lineTo(size.width * 0.58, size.height * 0.15);
    cabPath.lineTo(size.width * 0.82, size.height * 0.15);
    cabPath.lineTo(size.width * 0.95, size.height * 0.48);
    cabPath.lineTo(size.width * 0.95, size.height * 0.75);
    cabPath.close();
    canvas.drawPath(cabPath, Paint()..color = const Color(0xFFEA580C));

    final glassPath = Path();
    glassPath.moveTo(size.width * 0.70, size.height * 0.20);
    glassPath.lineTo(size.width * 0.81, size.height * 0.20);
    glassPath.lineTo(size.width * 0.92, size.height * 0.46);
    glassPath.lineTo(size.width * 0.70, size.height * 0.46);
    glassPath.close();
    canvas.drawPath(glassPath, Paint()..color = const Color(0xFF38BDF8));

    _drawWheel(canvas, Offset(size.width * 0.18, size.height * 0.78), 9.5);
    _drawWheel(canvas, Offset(size.width * 0.36, size.height * 0.78), 9.5);
    _drawWheel(canvas, Offset(size.width * 0.78, size.height * 0.78), 9.5);
  }

  void _drawRealisticScania(Canvas canvas, Size size) {
    final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.22)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(Rect.fromLTWH(2, size.height - 8, size.width - 4, 7), shadowPaint);

    final containerRect = Rect.fromLTWH(size.width * 0.03, size.height * 0.10, size.width * 0.58, size.height * 0.64);
    canvas.drawRRect(RRect.fromRectAndRadius(containerRect, const Radius.circular(3)), Paint()..color = const Color(0xFF1E3A8A));

    for (int i = 1; i <= 4; i++) {
      final x = size.width * 0.03 + (size.width * 0.58) * (i / 5);
      canvas.drawLine(Offset(x, size.height * 0.10), Offset(x, size.height * 0.74), Paint()..color = const Color(0xFF3B82F6)..strokeWidth = 1.2);
    }

    final cabPath = Path();
    cabPath.moveTo(size.width * 0.65, size.height * 0.75);
    cabPath.lineTo(size.width * 0.65, size.height * 0.10);
    cabPath.lineTo(size.width * 0.88, size.height * 0.10);
    cabPath.lineTo(size.width * 0.96, size.height * 0.45);
    cabPath.lineTo(size.width * 0.96, size.height * 0.75);
    cabPath.close();
    canvas.drawPath(cabPath, Paint()..color = const Color(0xFFDC2626));

    final glassPath = Path();
    glassPath.moveTo(size.width * 0.74, size.height * 0.15);
    glassPath.lineTo(size.width * 0.87, size.height * 0.15);
    glassPath.lineTo(size.width * 0.94, size.height * 0.42);
    glassPath.lineTo(size.width * 0.74, size.height * 0.42);
    glassPath.close();
    canvas.drawPath(glassPath, Paint()..color = const Color(0xFF38BDF8));

    _drawWheel(canvas, Offset(size.width * 0.14, size.height * 0.78), 10.0);
    _drawWheel(canvas, Offset(size.width * 0.28, size.height * 0.78), 10.0);
    _drawWheel(canvas, Offset(size.width * 0.44, size.height * 0.78), 10.0);
    _drawWheel(canvas, Offset(size.width * 0.82, size.height * 0.78), 10.0);
  }

  void _drawWheel(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF1E293B));
    canvas.drawCircle(center, radius * 0.55, Paint()..color = const Color(0xFF94A3B8));
    canvas.drawCircle(center, radius * 0.2, Paint()..color = const Color(0xFF0F172A));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Borderless Top-down / Isometric Vehicle Graphic for the Map (NO white box)
class MapVehicleMarkerPainter extends CustomPainter {
  final String type;
  final Color color;

  MapVehicleMarkerPainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width / 2, size.height / 2 + 2), width: 28, height: 16),
      Paint()..color = Colors.black.withValues(alpha: 0.28)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: 18, height: 26),
      const Radius.circular(4),
    );
    canvas.drawRRect(bodyRect, Paint()..color = color);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width / 2 - 6, size.height / 2 - 8, 12, 5),
        const Radius.circular(1.5),
      ),
      Paint()..color = const Color(0xFF0F172A),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width / 2 - 7, size.height / 2 + 1, 14, 10),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.2),
    );

    final headlightPaint = Paint()..color = const Color(0xFFFEF08A);
    canvas.drawCircle(Offset(size.width / 2 - 5, size.height / 2 - 12), 1.5, headlightPaint);
    canvas.drawCircle(Offset(size.width / 2 + 5, size.height / 2 - 12), 1.5, headlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Downward Triangle Pointer for Speech Bubbles (Images 1 & 2)
class TrianglePainter extends CustomPainter {
  final Color color;
  const TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
