import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import 'main_navigation_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String phoneNumber;

  const ProfileScreen({super.key, required this.phoneNumber});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nidaController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String _idType = 'NIDA';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _nidaController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleCompleteProfile() async {
    final name = _nameController.text.trim();
    final rawId = _idType == 'NIDA'
        ? _nidaController.text.replaceAll(RegExp(r'[^0-9]'), '')
        : _nidaController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your full name';
      });
      return;
    }

    if (rawId.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your $_idType number';
      });
      return;
    }

    if (_idType == 'NIDA' && rawId.length != 20) {
      setState(() {
        _errorMessage = 'NIDA Number must contain 20 digits (entered ${rawId.length})';
      });
      return;
    } else if (_idType != 'NIDA' && rawId.length < 6) {
      setState(() {
        _errorMessage = 'Please enter a valid $_idType number (at least 6 characters)';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.completeProfile(
      name: name,
      nidaNumber: rawId,
      email: email.isEmpty ? null : email,
      city: 'Dar es Salaam',
    );

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      final user = result['data']?['user'] ?? {
        'name': name,
        'phone': widget.phoneNumber,
        'id_type': _idType,
        'id_number': rawId,
        'nida_number': rawId,
        'email': email.isEmpty ? null : email,
        'city': 'Dar es Salaam',
        'is_profile_complete': true,
      };
      user['id_type'] = _idType;
      user['id_number'] = rawId;

      await SessionManager.saveUser(user);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => MainNavigationScreen(user: user),
        ),
        (route) => false,
      );
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Network error. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawNidaLength = _nidaController.text.replaceAll(RegExp(r'[^0-9]'), '').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Final Step',
          style: TextStyle(
            fontFamily: 'Segoe UI Variable',
            color: Color(0xFF1E2822),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Account Details',
                style: TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E2822),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Provide your identification details to ensure secure cargo handling and carrier accountability.',
                style: TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF6B7E74),
                ),
              ),

              const SizedBox(height: 24),

              // Full Name Field
              _buildInputLabel('Full Name (As on Official ID) *'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCAD4CC)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E2822),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Juma Rashid Bakari',
                    prefixIcon: Icon(Icons.person_outline_rounded, color: Color(0xFF4B7B9F)),
                    border: InputBorder.none,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Verification Document Type Dropdown
              _buildInputLabel('Verification Document Type *'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCAD4CC)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _idType,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF4B7B9F)),
                    style: const TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E2822),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'NIDA', child: Text('National ID (NIDA)')),
                      DropdownMenuItem(value: 'Driving License', child: Text('Driving License (Leseni ya Udereva)')),
                      DropdownMenuItem(value: "Voter's ID", child: Text("Voter's ID (Kadi ya Mpiga Kura)")),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _idType = val;
                          _nidaController.clear();
                          _errorMessage = null;
                        });
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ID Number Field
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInputLabel(_idType == 'NIDA' ? 'National NIDA Number (20 Digits) *' : '$_idType Number *'),
                  if (_idType == 'NIDA')
                    Text(
                      '$rawNidaLength / 20',
                      style: TextStyle(
                        fontFamily: 'Segoe UI Variable',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: rawNidaLength == 20 ? const Color(0xFF4B7B9F) : const Color(0xFF6B7E74),
                      ),
                    ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (_idType == 'NIDA' ? rawNidaLength == 20 : _nidaController.text.trim().length >= 6)
                        ? const Color(0xFF4B7B9F)
                        : const Color(0xFFCAD4CC),
                    width: (_idType == 'NIDA' ? rawNidaLength == 20 : _nidaController.text.trim().length >= 6) ? 1.8 : 1.0,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _nidaController,
                  keyboardType: _idType == 'NIDA' ? TextInputType.number : TextInputType.text,
                  inputFormatters: _idType == 'NIDA'
                      ? [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(20),
                        ]
                      : [
                          LengthLimitingTextInputFormatter(25),
                        ],
                  onChanged: (val) {
                    setState(() {
                      if (_errorMessage != null) _errorMessage = null;
                    });
                  },
                  style: const TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    fontSize: 16,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E2822),
                  ),
                  decoration: InputDecoration(
                    hintText: _idType == 'NIDA'
                        ? '19900101123450000120'
                        : (_idType == 'Driving License' ? 'DL-7482910' : 'T-10293847-X'),
                    hintStyle: TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      color: Colors.grey.shade400,
                      letterSpacing: 1.0,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF4B7B9F)),
                    suffixIcon: (_idType == 'NIDA' ? rawNidaLength == 20 : _nidaController.text.trim().length >= 6)
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF4B7B9F), size: 22)
                        : null,
                    border: InputBorder.none,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Official ID Info Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5EEF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCAD4CC)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Color(0xFF4B7B9F), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your official ID (NIDA, Driving License, or Voter\'s ID) verifies your identity for legal cargo transit protection and tracking.',
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          fontSize: 11.5,
                          height: 1.35,
                          color: Color(0xFF2C4A63),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Email Field (Optional)
              _buildInputLabel('Email Address (Optional - for delivery receipts)'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCAD4CC)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E2822),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'juma@example.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded, color: Color(0xFF4B7B9F)),
                    border: InputBorder.none,
                  ),
                ),
              ),

              // Dynamic GPS Location Notice
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCAD4CC)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.my_location_rounded, color: Color(0xFF4B7B9F), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your pickup city and street are automatically detected via real-time GPS across Tanzania.',
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          fontSize: 11.5,
                          color: Color(0xFF6B7E74),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 18, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleCompleteProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4B7B9F),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF4B7B9F).withValues(alpha: 0.6),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Complete & Enter CARGOO',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Segoe UI Variable',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1E2822),
        ),
      ),
    );
  }
}
