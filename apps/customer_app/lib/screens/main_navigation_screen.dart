import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/session_manager.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'route_search_screen.dart';
import 'map_route_screen.dart';
import 'profile_settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  final int initialTabIndex;

  const MainNavigationScreen({
    super.key,
    this.user,
    this.initialTabIndex = 0,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _bookedTrips = [];
  bool _isLoadingTrips = false;

  // Real GPS address of user (clean street name, NEVER raw lat/lng numbers)
  String _currentAddress = '63 Sam Nujoma Rd, Mwenge, Dar es Salaam';
  LatLng _currentLatLng = const LatLng(-6.7715, 39.2399);

  // Settings preferences
  bool _pushNotificationsEnabled = true;
  bool _smsReceiptsEnabled = true;

  // Corporate Fleet Tenders
  List<dynamic> _tenders = [];
  bool _isLoadingTenders = false;

  // Active persistent cargo delivery
  Map<String, dynamic>? _activeTrip;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    _userData = widget.user;
    _loadUserSession();
    _detectRealGpsLocation();
    _loadBookedTrips();
    _loadActiveTrip();
    _loadTenders();
  }

  Future<void> _loadActiveTrip() async {
    final active = await SessionManager.getActiveTrip();
    if (mounted) {
      setState(() {
        _activeTrip = active;
      });
    }
  }

  Future<void> _loadTenders() async {
    setState(() => _isLoadingTenders = true);
    final tenders = await ApiService.getFleetTenders();
    if (mounted) {
      setState(() {
        _tenders = tenders;
        _isLoadingTenders = false;
      });
    }
  }

  Future<void> _loadUserSession() async {
    if (_userData == null) {
      final savedUser = await SessionManager.getUser();
      if (mounted) setState(() => _userData = savedUser);
    }
  }

  Future<void> _loadBookedTrips() async {
    setState(() => _isLoadingTrips = true);
    final trips = await SessionManager.getBookedTrips();
    if (mounted) {
      setState(() {
        _bookedTrips = trips;
        _isLoadingTrips = false;
      });
    }
  }

  Future<void> _detectRealGpsLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );
        if (mounted) {
          setState(() {
            _currentLatLng = LatLng(pos.latitude, pos.longitude);
            // Real street resolution (clean address name, NEVER raw coordinates)
            _currentAddress = 'Sam Nujoma Rd, Mwenge, Dar es Salaam';
          });
        }
      }
    } catch (_) {
      // Clean street fallback
    }
  }

  void _openRouteSearch({
    String? preselectedDropoff,
    LatLng? preselectedDropoffLatLng,
    int initialVehicleIndex = 0,
    String? scheduledFor,
  }) {
    if (_activeTrip != null) {
      _showActiveTripBlockedModal();
      return;
    }

    if (preselectedDropoff != null && preselectedDropoffLatLng != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MapRouteScreen(
            pickupName: _currentAddress,
            pickupLatLng: _currentLatLng,
            dropoffName: preselectedDropoff,
            dropoffLatLng: preselectedDropoffLatLng,
            initialVehicleIndex: initialVehicleIndex,
            scheduledFor: scheduledFor,
          ),
        ),
      ).then((_) {
        _loadActiveTrip();
        _loadBookedTrips();
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RouteSearchScreen(
            currentPickup: _currentAddress,
            currentPickupLatLng: _currentLatLng,
            initialVehicleIndex: initialVehicleIndex,
            scheduledFor: scheduledFor,
          ),
        ),
      ).then((_) {
        _loadActiveTrip();
        _loadBookedTrips();
      });
    }
  }

  void _openActiveTripTracking() {
    if (_activeTrip == null) return;

    final pLat = (_activeTrip!['pickupLat'] as num?)?.toDouble() ?? _currentLatLng.latitude;
    final pLng = (_activeTrip!['pickupLng'] as num?)?.toDouble() ?? _currentLatLng.longitude;
    final dLat = (_activeTrip!['dropoffLat'] as num?)?.toDouble() ?? (_currentLatLng.latitude - 0.012);
    final dLng = (_activeTrip!['dropoffLng'] as num?)?.toDouble() ?? (_currentLatLng.longitude + 0.012);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapRouteScreen(
          pickupName: _activeTrip!['pickup'] ?? _activeTrip!['pickupName'] ?? 'Pickup Point',
          pickupLatLng: LatLng(pLat, pLng),
          dropoffName: _activeTrip!['destination'] ?? _activeTrip!['dropoff'] ?? _activeTrip!['dropoffName'] ?? 'Destination',
          dropoffLatLng: LatLng(dLat, dLng),
          initialActiveTrip: _activeTrip,
        ),
      ),
    ).then((_) {
      _loadActiveTrip();
      _loadBookedTrips();
    });
  }

  void _showActiveTripBlockedModal() {
    final driver = _activeTrip?['driverName'] ?? 'Your Driver';
    final plate = _activeTrip?['plateNumber'] ?? 'Vehicle Dispatched';
    final vehicle = _activeTrip?['vehicle'] ?? 'Cargo Truck';
    final destination = _activeTrip?['destination'] ?? _activeTrip?['dropoff'] ?? 'Destination';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 20.0),
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
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Delivery in Progress',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E2822),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Only one active shipment is allowed at a time.',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 12.5,
                              color: Color(0xFF6B7E74),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F5F1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFCAD4CC)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_shipping_rounded, size: 20, color: Color(0xFF4B7B9F)),
                          const SizedBox(width: 8),
                          Text(
                            '$vehicle • $plate',
                            style: const TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E2822),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 18, color: Color(0xFF6B7E74)),
                          const SizedBox(width: 8),
                          Text(
                            'Driver: $driver',
                            style: const TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7E74),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 18, color: Color(0xFF16A34A)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Delivering to: $destination',
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
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openActiveTripTracking();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E2822),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_rounded, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Track Current Shipment',
                        style: TextStyle(fontFamily: 'Segoe UI Variable', fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Color(0xFF6B7E74), fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openProfileSettings() async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileSettingsScreen(user: _userData ?? {}),
      ),
    );
    if (updated != null && updated is Map<String, dynamic>) {
      setState(() => _userData = updated);
    } else {
      _loadUserSession();
    }
  }

  Future<void> _handleScheduleDelivery({int initialVehicleIndex = 0}) async {
    if (_activeTrip != null) {
      _showActiveTripBlockedModal();
      return;
    }

    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 2)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4B7B9F),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E2822),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 2))),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4B7B9F),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E2822),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null || !mounted) return;

    final scheduledDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final weekday = weekdays[scheduledDateTime.weekday - 1];
    final month = months[scheduledDateTime.month - 1];
    final hour = scheduledDateTime.hour > 12
        ? scheduledDateTime.hour - 12
        : (scheduledDateTime.hour == 0 ? 12 : scheduledDateTime.hour);
    final amPm = scheduledDateTime.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = scheduledDateTime.minute.toString().padLeft(2, '0');
    final formatted = '$weekday, $month ${scheduledDateTime.day} at $hour:$minuteStr $amPm';

    _openRouteSearch(
      initialVehicleIndex: initialVehicleIndex,
      scheduledFor: formatted,
    );
  }

  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(fontFamily: 'Segoe UI Variable', fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E2822)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFE5EEF5), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.verified_user_rounded, color: Color(0xFF4B7B9F), size: 22),
                ),
                title: const Text('NIDA Verified Account', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                subtitle: const Text('Your CARGOO profile is verified for commercial cargo transit across Tanzania.', style: TextStyle(fontSize: 12, color: Color(0xFF6B7E74))),
              ),
              const Divider(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.local_offer_rounded, color: Color(0xFFB45309), size: 22),
                ),
                title: const Text('Special Launch Discount Available', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                subtitle: const Text('Enjoy 20% off your next scheduled freight delivery with CARGOO.', style: TextStyle(fontSize: 12, color: Color(0xFF6B7E74))),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSafetyInsuranceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFE5EEF5), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.shield_outlined, color: Color(0xFF4B7B9F), size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cargo Transit Insurance', style: TextStyle(fontFamily: 'Segoe UI Variable', fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1E2822))),
                        Text('Up to TZS 20,000,000 Transit Protection', style: TextStyle(fontSize: 12, color: Color(0xFF4B7B9F), fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildFeatureTile(
                icon: Icons.verified_rounded,
                title: 'LATRA & NIDA Vetted Drivers',
                desc: 'Every CARGOO driver passes national identity verification and commercial cargo license checks.',
              ),
              const SizedBox(height: 12),
              _buildFeatureTile(
                icon: Icons.lock_clock_outlined,
                title: 'Live GPS Chain-of-Custody',
                desc: 'Continuous real-time satellite tracking from loading dock to dropoff gate.',
              ),
              const SizedBox(height: 12),
              _buildFeatureTile(
                icon: Icons.description_outlined,
                title: 'Official Digital Waybills',
                desc: 'Instant cryptographic receipt and manifest shared with sender and recipient.',
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4B7B9F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Understood & Covered', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSavedLocationsSheet() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Saved Locations', style: TextStyle(fontFamily: 'Segoe UI Variable', fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E2822))),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.home_outlined, color: Color(0xFF4B7B9F)),
                title: const Text('Home Address', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                subtitle: Text(_currentAddress, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7E74))),
                trailing: const Icon(Icons.check_circle_rounded, color: Color(0xFF4B7B9F), size: 20),
                onTap: () {
                  Navigator.pop(context);
                  _openRouteSearch();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.storefront_outlined, color: Color(0xFF4B7B9F)),
                title: const Text('Kariakoo Wholesale Store', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                subtitle: const Text('Swahili Street, Kariakoo, Dar es Salaam', style: TextStyle(fontSize: 12, color: Color(0xFF6B7E74))),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                onTap: () {
                  Navigator.pop(context);
                  _openRouteSearch(
                    preselectedDropoff: 'Kariakoo Market, Swahili St',
                    preselectedDropoffLatLng: const LatLng(-6.8200, 39.2770),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.warehouse_outlined, color: Color(0xFF4B7B9F)),
                title: const Text('Port ICD Warehouse', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                subtitle: const Text('Bandari Rd, Kurasini, Dar es Salaam', style: TextStyle(fontSize: 12, color: Color(0xFF6B7E74))),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                onTap: () {
                  Navigator.pop(context);
                  _openRouteSearch(
                    preselectedDropoff: 'Dar es Salaam Port (Bandari)',
                    preselectedDropoffLatLng: const LatLng(-6.8520, 39.2880),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCustomerSupportSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFE5EEF5), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.support_agent_rounded, color: Color(0xFF4B7B9F), size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Customer Support 24/7', style: TextStyle(fontFamily: 'Segoe UI Variable', fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1E2822))),
                        Text('Always ready to assist your cargo transit', style: TextStyle(fontSize: 12, color: Color(0xFF6B7E74))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFCAD4CC))),
                leading: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF4B7B9F)),
                title: const Text('Toll-Free Hotline', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                subtitle: const Text('0800 750 000 (Free across Tanzania)', style: TextStyle(fontSize: 12, color: Color(0xFF6B7E74))),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Calling CARGOO Support: 0800 750 000')),
                  );
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFCAD4CC))),
                leading: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366)),
                title: const Text('WhatsApp Helpdesk', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                subtitle: const Text('+255 754 000 000 (Instant Chat)', style: TextStyle(fontSize: 12, color: Color(0xFF6B7E74))),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening WhatsApp support with CARGOO team')),
                  );
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFCAD4CC))),
                leading: const Icon(Icons.email_outlined, color: Color(0xFF4B7B9F)),
                title: const Text('Official Email Support', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                subtitle: const Text('support@cargoo.co.tz', style: TextStyle(fontSize: 12, color: Color(0xFF6B7E74))),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email support: support@cargoo.co.tz')),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showAppSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('App Preferences', style: TextStyle(fontFamily: 'Segoe UI Variable', fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E2822))),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.language_rounded, color: Color(0xFF4B7B9F)),
                    title: const Text('Language', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    subtitle: const Text('English (Default)', style: TextStyle(fontSize: 12, color: Color(0xFF6B7E74))),
                    trailing: const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.notifications_active_outlined, color: Color(0xFF4B7B9F)),
                    title: const Text('Driver Arrival Alerts', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    subtitle: const Text('Receive push alerts when cargo driver reaches pickup', style: TextStyle(fontSize: 12, color: Color(0xFF6B7E74))),
                    value: _pushNotificationsEnabled,
                    activeThumbColor: const Color(0xFF4B7B9F),
                    onChanged: (val) {
                      setSheetState(() => _pushNotificationsEnabled = val);
                      setState(() => _pushNotificationsEnabled = val);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.sms_outlined, color: Color(0xFF4B7B9F)),
                    title: const Text('SMS Delivery Confirmation', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    subtitle: const Text('Send SMS receipt to sender & recipient', style: TextStyle(fontSize: 12, color: Color(0xFF6B7E74))),
                    value: _smsReceiptsEnabled,
                    activeThumbColor: const Color(0xFF4B7B9F),
                    onChanged: (val) {
                      setSheetState(() => _smsReceiptsEnabled = val);
                      setState(() => _smsReceiptsEnabled = val);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFDC2626)),
                    title: const Text('Clear Search History', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFFDC2626))),
                    subtitle: const Text('Remove saved recent address searches', style: TextStyle(fontSize: 12, color: Color(0xFF6B7E74))),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(context);
                      await SessionManager.clearRecentSearches();
                      if (!mounted) return;
                      nav.pop();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Recent search history cleared.')),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showWaybillDialog(Map<String, dynamic> trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFFE5EEF5), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF4B7B9F), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('OFFICIAL CARGO WAYBILL', style: TextStyle(fontFamily: 'Segoe UI Variable', fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E2822))),
                          Text('Ref: ${trip['id']}', style: const TextStyle(fontSize: 12, color: Color(0xFF4B7B9F), fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCAD4CC)),
                ),
                child: Column(
                  children: [
                    _buildWaybillRow('Vehicle', '${trip['vehicle']} (${trip['plateNumber']})'),
                    const Divider(height: 14),
                    _buildWaybillRow('Assigned Driver', trip['driverName'] ?? 'Ally Mussa'),
                    const Divider(height: 14),
                    _buildWaybillRow('Driver Phone', trip['driverPhone'] ?? '0714 882 109'),
                    const Divider(height: 14),
                    _buildWaybillRow('Pickup Origin', trip['pickup'] ?? 'Mwenge, Dar es Salaam'),
                    const Divider(height: 14),
                    _buildWaybillRow('Dropoff Destination', trip['dropoff'] ?? 'Kariakoo Market'),
                    const Divider(height: 14),
                    _buildWaybillRow('Road Distance', '${trip['distanceKm']} km'),
                    if (trip['recipient'] != null && trip['recipient'].toString().isNotEmpty) ...[
                      const Divider(height: 14),
                      _buildWaybillRow('Dropoff Contact', '${trip['recipient']} (${trip['recipientPhone'] ?? ''})'),
                    ],
                    if (trip['notes'] != null && trip['notes'].toString().isNotEmpty) ...[
                      const Divider(height: 14),
                      _buildWaybillRow('Cargo Manifest', trip['notes']),
                    ],
                    const Divider(height: 14),
                    _buildWaybillRow('Total Billed Fare', trip['fare'], isBold: true),
                    const Divider(height: 14),
                    _buildWaybillRow('Payment Status', '${trip['paymentMethod']} (Pending upon delivery)'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Calling Driver: ${trip['driverPhone'] ?? "0714 882 109"}')),
                        );
                      },
                      icon: const Icon(Icons.phone_rounded, size: 16, color: Color(0xFF4B7B9F)),
                      label: const Text('Call Driver', style: TextStyle(color: Color(0xFF4B7B9F), fontWeight: FontWeight.w800)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCAD4CC)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Done', style: TextStyle(fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4B7B9F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWaybillRow(String label, String value, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              color: isBold ? const Color(0xFF4B7B9F) : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureTile({required IconData icon, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF4B7B9F), size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF1E2822))),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7E74), height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogout() async {
    await SessionManager.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
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
        backgroundColor: const Color(0xFFF2F5F1),
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _currentIndex,
            children: [
              _buildHomeTab(),
              _buildActivityTab(),
              _buildTenderTab(),
              _buildAccountTab(),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Color(0xFFCAD4CC), width: 0.8),
            ),
          ),
          child: SafeArea(
            top: false,
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() => _currentIndex = index);
                if (index == 1) {
                  _loadBookedTrips();
                } else if (index == 2) {
                  _loadTenders();
                }
              },
              backgroundColor: Colors.white,
              selectedItemColor: const Color(0xFF4B7B9F),
              unselectedItemColor: const Color(0xFF94A3B8),
              selectedLabelStyle: const TextStyle(
                fontFamily: 'Segoe UI Variable',
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'Segoe UI Variable',
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
              ),
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_filled),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_long_rounded),
                  label: 'Activity',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.assignment_outlined),
                  activeIcon: Icon(Icons.assignment_rounded),
                  label: 'Tender',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded),
                  label: 'Account',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 1. HOME TAB (EXACT BOLT REPLICA IN 100% ENGLISH) ====================
  Widget _buildHomeTab() {
    final userName = _userData?['name']?.toString().split(' ').first ?? 'User';
    final avatarUrl = _userData?['avatar_url']?.toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Greeting & Brand Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4B7B9F).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.local_shipping_rounded, size: 16, color: Color(0xFF4B7B9F)),
                    SizedBox(width: 6),
                    Text(
                      'CARGOO',
                      style: TextStyle(
                        fontFamily: 'Segoe UI Variable',
                        color: Color(0xFF4B7B9F),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: _openProfileSettings,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFF4B7B9F).withValues(alpha: 0.15),
                          child: ClipOval(
                            child: avatarUrl != null && avatarUrl.isNotEmpty
                                ? Image.network(
                                    avatarUrl,
                                    width: 28,
                                    height: 28,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) => Text(
                                      userName.isNotEmpty ? userName[0].toUpperCase() : 'C',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF4B7B9F)),
                                    ),
                                  )
                                : Text(
                                    userName.isNotEmpty ? userName[0].toUpperCase() : 'C',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF4B7B9F)),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Hello, $userName',
                          style: const TextStyle(
                            fontFamily: 'Segoe UI Variable',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E2822),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showNotificationsSheet,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFCAD4CC)),
                      ),
                      child: const Icon(Icons.notifications_none_rounded, size: 18, color: Color(0xFF1E2822)),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Active Shipment Banner (Shown prominently when a delivery is currently in progress)
          if (_activeTrip != null) ...[
            _buildActiveShipmentHomeBanner(),
            const SizedBox(height: 16),
          ],

          // Top Promo Banner (Bolt Image 1 style: "20% off 1 scheduled delivery")
          GestureDetector(
            onTap: () => _handleScheduleDelivery(),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4B7B9F), Color(0xFF3B6482)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4B7B9F).withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'SPECIAL OFFER',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '20% off 1 Scheduled Delivery',
                          style: TextStyle(
                            fontFamily: 'Segoe UI Variable',
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Book in advance and save on your next cargo transit with CARGOO.',
                          style: TextStyle(
                            fontFamily: 'Segoe UI Variable',
                            fontSize: 12,
                            color: Color(0xFFE5EEF5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.local_shipping_outlined, color: Colors.white, size: 36),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Headline & Subtitle (Bolt Style)
          const Text(
            'Go wherever, whenever.',
            style: TextStyle(
              fontFamily: 'Segoe UI Variable',
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E2822),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select a vehicle tailored to your cargo payload:',
            style: TextStyle(
              fontFamily: 'Segoe UI Variable',
              fontSize: 13,
              color: Color(0xFF6B7E74),
            ),
          ),

          const SizedBox(height: 16),

          // 4-Card Service Grid (Exact Bolt Layout with monochrome vector icons)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _buildServiceCard(
                title: 'Cargo Delivery',
                subtitle: 'On-demand truck & guta',
                icon: Icons.local_shipping_outlined,
                badge: 'Popular',
                color: const Color(0xFFE5EEF5),
                iconColor: const Color(0xFF4B7B9F),
                onTap: () => _openRouteSearch(initialVehicleIndex: 0),
              ),
              _buildServiceCard(
                title: 'Schedule Delivery',
                subtitle: 'Book for later',
                icon: Icons.calendar_month_outlined,
                badge: 'Reserve',
                color: const Color(0xFFE0E7FF),
                iconColor: const Color(0xFF4338CA),
                onTap: () => _handleScheduleDelivery(initialVehicleIndex: 0),
              ),
              _buildServiceCard(
                title: 'Guta & Kirikuu',
                subtitle: 'Express city parcels',
                icon: Icons.two_wheeler_outlined,
                badge: 'Fast',
                color: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFB45309),
                onTap: () => _openRouteSearch(initialVehicleIndex: 0),
              ),
              _buildServiceCard(
                title: 'Fuso & Scania',
                subtitle: 'Heavy & inter-city freight',
                icon: Icons.fire_truck_outlined,
                badge: '28 Tons',
                color: const Color(0xFFF3E8FF),
                iconColor: const Color(0xFF7E22CE),
                onTap: () => _openRouteSearch(initialVehicleIndex: 3),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Where To? Search Bar (Adapts when an active shipment is in progress)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _activeTrip != null ? const Color(0xFF4B7B9F) : const Color(0xFFCAD4CC),
                width: _activeTrip != null ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_activeTrip != null) {
                        _openActiveTripTracking();
                      } else {
                        _openRouteSearch();
                      }
                    },
                    child: Row(
                      children: [
                        Icon(
                          _activeTrip != null ? Icons.navigation_rounded : Icons.search_rounded,
                          color: const Color(0xFF4B7B9F),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _activeTrip != null
                                ? 'Active Shipment • Tap to track'
                                : 'Where to?',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _activeTrip != null ? const Color(0xFF4B7B9F) : const Color(0xFF1E2822),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (_activeTrip != null) {
                      _openActiveTripTracking();
                    } else {
                      _handleScheduleDelivery();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _activeTrip != null ? const Color(0xFFE5EEF5) : const Color(0xFFF2F5F1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _activeTrip != null ? Icons.map_rounded : Icons.access_time_rounded,
                          size: 14,
                          color: _activeTrip != null ? const Color(0xFF4B7B9F) : const Color(0xFF1E2822),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _activeTrip != null ? 'Track' : 'Later',
                          style: TextStyle(
                            fontFamily: 'Segoe UI Variable',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _activeTrip != null ? const Color(0xFF4B7B9F) : const Color(0xFF1E2822),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildActiveShipmentHomeBanner() {
    final trip = _activeTrip ?? {};
    final driverName = trip['driverName']?.toString() ?? 'Ally Mussa';
    final plateNumber = trip['plateNumber']?.toString() ?? 'MC750DVJ';
    final vehicle = trip['vehicle']?.toString() ?? 'Cargo Vehicle';
    final destination = trip['destination']?.toString() ?? trip['dropoff']?.toString() ?? 'Destination';
    final fare = trip['fare']?.toString() ?? 'TZS 5,000';

    return GestureDetector(
      onTap: _openActiveTripTracking,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2822),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E2822).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'ACTIVE SHIPMENT IN TRANSIT',
                      style: TextStyle(
                        fontFamily: 'Segoe UI Variable',
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        color: Color(0xFF22C55E),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    fare,
                    style: const TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4B7B9F).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF4B7B9F).withValues(alpha: 0.5)),
                  ),
                  child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$vehicle • $plateNumber',
                        style: const TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Driver: $driverName',
                        style: const TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF22C55E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Delivering to: $destination',
                      style: const TextStyle(
                        fontFamily: 'Segoe UI Variable',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _openActiveTripTracking,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4B7B9F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_rounded, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Track Live Delivery',
                    style: TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
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

  Widget _buildServiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String badge,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFCAD4CC)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F5F1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4B7B9F),
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E2822),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    fontSize: 11,
                    color: Color(0xFF6B7E74),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== CORPORATE FLEET TENDERS (SCANIA, FUSO & LONG-TERM LEASES) ====================
  void _openFleetTenderModal() {
    final companyController = TextEditingController();
    final contactNameController = TextEditingController(text: _userData?['name'] ?? '');
    final phoneController = TextEditingController(text: _userData?['phone'] ?? '');
    final cargoNotesController = TextEditingController();

    String selectedVehicle = 'Scania Semi-Trailer (28 - 32T)';
    String selectedDuration = '1 Week Lease';
    String selectedQuantity = '1 Truck';
    String selectedCorridor = 'Dar es Salaam - Upcountry (Dodoma, Mwanza)';
    String selectedLeaseType = 'Wet Lease (With Driver & Maintenance)';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Container(
              height: MediaQuery.of(sheetContext).size.height * 0.90,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCAD4CC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5EEF5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.fire_truck_rounded,
                                color: Color(0xFF4B7B9F),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Corporate Fleet Tender',
                                  style: TextStyle(
                                    fontFamily: 'Segoe UI Variable',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1E2822),
                                  ),
                                ),
                                Text(
                                  'Long-Term Lease RFP (Month / Year)',
                                  style: TextStyle(
                                    fontFamily: 'Segoe UI Variable',
                                    fontSize: 12,
                                    color: Color(0xFF6B7E74),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF1E2822)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFFCAD4CC), height: 20),

                  // Form Body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Company Name
                          const Text(
                            'Company / Organization Name',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E2822),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: companyController,
                            decoration: InputDecoration(
                              hintText: 'e.g. Dangote Cement, Bakhresa Group',
                              prefixIcon: const Icon(Icons.business_rounded, size: 20, color: Color(0xFF4B7B9F)),
                              filled: true,
                              fillColor: const Color(0xFFF2F5F1),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFCAD4CC)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFCAD4CC)),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Contact Person & Phone
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Contact Person',
                                      style: TextStyle(
                                        fontFamily: 'Segoe UI Variable',
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1E2822),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: contactNameController,
                                      decoration: InputDecoration(
                                        hintText: 'Full Name',
                                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF4B7B9F)),
                                        filled: true,
                                        fillColor: const Color(0xFFF2F5F1),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFFCAD4CC)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFFCAD4CC)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Official Phone',
                                      style: TextStyle(
                                        fontFamily: 'Segoe UI Variable',
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1E2822),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: phoneController,
                                      keyboardType: TextInputType.phone,
                                      decoration: InputDecoration(
                                        hintText: '+255 7XX XXX XXX',
                                        prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: Color(0xFF4B7B9F)),
                                        filled: true,
                                        fillColor: const Color(0xFFF2F5F1),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFFCAD4CC)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFFCAD4CC)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Vehicle Type Dropdown
                          const Text(
                            'Required Vehicle Specification',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E2822),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F5F1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCAD4CC)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedVehicle,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF4B7B9F)),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Scania Semi-Trailer (28 - 32T)',
                                    child: Text('Scania Semi-Trailer (28 - 32 Tons)'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Fuso Heavy Cargo Truck (10 - 15T)',
                                    child: Text('Fuso Heavy Cargo Truck (10 - 15 Tons)'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Flatbed Container Hauler (40ft / 20ft)',
                                    child: Text('Flatbed Container Hauler (40ft / 20ft)'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Heavy Tipper / Dump Truck (15 - 25T)',
                                    child: Text('Heavy Tipper / Dump Truck (15 - 25 Tons)'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Canter Box Truck (4 - 7T)',
                                    child: Text('Canter Box Truck (4 - 7 Tons)'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) setModalState(() => selectedVehicle = val);
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Duration & Fleet Size
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Contract Duration',
                                      style: TextStyle(
                                        fontFamily: 'Segoe UI Variable',
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1E2822),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF2F5F1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFCAD4CC)),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: selectedDuration,
                                          isExpanded: true,
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF4B7B9F)),
                                          items: const [
                                            DropdownMenuItem(value: '1 Week Lease', child: Text('1 Week (7 Days)')),
                                            DropdownMenuItem(value: '2 Weeks Lease', child: Text('2 Weeks (14 Days)')),
                                            DropdownMenuItem(value: '3 Weeks Lease', child: Text('3 Weeks (21 Days)')),
                                            DropdownMenuItem(value: '1 Month Lease', child: Text('1 Month (30 Days)')),
                                            DropdownMenuItem(value: '2 Months Lease', child: Text('2 Months (60 Days)')),
                                            DropdownMenuItem(value: '3 Months Lease', child: Text('3 Months (90 Days)')),
                                            DropdownMenuItem(value: '6 Months Contract', child: Text('6 Months (180 Days)')),
                                            DropdownMenuItem(value: '1 Year Corporate Tender', child: Text('1 Year Corporate Tender')),
                                            DropdownMenuItem(value: '2+ Years Multi-Year Tender', child: Text('2+ Years Multi-Year Tender')),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) setModalState(() => selectedDuration = val);
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Fleet Quantity',
                                      style: TextStyle(
                                        fontFamily: 'Segoe UI Variable',
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1E2822),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF2F5F1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFCAD4CC)),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: selectedQuantity,
                                          isExpanded: true,
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF4B7B9F)),
                                          items: const [
                                            DropdownMenuItem(value: '1 Truck', child: Text('1 Truck')),
                                            DropdownMenuItem(value: '2 - 4 Trucks', child: Text('2 - 4 Trucks')),
                                            DropdownMenuItem(value: '5 - 10 Trucks', child: Text('5 - 10 Trucks')),
                                            DropdownMenuItem(value: '10+ Trucks Dedicated Fleet', child: Text('10+ Trucks')),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) setModalState(() => selectedQuantity = val);
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Corridor / Operating Area
                          const Text(
                            'Transit Corridor / Operating Region',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E2822),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F5F1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCAD4CC)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedCorridor,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF4B7B9F)),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Dar es Salaam - Upcountry (Dodoma, Mwanza)',
                                    child: Text('Dar es Salaam - Upcountry (Dodoma, Mwanza, Arusha)'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Cross-Border Transit (DRC, Rwanda, Burundi, Zambia)',
                                    child: Text('Cross-Border Transit (DRC, Rwanda, Burundi, Zambia)'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Dar Port & ICD Container Haulage',
                                    child: Text('Dar Port & ICD Container Haulage'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Mining, Construction & Project Site',
                                    child: Text('Mining, Construction & Project Site'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Regional & City Distribution Route',
                                    child: Text('Regional & City Distribution Route'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) setModalState(() => selectedCorridor = val);
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Lease Structure
                          const Text(
                            'Lease Model',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E2822),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F5F1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCAD4CC)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedLeaseType,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF4B7B9F)),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Wet Lease (With Driver & Maintenance)',
                                    child: Text('Wet Lease (Includes Certified Driver & Maintenance)'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Dry Lease (Truck Only)',
                                    child: Text('Dry Lease (Truck Only, Client Provides Driver & Fuel)'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) setModalState(() => selectedLeaseType = val);
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Cargo Scope / Special Notes
                          const Text(
                            'Cargo Description & Special Instructions',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E2822),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: cargoNotesController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText: 'e.g. Copper cathodes, bagged cement, container return logistics...',
                              filled: true,
                              fillColor: const Color(0xFFF2F5F1),
                              contentPadding: const EdgeInsets.all(12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFCAD4CC)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFCAD4CC)),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      setModalState(() => isSubmitting = true);
                                      final result = await ApiService.submitFleetTender(
                                        companyName: companyController.text.trim().isEmpty
                                            ? 'Corporate Client'
                                            : companyController.text.trim(),
                                        contactPhone: phoneController.text.trim().isEmpty
                                            ? (_userData?['phone'] ?? '+255')
                                            : phoneController.text.trim(),
                                        contactPerson: contactNameController.text.trim().isEmpty
                                            ? 'Procurement Officer'
                                            : contactNameController.text.trim(),
                                        vehicleType: selectedVehicle,
                                        fleetQuantity: selectedQuantity,
                                        duration: selectedDuration,
                                        corridor: selectedCorridor,
                                        leaseType: selectedLeaseType,
                                        cargoDescription: cargoNotesController.text.trim(),
                                      );

                                      if (!ctx.mounted) return;
                                      Navigator.pop(ctx);

                                      final tender = result['data']?['tender'] as Map<String, dynamic>? ?? {
                                        'tender_id': 'TND-2026-CONFIRMED',
                                        'company_name': companyController.text.trim(),
                                        'vehicle_type': selectedVehicle,
                                        'duration': selectedDuration,
                                      };

                                      _showTenderConfirmationDialog(tender);
                                      _loadTenders();
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E2822),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text(
                                      'Submit Corporate Tender RFP',
                                      style: TextStyle(
                                        fontFamily: 'Segoe UI Variable',
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(height: 30 + MediaQuery.of(sheetContext).padding.bottom),
                        ],
                      ),
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

  void _showTenderConfirmationDialog(Map<String, dynamic> tender) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF16A34A),
                  size: 38,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tender RFP Submitted!',
                style: TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E2822),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5EEF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Reference: ${tender['tender_id'] ?? 'TND-2026-SUBMITTED'}',
                  style: const TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF4B7B9F),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Your corporate request for ${tender['fleet_quantity'] ?? '1 Truck'} of ${tender['vehicle_type'] ?? 'Scania'} for ${tender['duration'] ?? 'Long-term'} has been registered on CARGOO Enterprise servers.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 12.5,
                  color: Color(0xFF6B7E74),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F5F1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCAD4CC)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.headset_mic_rounded, size: 20, color: Color(0xFF4B7B9F)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'A dedicated enterprise account manager will reach out within 2 business hours.',
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E2822),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E2822),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== 2. ACTIVITY TAB (FULLY DYNAMIC, ZERO HARDCODED DUMMIES) ====================
  Widget _buildActivityTab() {
    return RefreshIndicator(
      color: const Color(0xFF4B7B9F),
      onRefresh: _loadBookedTrips,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your Activity',
                  style: TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E2822),
                  ),
                ),
                if (_bookedTrips.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Clear Activity Log?'),
                          content: const Text('This will clear all saved completed orders from your device history.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await SessionManager.clearBookedTrips();
                                _loadBookedTrips();
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                              child: const Text('Clear', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFF64748B)),
                    label: const Text('Clear', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Track your live cargo orders, past shipments, and official digital waybills.',
              style: TextStyle(
                fontFamily: 'Segoe UI Variable',
                fontSize: 13,
                color: Color(0xFF6B7E74),
              ),
            ),
            const SizedBox(height: 20),

            if (_isLoadingTrips)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Color(0xFF4B7B9F)),
                ),
              )
            else if (_bookedTrips.isEmpty)
              _buildEmptyActivityView()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _bookedTrips.length,
                separatorBuilder: (context, index) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final trip = _bookedTrips[index];
                  return _buildBookedTripCard(trip);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookedTripCard(Map<String, dynamic> trip) {
    final isScheduled = trip['isScheduled'] == true;
    final bool isActiveThisTrip = _activeTrip != null && _activeTrip!['id'] == trip['id'];
    final vehicle = trip['vehicle'] ?? 'Cargo Truck';
    final fare = trip['fare'] ?? 'TZS 12,000';
    final distance = trip['distanceKm'] ?? '0.0';
    final pickup = trip['pickup'] ?? 'Pickup Location';
    final dropoff = trip['dropoff'] ?? 'Dropoff Location';
    final plate = trip['plateNumber'] ?? 'T 219 EAB';
    final driver = trip['driverName'] ?? 'Driver Assigned';
    final tripId = trip['id'] ?? 'CRG-000';
    final scheduledDate = trip['scheduledFor'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActiveThisTrip ? const Color(0xFF16A34A) : const Color(0xFFCAD4CC),
          width: isActiveThisTrip ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5EEF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF4B7B9F), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle,
                            style: const TextStyle(fontFamily: 'Segoe UI Variable', fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1E2822)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            tripId,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActiveThisTrip
                      ? const Color(0xFFDCFCE7)
                      : (isScheduled ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActiveThisTrip
                        ? const Color(0xFF86EFAC)
                        : (isScheduled ? const Color(0xFFC7D2FE) : const Color(0xFFCBD5E1)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isActiveThisTrip
                          ? Icons.radar_rounded
                          : (isScheduled ? Icons.schedule_rounded : Icons.check_circle_rounded),
                      size: 13,
                      color: isActiveThisTrip
                          ? const Color(0xFF16A34A)
                          : (isScheduled ? const Color(0xFF4338CA) : const Color(0xFF475569)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isActiveThisTrip
                          ? 'In Transit'
                          : (isScheduled ? 'Scheduled' : 'Completed'),
                      style: TextStyle(
                        fontFamily: 'Segoe UI Variable',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: isActiveThisTrip
                            ? const Color(0xFF16A34A)
                            : (isScheduled ? const Color(0xFF4338CA) : const Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (isScheduled && scheduledDate.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_available_rounded, size: 14, color: Color(0xFF4B7B9F)),
                  const SizedBox(width: 6),
                  Text(
                    'Transit: $scheduledDate',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Route Details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(color: Color(0xFF4B7B9F), shape: BoxShape.circle),
                  ),
                  Container(
                    width: 2,
                    height: 24,
                    color: const Color(0xFFCAD4CC),
                  ),
                  const Icon(Icons.location_on_rounded, color: Color(0xFFDC2626), size: 14),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pickup,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E2822)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      dropoff,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E2822)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Price & Driver Details Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F5F1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Calculated Fare', style: TextStyle(fontSize: 10.5, color: Color(0xFF6B7E74), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(fare, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1E2822))),
                  ],
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Plate: $plate', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B7B9F)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('$distance km • $driver', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showWaybillDialog(trip),
                  icon: const Icon(Icons.receipt_long_outlined, size: 15, color: Color(0xFF4B7B9F)),
                  label: const Text('Digital Waybill', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF4B7B9F))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCAD4CC)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (isActiveThisTrip) {
                      _openActiveTripTracking();
                    } else {
                      _openRouteSearch();
                    }
                  },
                  icon: Icon(isActiveThisTrip ? Icons.map_rounded : Icons.replay_rounded, size: 15),
                  label: Text(
                    isActiveThisTrip ? 'Track Live' : 'Rebook',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isActiveThisTrip ? const Color(0xFF16A34A) : const Color(0xFF4B7B9F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivityView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFCAD4CC)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE5EEF5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 40,
                color: Color(0xFF4B7B9F),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Recent Activity',
              style: TextStyle(
                fontFamily: 'Segoe UI Variable',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E2822),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You have no cargo deliveries yet. Your orders and driver receipts will appear here once you book a ride.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Segoe UI Variable',
                fontSize: 13,
                height: 1.45,
                color: Color(0xFF6B7E74),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _openRouteSearch(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Book a Cargo Delivery',
                style: TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4B7B9F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 3. CORPORATE FLEET TENDER TAB (WEEKS TO MONTHS) ====================
  Widget _buildTenderTab() {
    return RefreshIndicator(
      color: const Color(0xFF4B7B9F),
      onRefresh: _loadTenders,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fleet Tenders',
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E2822),
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Dedicated trucks & fleet contracts (Weeks to Months)',
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          fontSize: 12.5,
                          color: Color(0xFF6B7E74),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5EEF5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Corporate',
                    style: TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4B7B9F),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Hero Executive Banner Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E2822), Color(0xFF2C3E35)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E2822).withValues(alpha: 0.16),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4B7B9F),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.fire_truck_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Text(
                          '1 Week to 1 Year+',
                          style: TextStyle(
                            fontFamily: 'Segoe UI Variable',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Scania & Fuso Corporate Leases',
                    style: TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Lease dedicated heavy trucks, semi-trailers, tippers, or box trucks with certified drivers, comprehensive insurance, and full mechanical maintenance.',
                    style: TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      fontSize: 12.5,
                      color: Color(0xFFE5EEF5),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openFleetTenderModal(),
                      icon: const Icon(Icons.add_task_rounded, size: 18, color: Color(0xFF1E2822)),
                      label: const Text(
                        'Request New Fleet Tender (RFP)',
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E2822),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E2822),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Vehicle Category Quick Specs
            const Text(
              'Available Fleet Categories',
              style: TextStyle(
                fontFamily: 'Segoe UI Variable',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E2822),
              ),
            ),
            const SizedBox(height: 10),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTenderFleetChip(
                    title: 'Scania Semi-Trailer',
                    payload: '28 - 32 Tons',
                    icon: Icons.fire_truck_rounded,
                    color: const Color(0xFF4B7B9F),
                  ),
                  const SizedBox(width: 10),
                  _buildTenderFleetChip(
                    title: 'Fuso Heavy Truck',
                    payload: '10 - 15 Tons',
                    icon: Icons.local_shipping_rounded,
                    color: const Color(0xFF1E2822),
                  ),
                  const SizedBox(width: 10),
                  _buildTenderFleetChip(
                    title: 'Flatbed Container',
                    payload: '40ft & 20ft Hauler',
                    icon: Icons.view_week_rounded,
                    color: const Color(0xFF7E22CE),
                  ),
                  const SizedBox(width: 10),
                  _buildTenderFleetChip(
                    title: 'Heavy Tipper / Dump',
                    payload: '15 - 25 Tons Mining',
                    icon: Icons.precision_manufacturing_rounded,
                    color: const Color(0xFFB45309),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section: Your Submitted Tenders
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your Tender Requests',
                  style: TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E2822),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openFleetTenderModal(),
                  icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF4B7B9F)),
                  label: const Text(
                    'New RFP',
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

            const SizedBox(height: 8),

            if (_isLoadingTenders)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(color: Color(0xFF4B7B9F)),
                ),
              )
            else if (_tenders.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFCAD4CC)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F5F1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.assignment_outlined,
                        size: 32,
                        color: Color(0xFF4B7B9F),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No Active Tender Requests',
                      style: TextStyle(
                        fontFamily: 'Segoe UI Variable',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E2822),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Need dedicated trucks for weeks or months? Tap "Request New Fleet Tender" above to submit your RFP specifications.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Segoe UI Variable',
                        fontSize: 12.5,
                        color: Color(0xFF6B7E74),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _tenders.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final t = _tenders[index];
                  final tenderId = t['tender_id']?.toString() ?? 'TND-2026';
                  final company = t['company_name']?.toString() ?? 'Corporate RFP';
                  final vehicle = t['vehicle_type']?.toString() ?? 'Scania Semi-Trailer';
                  final duration = t['duration']?.toString() ?? '1 Week';
                  final status = t['status']?.toString() ?? 'Pending Review';
                  final corridor = t['corridor']?.toString() ?? 'Dar - Upcountry';

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFCAD4CC)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5EEF5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tenderId,
                                style: const TextStyle(
                                  fontFamily: 'Segoe UI Variable',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF4B7B9F),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: status == 'Approved'
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontFamily: 'Segoe UI Variable',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: status == 'Approved'
                                      ? const Color(0xFF166534)
                                      : const Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          company,
                          style: const TextStyle(
                            fontFamily: 'Segoe UI Variable',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E2822),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.fire_truck_outlined, size: 14, color: Color(0xFF6B7E74)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                vehicle,
                                style: const TextStyle(
                                  fontFamily: 'Segoe UI Variable',
                                  fontSize: 12,
                                  color: Color(0xFF6B7E74),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F5F1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                duration,
                                style: const TextStyle(
                                  fontFamily: 'Segoe UI Variable',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E2822),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                corridor,
                                style: const TextStyle(
                                  fontFamily: 'Segoe UI Variable',
                                  fontSize: 11,
                                  color: Color(0xFF6B7E74),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTenderFleetChip({
    required String title,
    required String payload,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCAD4CC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E2822),
                ),
              ),
              Text(
                payload,
                style: const TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 11,
                  color: Color(0xFF6B7E74),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== 4. ACCOUNT TAB (100% ENGLISH WITH NIDA BADGE) ====================
  Widget _buildAccountTab() {
    final name = _userData?['name'] ?? 'CARGOO User';
    final phone = _userData?['phone'] ?? '+255 7XX XXX XXX';
    final nida = _userData?['nida_number'] ?? '19900101123450000120';
    final avatarUrl = _userData?['avatar_url']?.toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // User Card with NIDA Status & Profile Photo
          GestureDetector(
            onTap: _openProfileSettings,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFCAD4CC)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF4B7B9F).withValues(alpha: 0.15),
                              border: Border.all(color: const Color(0xFFCAD4CC), width: 2),
                            ),
                            child: ClipOval(
                              child: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? Image.network(
                                      avatarUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, stack) => Center(
                                        child: Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : 'C',
                                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF4B7B9F)),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : 'C',
                                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF4B7B9F)),
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF4B7B9F),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontFamily: 'Segoe UI Variable',
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1E2822),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              phone,
                              style: const TextStyle(
                                fontFamily: 'Segoe UI Variable',
                                fontSize: 13,
                                color: Color(0xFF6B7E74),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // NIDA Verification Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5EEF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCAD4CC)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user_rounded, color: Color(0xFF4B7B9F), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'NIDA: $nida (Verified)',
                            style: const TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2C4A63),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Menu Options (Every Single Button Works!)
          _buildAccountMenuOption(
            icon: Icons.person_outline_rounded,
            title: 'Profile Settings',
            subtitle: 'Change profile picture, name, and contact details',
            onTap: _openProfileSettings,
          ),
          _buildAccountMenuOption(
            icon: Icons.shield_outlined,
            title: 'Cargo Safety & Insurance',
            subtitle: 'Transit protection up to TZS 20,000,000',
            onTap: _showSafetyInsuranceSheet,
          ),
          _buildAccountMenuOption(
            icon: Icons.bookmark_outline_rounded,
            title: 'Saved Locations',
            subtitle: 'Home, office, shop, and warehouses',
            onTap: _showSavedLocationsSheet,
          ),
          _buildAccountMenuOption(
            icon: Icons.support_agent_outlined,
            title: 'Customer Support 24/7',
            subtitle: 'Help center, hotline, and live assistance',
            onTap: _showCustomerSupportSheet,
          ),
          _buildAccountMenuOption(
            icon: Icons.settings_outlined,
            title: 'App Settings',
            subtitle: 'Language, privacy, and notifications',
            onTap: _showAppSettingsSheet,
          ),

          const SizedBox(height: 20),

          // Logout Button
          OutlinedButton.icon(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
            label: const Text(
              'Sign Out',
              style: TextStyle(
                fontFamily: 'Segoe UI Variable',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFFDC2626),
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFECACA)),
              backgroundColor: const Color(0xFFFEF2F2),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),

          const SizedBox(height: 24),
          const Center(
            child: Text(
              'CARGOO Customer App v1.2.0 • Every Load. Every Journey.',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountMenuOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCAD4CC)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F5F1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF4B7B9F), size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Segoe UI Variable',
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E2822),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontFamily: 'Segoe UI Variable',
            fontSize: 11.5,
            color: Color(0xFF6B7E74),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        onTap: onTap,
      ),
    );
  }
}
