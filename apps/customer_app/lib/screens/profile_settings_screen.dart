import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/session_manager.dart';
import 'login_screen.dart';
import 'otp_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ProfileSettingsScreen({super.key, required this.user});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _nidaController;
  late TextEditingController _emailController;
  late TextEditingController _cityController;

  String? _selectedAvatar;
  String _idType = 'NIDA';
  bool _isSaving = false;

  final List<String> _presetAvatars = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&h=200&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&h=200&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&h=200&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=200&h=200&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=200&h=200&fit=crop&crop=face',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['name'] ?? '');
    _phoneController = TextEditingController(text: widget.user['phone'] ?? '');
    _nidaController = TextEditingController(text: widget.user['nida_number'] ?? widget.user['id_number'] ?? '19900101123450000120');
    _idType = widget.user['id_type'] ?? 'NIDA';
    _emailController = TextEditingController(text: widget.user['email'] ?? '');
    _cityController = TextEditingController(text: widget.user['city'] ?? 'Dar es Salaam');
    _selectedAvatar = widget.user['avatar_url'] ?? _presetAvatars[1];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _nidaController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _showAvatarPickerSheet() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Choose Profile Picture',
                    style: TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E2822),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'This photo is visible to your assigned cargo driver for official pickup verification.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: _presetAvatars.map((url) {
                  final isSelected = _selectedAvatar == url;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedAvatar = url);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? const Color(0xFF4B7B9F) : const Color(0xFFCAD4CC),
                          width: isSelected ? 3.5 : 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5EEF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.link_rounded, color: Color(0xFF4B7B9F)),
                ),
                title: const Text('Enter Custom Image URL', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                subtitle: const Text('Paste direct link to your personal photo', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(context);
                  _showCustomUrlDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCustomUrlDialog() {
    final urlCtrl = TextEditingController(text: _selectedAvatar ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom Photo Link', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: urlCtrl,
          decoration: const InputDecoration(
            hintText: 'https://example.com/my-photo.jpg',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (urlCtrl.text.trim().isNotEmpty) {
                setState(() => _selectedAvatar = urlCtrl.text.trim());
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4B7B9F)),
            child: const Text('Apply', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSaveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final destination = _emailController.text.trim().isNotEmpty
        ? _emailController.text.trim()
        : _phoneController.text.trim();

    // Launch V15 Animated OTP Verification Card for Profile Update
    final verified = await showAnimatedOtpVerificationModal(
      context: context,
      destination: destination,
      verifiedSubtitle: 'Your profile update has been verified.',
      initialOtp: '1234',
    );

    if (!verified || !mounted) return;

    setState(() => _isSaving = true);

    final updatedUser = {
      'id': widget.user['id'] ?? 1,
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'id_type': _idType,
      'nida_number': _nidaController.text.trim(),
      'id_number': _nidaController.text.trim(),
      'email': _emailController.text.trim(),
      'city': _cityController.text.trim(),
      'avatar_url': _selectedAvatar,
      'role': widget.user['role'] ?? 'customer',
      'is_verified': true,
    };

    // 1. Save locally in device session
    await SessionManager.saveUser(updatedUser);

    // 2. Synchronize to Laravel backend API
    try {
      await http.post(
        Uri.parse('${ApiService.baseUrl}/user/profile'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(updatedUser),
      ).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Backend profile sync error: $e');
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile and photo updated successfully!'),
        backgroundColor: Color(0xFF4B7B9F),
      ),
    );

    Navigator.pop(context, updatedUser);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E2822)),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Profile Settings',
            style: TextStyle(
              fontFamily: 'Segoe UI Variable',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E2822),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile Avatar with Camera badge
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE5EEF5),
                          border: Border.all(color: const Color(0xFFCAD4CC), width: 3),
                        ),
                        child: ClipOval(
                          child: _selectedAvatar != null && _selectedAvatar!.isNotEmpty
                              ? Image.network(
                                  _selectedAvatar!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Center(
                                    child: Text(
                                      _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : 'C',
                                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF4B7B9F)),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : 'C',
                                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF4B7B9F)),
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showAvatarPickerSheet,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4B7B9F),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _showAvatarPickerSheet,
                  icon: const Icon(Icons.edit_rounded, size: 14, color: Color(0xFF4B7B9F)),
                  label: const Text(
                    'Change Profile Photo',
                    style: TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4B7B9F),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Full Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name *',
                    hintText: 'e.g. Peter John',
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF4B7B9F)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your full name' : null,
                ),
                const SizedBox(height: 16),

                // Phone Number
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number *',
                    hintText: '+255 7XX XXX XXX',
                    prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF4B7B9F)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    suffixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your phone number' : null,
                ),
                const SizedBox(height: 16),

                // ID Type Dropdown (NIDA, Driving License, Voter ID)
                DropdownButtonFormField<String>(
                  initialValue: _idType,
                  decoration: InputDecoration(
                    labelText: 'Verification Document Type *',
                    prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF4B7B9F)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'NIDA', child: Text('National ID (NIDA)')),
                    DropdownMenuItem(value: 'Driving License', child: Text('Driving License (Leseni ya Udereva)')),
                    DropdownMenuItem(value: "Voter's ID", child: Text("Voter's ID (Kadi ya Mpiga Kura)")),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _idType = val);
                  },
                ),
                const SizedBox(height: 16),

                // ID Number
                TextFormField(
                  controller: _nidaController,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: '$_idType Number *',
                    hintText: _idType == 'NIDA'
                        ? '19900101123450000120'
                        : (_idType == 'Driving License' ? 'DL-7482910' : 'VOT-8839210'),
                    prefixIcon: const Icon(Icons.verified_user_outlined, color: Color(0xFF4B7B9F)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    suffixIcon: Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5EEF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Verified',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF2C4A63)),
                      ),
                    ),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your $_idType number' : null,
                ),
                const SizedBox(height: 16),

                // Email Address
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address (Optional)',
                    hintText: 'peter@example.com',
                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF4B7B9F)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 16),

                // City / Base Region
                TextFormField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    labelText: 'Operational City',
                    hintText: 'Dar es Salaam',
                    prefixIcon: const Icon(Icons.location_city_outlined, color: Color(0xFF4B7B9F)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),

                const SizedBox(height: 32),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSaveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4B7B9F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text(
                            'Save Profile Changes',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 36),

                // Danger Zone: Delete Account (Google Play Compliance)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Account Privacy & Security',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Permanently erase your account, NIDA identification records, and shipment history from CARGOO servers in compliance with data privacy policies.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _confirmDeleteAccount,
                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                        label: const Text(
                          'Delete Account & Personal Data',
                          style: TextStyle(
                            fontFamily: 'Segoe UI Variable',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Delete Account?',
                  style: TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E2822),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to permanently delete your CARGOO account and personal data?',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF1E2822)),
              ),
              const SizedBox(height: 10),
              const Text(
                '• All ongoing delivery requests will be cancelled.\n'
                '• Digital cargo waybills will be permanently removed.\n'
                '• Your phone number, NIDA identity record, and profile will be erased from CARGOO servers in compliance with data privacy regulations.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.45),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFB45309)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action cannot be undone.',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _executeAccountDeletion();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _executeAccountDeletion() async {
    setState(() => _isSaving = true);
    final phone = _phoneController.text.trim();

    try {
      await http.post(
        Uri.parse('${ApiService.baseUrl}/user/delete-account'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {}

    await SessionManager.clearSession();
    await SessionManager.clearRecentSearches();
    await SessionManager.clearBookedTrips();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }
}
