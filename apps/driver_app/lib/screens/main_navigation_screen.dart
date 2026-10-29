import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/driver_model.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import 'driver_dashboard_screen.dart';
import 'driver_wallet_screen.dart';
import 'login_screen.dart';
import 'pj_verification_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialTabIndex;

  const MainNavigationScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  DriverModel? _driver;
  List<CargoOrder> _completedTrips = [];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    _loadState();
  }

  Future<void> _loadState() async {
    final driver = await SessionManager.getDriver();
    final trips = await SessionManager.getCompletedTrips();

    if (mounted) {
      setState(() {
        _driver = driver;
        _completedTrips = trips;
      });
    }
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Ondoka (Log Out)?',
          style: TextStyle(fontFamily: 'Segoe UI Variable', color: Color(0xFF1E2822), fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Je, una uhakika unataka kuondoka kwenye akaunti ya dereva?',
          style: TextStyle(fontFamily: 'Segoe UI Variable', color: Color(0xFF6B7E74)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('HAPANA', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('ONDOKA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await SessionManager.clearSession();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _openEditVehicleDialog() {
    final plateCtrl = TextEditingController(text: _driver?.vehiclePlate ?? 'T 482 DWK');
    final capacityCtrl = TextEditingController(text: _driver?.loadCapacity ?? 'Tani 1.5 (Kilo 1,500)');
    String selectedType = _driver?.vehicleType ?? 'Kirikuu Pick-up';
    String selectedLicense = _driver?.licenseClass ?? 'Daraja C1 (Kirikuu & Canter Ndogo)';

    final List<String> vehicleOptions = [
      'Bodaboda ya Mzigo',
      'Guta / Toyo la Mzigo',
      'Kirikuu Pick-up',
      'Canter Ndogo (3.5T)',
      'Canter Kubwa / Isuzu ELF (5.0T)',
      'Lori la Kati Fuso (10T)',
      'Tipa la Ujenzi (15T)',
      'Semi-Trailer Flatbed (28T)',
    ];

    final List<String> licenseClasses = [
      'Daraja A (Pikipiki & Guta la Mzigo)',
      'Daraja B (Magari Madogo)',
      'Daraja C1 (Kirikuu & Canter Ndogo)',
      'Daraja C2 (Malori ya Kati na Mazito)',
      'Daraja C3 (Malori Yenye Trela)',
      'Daraja E (Mitambo ya Ujenzi)',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: const [
                    Icon(Icons.edit_road_rounded, color: Color(0xFF4B7B9F), size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Sajili / Badili Chombo cha Usafiri',
                      style: TextStyle(
                        fontFamily: 'Segoe UI Variable',
                        color: Color(0xFF1E2822),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Vehicle Type Dropdown
                const Text('Aina ya Chombo cha Usafiri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: vehicleOptions.contains(selectedType) ? selectedType : vehicleOptions[2],
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: vehicleOptions
                      .map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 13.5))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedType = val);
                  },
                ),

                const SizedBox(height: 12),

                // Plate Number Input
                const Text('Namba ya Bati ya Chombo (TRA)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: plateCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Mfano: T 482 DWK',
                    prefixIcon: const Icon(Icons.pin_rounded, color: Color(0xFF4B7B9F)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                const SizedBox(height: 12),

                // Load Capacity
                const Text('Uwezo wa Mzigo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: capacityCtrl,
                  decoration: InputDecoration(
                    hintText: 'Mfano: Tani 1.5 au Kilo 800',
                    prefixIcon: const Icon(Icons.fitness_center_rounded, color: Color(0xFF4B7B9F)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                const SizedBox(height: 12),

                // License Class Dropdown
                const Text('Daraja la Leseni Linalohitajika', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: licenseClasses.contains(selectedLicense) ? selectedLicense : licenseClasses[2],
                  isExpanded: true,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: licenseClasses
                      .map((l) => DropdownMenuItem(
                          value: l,
                          child: Text(l, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedLicense = val);
                  },
                ),

                const SizedBox(height: 20),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      final updatedPlate = plateCtrl.text.trim().toUpperCase();
                      final updatedCapacity = capacityCtrl.text.trim();

                      if (updatedPlate.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tafadhali ingiza namba ya bati ya chombo.')),
                        );
                        return;
                      }

                      final updatedDriver = (_driver ??
                              DriverModel(
                                id: 'DRV-1',
                                name: 'Juma Shabani Mussa',
                                phone: '+255 714 882 109',
                                nida: '19920814-14102-00001-24',
                                licenseNumber: 'DL-772910',
                                licenseClass: selectedLicense,
                                vehicleType: selectedType,
                                vehiclePlate: updatedPlate,
                              ))
                          .copyWith(
                        vehicleType: selectedType,
                        vehiclePlate: updatedPlate,
                        licenseClass: selectedLicense,
                        loadCapacity: updatedCapacity.isNotEmpty ? updatedCapacity : 'Tani 1.5',
                      );

                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);

                      await SessionManager.saveDriver(updatedDriver);
                      await ApiService.updateVehicleDetails(
                        phone: updatedDriver.phone,
                        vehicleType: selectedType,
                        vehiclePlate: updatedPlate,
                        licenseClass: selectedLicense,
                        loadCapacity: updatedCapacity,
                      );

                      if (!mounted) return;
                      nav.pop();
                      setState(() {
                        _driver = updatedDriver;
                      });

                      HapticFeedback.heavyImpact();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Taarifa za chombo cha usafiri zimesasishwa kikamilifu!'),
                          backgroundColor: Color(0xFF16A34A),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'HIFADHI MABADILIKO',
                      style: TextStyle(
                        fontFamily: 'Segoe UI Variable',
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
        body: IndexedStack(
          index: _currentIndex,
          children: [
            // Tab 0: Home / Live Map Dashboard
            const DriverDashboardScreen(),

            // Tab 1: Activity / Safari Zilizokamilika
            _buildActivityTab(),

            // Tab 2: Wallet / Pochi ya Kamasheni
            const DriverWalletScreen(),

            // Tab 3: Account / Akaunti ya Dereva
            _buildAccountTab(),
          ],
        ),

        // Bottom Navigation Bar with exact CARGOO Design
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
                _loadState();
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
                  icon: Icon(Icons.account_balance_wallet_rounded),
                  label: 'Wallet',
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

  // ==================== TAB 1: ACTIVITY / SAFARI ====================
  Widget _buildActivityTab() {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Safari Zilizokamilika',
          style: TextStyle(
            fontFamily: 'Segoe UI Variable',
            color: Color(0xFF1E2822),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: _completedTrips.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5EEF5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF4B7B9F), size: 36),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Bado Hujafanya Safari Leo',
                    style: TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E2822),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Oda za mizigo utakazokamilisha zitaonekana hapa.',
                    style: TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      fontSize: 13,
                      color: Color(0xFF6B7E74),
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              itemCount: _completedTrips.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final t = _completedTrips[idx];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
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
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF16A34A)),
                            ),
                            child: const Text(
                              'IMEKAMILIKA ✓',
                              style: TextStyle(color: Color(0xFF16A34A), fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            t.fareAmount,
                            style: const TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.my_location_rounded, color: Color(0xFF4B7B9F), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.pickupName,
                              style: const TextStyle(
                                fontFamily: 'Segoe UI Variable',
                                color: Color(0xFF1E2822),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.dropoffName,
                              style: const TextStyle(
                                fontFamily: 'Segoe UI Variable',
                                color: Color(0xFF1E2822),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Color(0xFFE2E8F0), height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Kamasheni ya CARGOO (7%): TZS ${t.commissionAmount.toStringAsFixed(0)}',
                            style: const TextStyle(color: Color(0xFF6B7E74), fontSize: 11.5),
                          ),
                          Text(
                            'Faida Yako: TZS ${t.netDriverEarnings.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ==================== TAB 3: ACCOUNT / AKAUNTI ====================
  Widget _buildAccountTab() {
    final driver = _driver;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Akaunti ya Dereva',
          style: TextStyle(
            fontFamily: 'Segoe UI Variable',
            color: Color(0xFF1E2822),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Column(
          children: [
            // Driver Profile Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5EEF5),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF4B7B9F), width: 2),
                        ),
                        child: const Icon(Icons.person_rounded, color: Color(0xFF4B7B9F), size: 48),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF16A34A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    driver?.name ?? 'Juma Shabani Mussa',
                    style: const TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E2822),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    driver?.phone ?? '+255 714 882 109',
                    style: const TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      fontSize: 13,
                      color: Color(0xFF6B7E74),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // AI PJ Verification Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF16A34A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Imethibitishwa na AI PJ ✓',
                          style: TextStyle(
                            fontFamily: 'Segoe UI Variable',
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 1. Button: Chombo cha Usafiri (Tazama & Badili Chombo)
            _buildAccountMenuButton(
              icon: Icons.local_shipping_rounded,
              iconBg: const Color(0xFFE0F2FE),
              iconColor: const Color(0xFF0284C7),
              title: 'Chombo cha Usafiri',
              subtitle: '${driver?.vehiclePlate ?? 'T 482 DWK'} • ${driver?.vehicleType ?? 'Kirikuu Pick-up'}',
              badgeText: 'Badili',
              onTap: _openEditVehicleDialog,
            ),

            // 2. Button: Uhakiki wa AI PJ & Nyaraka (KYC)
            _buildAccountMenuButton(
              icon: Icons.verified_user_rounded,
              iconBg: const Color(0xFFDCFCE7),
              iconColor: const Color(0xFF16A34A),
              title: 'Uhakiki wa AI PJ & KYC',
              subtitle: 'NIDA, Leseni, Picha & Cheti cha Usalama',
              badgeText: 'Imethibitishwa ✓',
              badgeColor: const Color(0xFF16A34A),
              onTap: () {
                if (driver != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PjVerificationScreen(driver: driver)),
                  );
                }
              },
            ),

            // 3. Button: Pochi ya Dereva & Kamasheni
            _buildAccountMenuButton(
              icon: Icons.account_balance_wallet_rounded,
              iconBg: const Color(0xFFFEF3C7),
              iconColor: const Color(0xFFD97706),
              title: 'Pochi ya Dereva & Kamasheni',
              subtitle: 'Kamasheni ya 7% • M-Pesa, Tigo Pesa, Airtel',
              onTap: () {
                setState(() => _currentIndex = 2);
              },
            ),

            // 4. Button: Kituo cha Msaada & Huduma kwa Dereva
            _buildAccountMenuButton(
              icon: Icons.support_agent_rounded,
              iconBg: const Color(0xFFF3E8FF),
              iconColor: const Color(0xFF7C3AED),
              title: 'Msaada & Huduma kwa Dereva',
              subtitle: 'Msaada wa dharura 24/7 na ushauri',
              onTap: _showSupportBottomSheet,
            ),

            const SizedBox(height: 10),

            // 5. Button: Ondoka Kwenye Akaunti (Log Out)
            _buildAccountMenuButton(
              icon: Icons.logout_rounded,
              iconBg: const Color(0xFFFEE2E2),
              iconColor: const Color(0xFFEF4444),
              title: 'Ondoka Kwenye Akaunti',
              subtitle: 'Funga kipindi cha dereva kwa usalama',
              isDestructive: true,
              onTap: _logout,
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountMenuButton({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    String? subtitle,
    String? badgeText,
    Color? badgeColor,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDestructive ? const Color(0xFFFEE2E2) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
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
                              title,
                              style: TextStyle(
                                fontFamily: 'Segoe UI Variable',
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: isDestructive ? const Color(0xFFEF4444) : const Color(0xFF1E2822),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badgeText != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: (badgeColor ?? const Color(0xFF4B7B9F)).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badgeText,
                                style: TextStyle(
                                  fontFamily: 'Segoe UI Variable',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: badgeColor ?? const Color(0xFF4B7B9F),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: 'Segoe UI Variable',
                            fontSize: 12,
                            color: isDestructive ? const Color(0xFFF87171) : const Color(0xFF6B7E74),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isDestructive ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSupportBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: const [
                Icon(Icons.support_agent_rounded, color: Color(0xFF4B7B9F), size: 26),
                SizedBox(width: 10),
                Text(
                  'Huduma kwa Madereva CARGOO',
                  style: TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E2822),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Una swali au changamoto yoyote ukiwa barabarani? Wasiliana na timu ya CARGOO saa 24/7:',
              style: TextStyle(fontFamily: 'Segoe UI Variable', fontSize: 13, color: Color(0xFF6B7E74)),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.phone_rounded, color: Color(0xFF0284C7), size: 20),
              ),
              title: const Text('Piga Simu ya Bure (Toll-Free)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('0800 750 000 / +255 714 882 109', style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7E74))),
              onTap: () => Navigator.pop(ctx),
            ),
            const Divider(color: Color(0xFFF1F5F9)),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.chat_rounded, color: Color(0xFF16A34A), size: 20),
              ),
              title: const Text('Msaada kwa WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Wasiliana nasi muda wote kwa ujumbe', style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7E74))),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
