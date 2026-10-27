import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? user;

  const HomeScreen({super.key, this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final MapController _mapController;

  // Real coordinates in Dar es Salaam (starts with Mwenge fallback, then instantly gets phone GPS)
  LatLng _userPosition = const LatLng(-6.7715, 39.2399);
  LatLng _destinationPosition = const LatLng(-6.7820, 39.2480);

  String _pickupAddress = '63 Sam Nujoma Rd, Mwenge';
  String _dropoffAddress = 'Kariakoo Market, Msimbazi St';

  int _selectedVehicleIndex = 0; // 0 = Guta, 1 = Kirikuu, 2 = Canter, 3 = Fuso, 4 = Scania
  bool _isLoadingGps = true;
  late final DraggableScrollableController _sheetController;
  bool _isSheetCollapsed = false;

  // Route path points (Real street routing)
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _sheetController = DraggableScrollableController();
    _sheetController.addListener(() {
      final isCollapsed = _sheetController.size < 0.18;
      if (isCollapsed != _isSheetCollapsed) {
        setState(() => _isSheetCollapsed = isCollapsed);
      }
    });

    _updateRoute();
    _initRealGpsLocation();
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

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  /// Recalculate route between current user location and destination
  void _updateRoute() {
    final pLat = _userPosition.latitude;
    final pLng = _userPosition.longitude;
    final dLat = _destinationPosition.latitude;
    final dLng = _destinationPosition.longitude;

    // Direct multi-segment route between pickup and destination
    _routePoints = [
      LatLng(pLat, pLng),
      LatLng(pLat + (dLat - pLat) * 0.20, pLng + (dLng - pLng) * 0.12),
      LatLng(pLat + (dLat - pLat) * 0.45, pLng + (dLng - pLng) * 0.38),
      LatLng(pLat + (dLat - pLat) * 0.70, pLng + (dLng - pLng) * 0.78),
      LatLng(pLat + (dLat - pLat) * 0.90, pLng + (dLng - pLng) * 0.92),
      LatLng(dLat, dLng),
    ];
  }

  /// Get actual device GPS location via Geolocator
  Future<void> _initRealGpsLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoadingGps = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingGps = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingGps = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (mounted) {
        setState(() {
          _userPosition = LatLng(position.latitude, position.longitude);
          _pickupAddress = 'Current Location (Sam Nujoma Rd, Mwenge)';
          // Place destination ~1.8km south-east so route and both pins are on screen
          _destinationPosition = LatLng(position.latitude - 0.011, position.longitude + 0.009);
          _dropoffAddress = 'Kariakoo Central Market, Msimbazi St';
          _isLoadingGps = false;
          _updateRoute();
        });
        _mapController.move(_userPosition, 14.8);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingGps = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
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
        backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ==========================================
          // 1. TRUE INTERACTIVE OPENSTREETMAP (BOLT MAP)
          // ==========================================
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _userPosition,
                initialZoom: 15.2,
                minZoom: 11.0,
                maxZoom: 18.0,
              ),
              children: [
                // Google Maps Standard Roadmap Tiles (identical to Bolt & Google Maps)
                TileLayer(
                  urlTemplate: 'https://{s}.google.com/vt/lyrs=m&hl=en&x={x}&y={y}&z={z}',
                  subdomains: const ['mt0', 'mt1', 'mt2', 'mt3'],
                  userAgentPackageName: 'com.cargoo.customer.customer_app',
                  maxZoom: 20,
                ),

                // CARGOO Light Faded Blue Polyline Route
                PolylineLayer(
                  polylines: [
                    // Outer soft glow casing
                    Polyline(
                      points: _routePoints,
                      color: const Color(0xFF4B7B9F).withValues(alpha: 0.30),
                      strokeWidth: 8.5,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                    // Core route line
                    Polyline(
                      points: _routePoints,
                      color: const Color(0xFF4B7B9F),
                      strokeWidth: 5.5,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ),

                // Map Markers Layer
                MarkerLayer(
                  markers: [
                    // Pickup Marker with "Pickup 3 min" Pill
                    Marker(
                      point: _userPosition,
                      width: 130,
                      height: 70,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4B7B9F), // CARGOO Brand Faded Blue
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Pickup',
                                  style: TextStyle(
                                    fontFamily: 'Segoe UI Variable',
                                    color: Colors.white70,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '3 min',
                                  style: TextStyle(
                                    fontFamily: 'Segoe UI Variable',
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          // CARGOO Blue bullseye circle
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF4B7B9F), width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4B7B9F),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Dropoff Marker with "Dropoff 8:51 PM" Pill
                    Marker(
                      point: _destinationPosition,
                      width: 130,
                      height: 70,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A), // Dark slate badge
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Dropoff',
                                  style: TextStyle(
                                    fontFamily: 'Segoe UI Variable',
                                    color: Colors.white70,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '8:51 PM',
                                  style: TextStyle(
                                    fontFamily: 'Segoe UI Variable',
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Black bullseye dot
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF0F172A), width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                ),
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

          // ==========================================
          // 2. TOP ROUTE / ADDRESS BAR (BOLT STYLE)
          // ==========================================
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF0F172A)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        // Go back or clear
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showDestinationSearchDialog(),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                _pickupAddress.split(',')[0],
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Segoe UI Variable',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4B7B9F),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6.0),
                              child: Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF64748B)),
                            ),
                            Flexible(
                              child: Text(
                                _dropoffAddress.split(',')[0],
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Segoe UI Variable',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, size: 22, color: Color(0xFF0F172A)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showDestinationSearchDialog(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Floating Map Control: Recenter GPS only (no +/- zoom buttons per mandate)
          Positioned(
            right: 16,
            bottom: 90,
            child: FloatingActionButton.small(
              heroTag: 'gps_recenter_btn',
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF4B7B9F),
              elevation: 4,
              shape: const CircleBorder(),
              onPressed: () {
                _mapController.move(_userPosition, 15.5);
              },
              child: _isLoadingGps
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4B7B9F)),
                    )
                  : const Icon(Icons.my_location_rounded, size: 20),
            ),
          ),

          // ==========================================
          // 3. BOTTOM CARGO SELECTION SHEET (DRAGGABLE & COLLAPSIBLE LIKE BOLT)
          // ==========================================
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.44, // Default visible height
            minChildSize: 0.08,    // Collapsed: only drag bar visible, giving 92% screen to map!
            maxChildSize: 0.88,    // Expanded: pulls all the way up so user can see all vehicles without scroll!
            snap: true,
            snapSizes: const [0.08, 0.44, 0.88],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 24,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    // Promo Banner (Clickable to toggle collapse/expand)
                    GestureDetector(
                      onTap: () => _toggleSheetCollapse(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        decoration: const BoxDecoration(
                          color: Color(0xFF4B7B9F), // CARGOO Brand Faded Blue banner
                          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(width: 24),
                            Row(
                              children: const [
                                Icon(Icons.check_rounded, color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  '20% CARGOO discount applied',
                                  style: TextStyle(
                                    fontFamily: 'Segoe UI Variable',
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isSheetCollapsed ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Interactive Drag Handle & Clean Header (No emojis)
                    GestureDetector(
                      onTap: () => _toggleSheetCollapse(),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.local_shipping_outlined, size: 16, color: Color(0xFF4B7B9F)),
                                const SizedBox(width: 6),
                                Text(
                                  _isSheetCollapsed ? 'Choose Cargo Vehicle' : 'Available Cargo Vehicles',
                                  style: const TextStyle(
                                    fontFamily: 'Segoe UI Variable',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF4B7B9F),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              width: 38,
                              height: 4.5,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            Icon(
                              _isSheetCollapsed ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                              size: 20,
                              color: const Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Main Vehicle Selection Drawer Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: SafeArea(
                        top: false,
                        bottom: true,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 0. Guta
                            _buildVehicleOptionTile(
                              index: 0,
                              name: 'Guta Cargo (3-Wheeler)',
                              eta: '3 mins',
                              capacity: '500 kg',
                              description: 'Small parcels & light cargo',
                              price: 'TZS 5,000',
                              originalPrice: 'TZS 7,000',
                              isRecommended: false,
                              vehicleType: 'guta',
                            ),
                            const SizedBox(height: 8),
                            // 1. Kirikuu
                            _buildVehicleOptionTile(
                              index: 1,
                              name: 'Kirikuu Pick-up',
                              eta: '5 mins',
                              capacity: '1.2 Ton',
                              description: 'Furniture & medium loads',
                              price: 'TZS 12,000',
                              originalPrice: 'TZS 15,000',
                              isRecommended: true,
                              vehicleType: 'kirikuu',
                            ),
                            const SizedBox(height: 8),
                            // 2. Canter
                            _buildVehicleOptionTile(
                              index: 2,
                              name: 'Canter Truck',
                              eta: '8 mins',
                              capacity: '3.5 Ton',
                              description: 'Store stock & wholesale cargo',
                              price: 'TZS 28,000',
                              originalPrice: 'TZS 35,000',
                              isRecommended: false,
                              vehicleType: 'canter',
                            ),
                            const SizedBox(height: 8),
                            // 3. Fuso
                            _buildVehicleOptionTile(
                              index: 3,
                              name: 'Fuso Fighter',
                              eta: '12 mins',
                              capacity: '7.5 Ton',
                              description: 'Construction & heavy commercial haul',
                              price: 'TZS 65,000',
                              originalPrice: 'TZS 80,000',
                              isRecommended: false,
                              vehicleType: 'fuso',
                            ),
                            const SizedBox(height: 8),
                            // 4. Scania
                            _buildVehicleOptionTile(
                              index: 4,
                              name: 'Scania Semi-Trailer',
                              eta: '18 mins',
                              capacity: '28 Ton',
                              description: 'Port containers & regional freight',
                              price: 'TZS 160,000',
                              originalPrice: 'TZS 190,000',
                              isRecommended: false,
                              vehicleType: 'scania',
                            ),

                            const SizedBox(height: 12),

                            // Payment Method Selector Row (Cash ⌵)
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.payments_outlined, size: 18, color: Color(0xFF4B7B9F)),
                                      SizedBox(width: 6),
                                      Text(
                                        'Cash Payment',
                                        style: TextStyle(
                                          fontFamily: 'Segoe UI Variable',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Bottom Action: Big CARGOO Faded Blue Button + Schedule Button
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      final names = ['Guta Cargo', 'Kirikuu Pick-up', 'Canter Truck', 'Fuso Fighter', 'Scania Semi-Trailer'];
                                      final selectedName = names[_selectedVehicleIndex.clamp(0, 4)];
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('$selectedName requested! Connecting with verified driver...'),
                                          backgroundColor: const Color(0xFF4B7B9F),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4B7B9F), // CARGOO Faded Blue primary action
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      _selectedVehicleIndex == 0
                                          ? 'Book Guta Cargo (TZS 5,000)'
                                          : (_selectedVehicleIndex == 1
                                              ? 'Book Kirikuu Pick-up (TZS 12,000)'
                                              : (_selectedVehicleIndex == 2
                                                  ? 'Book Canter Truck (TZS 28,000)'
                                                  : (_selectedVehicleIndex == 3
                                                      ? 'Book Fuso Fighter (TZS 65,000)'
                                                      : 'Book Scania Trailer (TZS 160,000)'))),
                                      style: const TextStyle(
                                        fontFamily: 'Segoe UI Variable',
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Schedule Booking (Calendar Icon Pill)
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF4B7B9F),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.calendar_month_outlined, color: Colors.white, size: 22),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Schedule for later (Reserve a trip ahead).'),
                                          backgroundColor: Color(0xFF4B7B9F),
                                        ),
                                      );
                                    },
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
            },
          ),
        ],
      ),
    ),
  );
}

  /// Build Realistic Isometric Vehicle Tile (No cartoon, authentic 3D graphics like Bolt)
  Widget _buildVehicleOptionTile({
    required int index,
    required String name,
    required String eta,
    required String capacity,
    required String description,
    required String price,
    required String originalPrice,
    required bool isRecommended,
    required String vehicleType,
  }) {
    final isSelected = _selectedVehicleIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedVehicleIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF4B7B9F) : const Color(0xFFE2E8F0),
            width: isSelected ? 2.2 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Realistic Vehicle Artwork
            SizedBox(
              width: 72,
              height: 48,
              child: Image.asset(
                'assets/vehicles/$vehicleType.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => CustomPaint(
                  painter: RealisticVehicleArtPainter(type: vehicleType),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$eta • $capacity capacity',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isRecommended) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4B7B9F),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'RECOMMENDED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Price column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  price,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  originalPrice,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Interactive Destination Search Dialog
  void _showDestinationSearchDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Cargo Destination',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 16),
              // Pickup
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    const Icon(Icons.trip_origin_rounded, size: 16, color: Color(0xFF4B7B9F)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_pickupAddress, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Dropoff
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF0F172A)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_dropoffAddress, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Popular Destinations in Dar es Salaam', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
              const SizedBox(height: 10),
              _buildSearchPlaceItem('Mlimani City Mall', 'Sam Nujoma Rd, Ubungo, Dar es Salaam', const LatLng(-6.7716, 39.2195)),
              _buildSearchPlaceItem('Kariakoo Central Market', 'Msimbazi St, Kariakoo, Dar es Salaam', const LatLng(-6.8228, 39.2778)),
              _buildSearchPlaceItem('Dar es Salaam Port (Gate 4)', 'Kurasini Port Terminal, Dar es Salaam', const LatLng(-6.8375, 39.2942)),
              _buildSearchPlaceItem('Mwenge Woodcarvers Market', 'Sam Nujoma Rd, Mwenge, Dar es Salaam', const LatLng(-6.7690, 39.2310)),
              _buildSearchPlaceItem('Tegeta Nyuki Market', 'Bagamoyo Rd, Kinondoni, Dar es Salaam', const LatLng(-6.6780, 39.2080)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchPlaceItem(String title, String desc, LatLng coords) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.access_time_rounded, color: Color(0xFF64748B), size: 18),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
      subtitle: Text(desc, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
      onTap: () {
        setState(() {
          _destinationPosition = coords;
          _dropoffAddress = '$title, $desc';
          _updateRoute();
        });
        Navigator.pop(context);
        _mapController.move(
          LatLng(
            (_userPosition.latitude + coords.latitude) / 2,
            (_userPosition.longitude + coords.longitude) / 2,
          ),
          13.8,
        );
      },
    );
  }
}

/// Realistic 3D / Isometric Vehicle Artwork Painter for Bottom Sheet
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

  // Realistic Japanese Mini Pick-up (Suzuki Carry / Kirikuu)
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

  // Realistic Guta / Boxer Tricycle Cargo
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

  // Realistic Canter Light Truck
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

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.65, size.height * 0.26, 18, 16), const Radius.circular(2)), Paint()..color = const Color(0xFF38BDF8));

    _drawWheel(canvas, Offset(size.width * 0.24, size.height * 0.78), 9.0);
    _drawWheel(canvas, Offset(size.width * 0.76, size.height * 0.78), 9.0);
  }

  // Realistic Heavy Commercial Fuso Truck
  void _drawRealisticFuso(Canvas canvas, Size size) {
    final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.20)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    canvas.drawOval(Rect.fromLTWH(2, size.height - 8, size.width - 4, 7), shadowPaint);

    // Large Silver/White Cargo Container
    final boxRect = Rect.fromLTWH(size.width * 0.04, size.height * 0.12, size.width * 0.52, size.height * 0.62);
    canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(4)), Paint()..color = const Color(0xFFCBD5E1));
    canvas.drawLine(Offset(size.width * 0.08, size.height * 0.40), Offset(size.width * 0.52, size.height * 0.40), Paint()..color = const Color(0xFFEA580C)..strokeWidth = 3);

    // Fuso Orange/Red Front Cab
    final cabPath = Path();
    cabPath.moveTo(size.width * 0.56, size.height * 0.75);
    cabPath.lineTo(size.width * 0.56, size.height * 0.18);
    cabPath.lineTo(size.width * 0.80, size.height * 0.18);
    cabPath.lineTo(size.width * 0.96, size.height * 0.48);
    cabPath.lineTo(size.width * 0.96, size.height * 0.75);
    cabPath.close();
    canvas.drawPath(cabPath, Paint()..color = const Color(0xFFEA580C)); // Commercial Fuso Orange

    // Windshield
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.68, size.height * 0.22, 20, 16), const Radius.circular(2)), Paint()..color = const Color(0xFF0F172A));

    // Wheels (Triple axles)
    _drawWheel(canvas, Offset(size.width * 0.18, size.height * 0.78), 8.5);
    _drawWheel(canvas, Offset(size.width * 0.38, size.height * 0.78), 8.5);
    _drawWheel(canvas, Offset(size.width * 0.78, size.height * 0.78), 8.5);
  }

  // Realistic Scania Semi-Trailer Heavy Hauler
  void _drawRealisticScania(Canvas canvas, Size size) {
    final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.22)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(Rect.fromLTWH(2, size.height - 8, size.width - 4, 8), shadowPaint);

    // 40ft Shipping Container on Trailer
    final trailerRect = Rect.fromLTWH(size.width * 0.02, size.height * 0.10, size.width * 0.58, size.height * 0.62);
    canvas.drawRRect(RRect.fromRectAndRadius(trailerRect, const Radius.circular(4)), Paint()..color = const Color(0xFF1E3A8A)); // Deep Navy Container
    // Container ridges
    for (double x = size.width * 0.08; x < size.width * 0.56; x += 8) {
      canvas.drawLine(Offset(x, size.height * 0.12), Offset(x, size.height * 0.70), Paint()..color = Colors.white24..strokeWidth = 1.2);
    }

    // Heavy Scania Tractor Head (High cab with aero roof visor)
    final cabPath = Path();
    cabPath.moveTo(size.width * 0.60, size.height * 0.75);
    cabPath.lineTo(size.width * 0.60, size.height * 0.10);
    cabPath.lineTo(size.width * 0.82, size.height * 0.10);
    cabPath.lineTo(size.width * 0.98, size.height * 0.40);
    cabPath.lineTo(size.width * 0.98, size.height * 0.75);
    cabPath.close();
    canvas.drawPath(cabPath, Paint()..color = const Color(0xFFDC2626)); // Classic Scania Red

    // Visor and windshield
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.70, size.height * 0.16, 22, 17), const Radius.circular(2)), Paint()..color = const Color(0xFF1E293B));

    // Wheels (Heavy tandem axles)
    _drawWheel(canvas, Offset(size.width * 0.14, size.height * 0.78), 9.0);
    _drawWheel(canvas, Offset(size.width * 0.32, size.height * 0.78), 9.0);
    _drawWheel(canvas, Offset(size.width * 0.74, size.height * 0.78), 9.0);
    _drawWheel(canvas, Offset(size.width * 0.90, size.height * 0.78), 9.0);
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
    // Subtle ground shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width / 2, size.height / 2 + 2), width: 28, height: 16),
      Paint()..color = Colors.black.withValues(alpha: 0.28)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Vehicle Top-down body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: 18, height: 26),
      const Radius.circular(4),
    );
    canvas.drawRRect(bodyRect, Paint()..color = color);

    // Windshield (Black top-down glass)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width / 2 - 6, size.height / 2 - 8, 12, 5),
        const Radius.circular(1.5),
      ),
      Paint()..color = const Color(0xFF0F172A),
    );

    // Cargo bed area (back)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width / 2 - 7, size.height / 2 + 1, 14, 10),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.2),
    );

    // Headlights
    final headlightPaint = Paint()..color = const Color(0xFFFEF08A);
    canvas.drawCircle(Offset(size.width / 2 - 5, size.height / 2 - 12), 1.5, headlightPaint);
    canvas.drawCircle(Offset(size.width / 2 + 5, size.height / 2 - 12), 1.5, headlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
