import 'package:flutter/material.dart';
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
  late TextEditingController _colorController;

  String _selectedVehicleType = 'Kirikuu Pick-up';
  String _selectedLicenseClass = 'Class C (Kirikuu & Canter)';

  final List<String> _vehicleTypes = [
    'Kirikuu Pick-up',
    'Guta / Boxer (Mizigo Midogo)',
    'Canter 3-Ton (Mizigo ya Kati)',
    'Isuzu Forward 7-Ton (Mizigo Mizito)',
    'Tipper Sand / Gravel (Kokoto & Mchanga)',
  ];

  final List<String> _licenseClasses = [
    'Class C (Kirikuu & Canter)',
    'Class B (Magari Binafsi & Boxer)',
    'Class E (Malori Makubwa & Matrela)',
    'Class D (Mabasi & Magari ya Abiria)',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Juma Shabani Mussa');
    _phoneController = TextEditingController(text: widget.initialPhone.isNotEmpty ? widget.initialPhone : '0714 882 109');
    _nidaController = TextEditingController(text: '19920814-14102-00001-24');
    _licenseController = TextEditingController(text: 'DL-TZ-772910');
    _plateController = TextEditingController(text: 'T 482 DWK');
    _colorController = TextEditingController(text: 'Nyeupe (White)');
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
      vehicleColor: _colorController.text.trim(),
      isPjVerified: false,
      walletDebt: 0.0,
      isOnline: false,
    );

    // Save profile locally
    await SessionManager.saveDriver(driver);

    if (!mounted) return;

    // Route directly to Process 1: AI Officer PJ Verification Screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PjVerificationScreen(driver: driver),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text(
          'Usajili wa Dereva Mpya',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
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
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.psychology_rounded, color: Color(0xFF38BDF8), size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Baada ya kujaza fomu, Afisa wa AI "PJ" atahakiki nyaraka zako mtandaoni kwa sekunde chache.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  '1. TAARIFA BINAFSI ZA DEREVA',
                  style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 12),

                // Name
                _buildField(
                  label: 'Jina Kamili (Kama lilivyo NIDA)',
                  controller: _nameController,
                  icon: Icons.person_outline_rounded,
                  hint: 'Mfano: Juma Shabani Mussa',
                ),

                // Phone
                _buildField(
                  label: 'Namba ya Simu ya Kazini',
                  controller: _phoneController,
                  icon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                  hint: '0714 882 109',
                ),

                // NIDA
                _buildField(
                  label: 'Namba ya NIDA (Tarakimu 20)',
                  controller: _nidaController,
                  icon: Icons.badge_outlined,
                  hint: '19920814-14102-00001-24',
                ),

                const SizedBox(height: 16),
                const Text(
                  '2. LESENI YA UDEREVA',
                  style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 12),

                // License Number
                _buildField(
                  label: 'Namba ya Leseni ya Udereva',
                  controller: _licenseController,
                  icon: Icons.drive_eta_outlined,
                  hint: 'DL-TZ-772910',
                ),

                // License Class Dropdown
                const Text(
                  'Daraja la Leseni',
                  style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedLicenseClass,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
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
                  '3. TAARIFA ZA CHOMBO CHA MZIGO',
                  style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 12),

                // Vehicle Type Dropdown
                const Text(
                  'Aina ya Chombo cha Mzigo',
                  style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedVehicleType,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
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

                // Vehicle Plate
                _buildField(
                  label: 'Namba ya Bati ya Chombo (TRA Plate)',
                  controller: _plateController,
                  icon: Icons.tag_rounded,
                  hint: 'Mfano: T 482 DWK',
                ),

                // Vehicle Color
                _buildField(
                  label: 'Rangi ya Gari / Chombo',
                  controller: _colorController,
                  icon: Icons.palette_outlined,
                  hint: 'Mfano: Nyeupe (White)',
                ),

                const SizedBox(height: 24),

                // Submit button to Process 1: AI PJ
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submitRegistration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'ENDELEA KWA AFISA WA AI "PJ"',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
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
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Tafadhali jaza sehemu hii' : null,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF1E293B),
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              prefixIcon: Icon(icon, color: const Color(0xFF38BDF8), size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF22C55E), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
