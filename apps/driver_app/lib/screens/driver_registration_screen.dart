import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/driver_model.dart';
import '../services/session_manager.dart';
import 'pj_verification_screen.dart';

class DriverRegistrationScreen extends StatefulWidget {
  final String initialPhone;

  const DriverRegistrationScreen({super.key, this.initialPhone = ''});

  @override
  State<DriverRegistrationScreen> createState() => _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _nidaController;
  late TextEditingController _licenseController;
  late TextEditingController _plateController;

  String _selectedVehicleType = 'Kirikuu Pick-up';
  String _selectedLicenseClass = 'Daraja C1 (Kirikuu & Canter Ndogo)';

  // Official Tanzania Driving License Classes for Commercial/Cargo
  final List<String> _licenseClasses = [
    'Daraja A (Pikipiki & Guta la Mzigo)',
    'Daraja B (Magari Madogo)',
    'Daraja C1 (Kirikuu & Canter Ndogo)',
    'Daraja C2 (Malori ya Kati na Mazito)',
    'Daraja C3 (Malori Yenye Trela)',
    'Daraja E (Mitambo ya Ujenzi)',
  ];

  final List<String> _vehicleTypes = [
    'Kirikuu Pick-up',
    'Guta / Boxer ya Mzigo',
    'Canter 3-Ton (Mizigo ya Kati)',
    'Isuzu Forward 7-Ton (Mizigo Mizito)',
    'Tipper (Kokoto & Mchanga)',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController(text: widget.initialPhone);
    _nidaController = TextEditingController();
    _licenseController = TextEditingController();
    _plateController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _nidaController.dispose();
    _licenseController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  void _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    final driver = DriverModel(
      id: 'DRV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      nida: _nidaController.text.trim(),
      licenseNumber: _licenseController.text.trim(),
      licenseClass: _selectedLicenseClass,
      vehicleType: _selectedVehicleType,
      vehiclePlate: _plateController.text.trim().toUpperCase(),
      vehicleColor: '', // Removed per user request
      isPjVerified: false,
      walletDebt: 0.0,
      isOnline: false,
    );

    await SessionManager.saveDriver(driver);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PjVerificationScreen(driver: driver),
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
        systemNavigationBarColor: Color(0xFFF2F5F1),
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F5F1),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E2822)),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Usajili wa Dereva Mpya',
            style: TextStyle(
              fontFamily: 'Segoe UI Variable',
              color: Color(0xFF1E2822),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.psychology_rounded, color: Color(0xFF4B7B9F), size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Baada ya kujaza fomu hii, Afisa wa AI "PJ" atahakiki NIDA, Leseni na Chombo chako papo hapo mtandaoni.',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              color: Color(0xFF6B7E74),
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    '1. TAARIFA ZA DEREVA',
                    style: TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      color: Color(0xFF4B7B9F),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildField(
                    label: 'Jina Kamili (Kama lilivyo NIDA)',
                    controller: _nameController,
                    icon: Icons.person_outline_rounded,
                    hint: 'Juma Shabani Mussa',
                  ),

                  _buildField(
                    label: 'Namba ya Simu',
                    controller: _phoneController,
                    icon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                    hint: '0714 882 109',
                  ),

                  _buildField(
                    label: 'Namba ya NIDA (Tarakimu 20)',
                    controller: _nidaController,
                    icon: Icons.badge_outlined,
                    hint: '19920814-14102-00001-24',
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    '2. LESENI YA UDEREVA (TANZANIA)',
                    style: TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      color: Color(0xFF4B7B9F),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildField(
                    label: 'Namba ya Leseni ya Udereva',
                    controller: _licenseController,
                    icon: Icons.drive_eta_outlined,
                    hint: 'DL-TZ-772910',
                  ),

                  const Text(
                    'Daraja la Leseni (Tanzania Official Class)',
                    style: TextStyle(color: Color(0xFF1E2822), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedLicenseClass,
                        isExpanded: true,
                        style: const TextStyle(
                          color: Color(0xFF1E2822),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        items: _licenseClasses.map((cls) {
                          return DropdownMenuItem(value: cls, child: Text(cls));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedLicenseClass = val);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    '3. CHOMBO CHA MZIGO',
                    style: TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      color: Color(0xFF4B7B9F),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'Aina ya Chombo cha Mzigo',
                    style: TextStyle(color: Color(0xFF1E2822), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedVehicleType,
                        isExpanded: true,
                        style: const TextStyle(
                          color: Color(0xFF1E2822),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        items: _vehicleTypes.map((type) {
                          return DropdownMenuItem(value: type, child: Text(type));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedVehicleType = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildField(
                    label: 'Namba ya Bati ya Chombo (TRA Plate)',
                    controller: _plateController,
                    icon: Icons.tag_rounded,
                    hint: 'T 482 DWK',
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _submitRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4B7B9F),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'ENDELEA KWA AFISA WA AI "PJ"',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF1E2822), fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(
              fontFamily: 'Segoe UI Variable',
              color: Color(0xFF1E2822),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Tafadhali jaza sehemu hii' : null,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              prefixIcon: Icon(icon, color: const Color(0xFF4B7B9F), size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF4B7B9F), width: 1.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
