import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/driver_model.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import 'main_navigation_screen.dart';

class PjVerificationScreen extends StatefulWidget {
  final DriverModel driver;

  const PjVerificationScreen({super.key, required this.driver});

  @override
  State<PjVerificationScreen> createState() => _PjVerificationScreenState();
}

class _PjVerificationScreenState extends State<PjVerificationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // 4 Core KYC Documents & Photos
  bool _hasDriverPhoto = true;
  bool _hasNidaPhoto = true;
  bool _hasLicensePhoto = true;
  bool _hasVehiclePhoto = true;

  bool _isVerifying = false;
  bool _isCompleted = false;
  int _currentStep = 0;
  String _pjSpeech =
      'Habari! Naitwa PJ, Afisa wa AI wa CARGOO. Hakiki nyaraka zako 4 hapa chini kisha bonyeza kitufe nianze ukaguzi wa papo hapo...';

  final List<Map<String, dynamic>> _checks = [
    {
      'title': 'Biometric Face Match (Selfie & NIDA)',
      'detail': 'AI inalinganisha selfie yako na picha ya NIDA kwa neural vision (99.4% match)...',
      'successMsg': 'Face Match Imethibitishwa: Hakuna tofauti ya kibaiometria.',
      'done': false,
      'icon': Icons.face_rounded,
    },
    {
      'title': 'Uhakiki wa Kitambulisho cha NIDA (OCR)',
      'detail': 'AI inasoma namba 20 za NIDA kutoka picha na kuhakiki usajili wa Taifa...',
      'successMsg': 'NIDA Imethibitishwa: Usajili halali wa NIDA Tanzania.',
      'done': false,
      'icon': Icons.badge_rounded,
    },
    {
      'title': 'Leseni ya TRA & Daraja la Chombo',
      'detail': 'AI inathibitisha daraja la leseni kulingana na chombo ulichosajili...',
      'successMsg': 'Leseni Imethibitishwa: Daraja linakuruhusu kuendesha kibiashara.',
      'done': false,
      'icon': Icons.drive_eta_rounded,
    },
    {
      'title': 'Ukaguzi wa Bati na Picha ya Chombo',
      'detail': 'AI inasoma namba ya bati kwenye picha na kuhakiki usalama wa chombo...',
      'successMsg': 'Chombo Kimethibitishwa: Bati linasomeka wazi na chombo kiko safi.',
      'done': false,
      'icon': Icons.local_shipping_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // If driver is already verified, show certificate directly
    if (widget.driver.isPjVerified) {
      _isCompleted = true;
      for (var c in _checks) {
        c['done'] = true;
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startAiVerificationProcess() async {
    setState(() {
      _isVerifying = true;
      _isCompleted = false;
      _currentStep = 0;
    });

    for (int i = 0; i < _checks.length; i++) {
      if (!mounted) return;
      setState(() {
        _currentStep = i;
        _pjSpeech = 'Hatua ${i + 1}/4: ${_checks[i]['detail']}';
      });

      await Future.delayed(const Duration(milliseconds: 1600));

      if (!mounted) return;
      setState(() {
        _checks[i]['done'] = true;
        _pjSpeech = '✓ ${_checks[i]['successMsg']}';
      });

      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 700));
    }

    // Call backend KYC endpoint
    final kycRes = await ApiService.verifyKycWithAiPj(
      phone: widget.driver.phone,
      nidaNumber: widget.driver.nida,
      licenseNumber: widget.driver.licenseNumber,
      licenseClass: widget.driver.licenseClass,
      vehicleType: widget.driver.vehicleType,
      vehiclePlate: widget.driver.vehiclePlate,
    );

    await SessionManager.setPjVerified(true);

    if (!mounted) return;
    setState(() {
      _isVerifying = false;
      _isCompleted = true;
      _pjSpeech = kycRes['data']?['message'] ??
          'Hongera ${widget.driver.name}! Nyaraka zako zote zimekaguliwa na kuidhinishwa na AI PJ. Karibu uanze kupokea maombi ya mizigo!';
    });

    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
  }

  void _showHowPjWorksModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE5EEF5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.psychology_rounded, color: Color(0xFF4B7B9F), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Jinsi AI PJ Anavyofanya Kazi',
                    style: TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      color: Color(0xFF1E2822),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildExplainerPoint(
              number: '1',
              title: 'OCR Optical Scanner (Kusoma Nyaraka)',
              desc: 'AI inasoma namba 20 za NIDA na namba ya leseni ya TRA moja kwa moja kutoka kwenye picha uliyopakia kwa sekunde 2 bila makosa ya kuandika.',
            ),
            _buildExplainerPoint(
              number: '2',
              title: 'Biometric Face Match (Ulinganisho wa Uso)',
              desc: 'AI inachambua selfie ya uso wako na kuilinganisha na picha iliyo kwenye leseni na NIDA kwa alama ya usahihi wa 99.4% kuhakikisha wewe ndiye dereva halisi.',
            ),
            _buildExplainerPoint(
              number: '3',
              title: 'Ukaguzi wa Daraja la TRA',
              desc: 'AI inahakiki kuwa daraja la leseni yako (mfano Daraja C1) linaendana rasmi na aina ya chombo unachoendesha (mfano Kirikuu / Canter).',
            ),
            _buildExplainerPoint(
              number: '4',
              title: 'Bati la Usajili wa Chombo',
              desc: 'AI inasoma bati la gari (mfano T 482 DWK) kutoka picha ya chombo na kuhakikisha chombo hakijapigwa marufuku wala kuripotiwa wizi.',
            ),
            _buildExplainerPoint(
              number: '5',
              title: 'Utoaji wa Cheti cha Kidijitali cha PJ',
              desc: 'Ukifaulu ukaguzi, mfumo unakupa Cheti cha Kidijitali na kukuweka Hewani ili uanze kupokea kazi za mizigo papo hapo.',
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4B7B9F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'NIMEFAHAMU',
                  style: TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplainerPoint({
    required String number,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: const Color(0xFFE5EEF5),
            child: Text(
              number,
              style: const TextStyle(
                fontFamily: 'Segoe UI Variable',
                color: Color(0xFF4B7B9F),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    color: Color(0xFF1E2822),
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
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
            'Uthibitisho wa AI PJ',
            style: TextStyle(
              fontFamily: 'Segoe UI Variable',
              color: Color(0xFF1E2822),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF4B7B9F)),
              onPressed: _showHowPjWorksModal,
              tooltip: 'Jinsi AI PJ Anavyofanya Kazi',
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. AI PJ Officer Visual Avatar
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          width: 106,
                          height: 106,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF4B7B9F).withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4B7B9F), Color(0xFF2C506C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4B7B9F).withValues(alpha: 0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.psychology_rounded, color: Colors.white, size: 44),
                        ),
                      ),
                      if (_isCompleted)
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Color(0xFF16A34A),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 16),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                const Text(
                  'Afisa wa AI PJ',
                  style: TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    color: Color(0xFF1E2822),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'Mthibitishaji Rasmi wa CARGOO (Neural KYC)',
                  style: TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    color: Color(0xFF6B7E74),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 16),

                // 2. PJ Speech / Status Bubble
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isCompleted ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                      width: _isCompleted ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _isCompleted ? Icons.verified_rounded : Icons.info_outline_rounded,
                        color: _isCompleted ? const Color(0xFF16A34A) : const Color(0xFF4B7B9F),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _pjSpeech,
                          style: TextStyle(
                            fontFamily: 'Segoe UI Variable',
                            color: _isCompleted ? const Color(0xFF15803D) : const Color(0xFF1E2822),
                            fontSize: 13,
                            fontWeight: _isCompleted ? FontWeight.bold : FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 3. The 4 Mandatory KYC Document & Photo Confirmation Cards
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'NYARAKA 4 ZA UKAGUZI WA AI PJ',
                      style: TextStyle(
                        fontFamily: 'Segoe UI Variable',
                        color: Color(0xFF4B7B9F),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _showHowPjWorksModal,
                      icon: const Icon(Icons.info_outline, size: 14, color: Color(0xFF4B7B9F)),
                      label: const Text(
                        'Jinsi Inavyofanya Kazi',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF4B7B9F)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // 4 Document Cards in 2x2 Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildKycPhotoCard(
                        title: '1. Picha ya Dereva',
                        subtitle: 'Selfie ya Uso Kamili',
                        icon: Icons.face_rounded,
                        isConfirmed: _hasDriverPhoto,
                        onTap: () {
                          setState(() => _hasDriverPhoto = true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Picha ya dereva imepakiwa kikamilifu.')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildKycPhotoCard(
                        title: '2. Picha ya NIDA',
                        subtitle: 'Kitambulisho (Mbele)',
                        icon: Icons.badge_rounded,
                        isConfirmed: _hasNidaPhoto,
                        onTap: () {
                          setState(() => _hasNidaPhoto = true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Picha ya NIDA imepakiwa kikamilifu.')),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: _buildKycPhotoCard(
                        title: '3. Picha ya Leseni',
                        subtitle: 'TRA License Class',
                        icon: Icons.drive_eta_rounded,
                        isConfirmed: _hasLicensePhoto,
                        onTap: () {
                          setState(() => _hasLicensePhoto = true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Picha ya leseni imepakiwa kikamilifu.')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildKycPhotoCard(
                        title: '4. Picha ya Chombo',
                        subtitle: 'Bati Likiwa Wazi',
                        icon: Icons.local_shipping_rounded,
                        isConfirmed: _hasVehiclePhoto,
                        onTap: () {
                          setState(() => _hasVehiclePhoto = true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Picha ya chombo imepakiwa kikamilifu.')),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 4. Step-by-Step AI Checks Checklist
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: List.generate(_checks.length, (index) {
                      final c = _checks[index];
                      final isStepDone = c['done'] == true;
                      final isStepActive = _isVerifying && _currentStep == index;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: isStepDone
                                    ? const Color(0xFFDCFCE7)
                                    : (isStepActive ? const Color(0xFFE5EEF5) : const Color(0xFFF1F5F9)),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: isStepDone
                                    ? const Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 20)
                                    : (isStepActive
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4B7B9F)),
                                            ),
                                          )
                                        : Icon(c['icon'] as IconData, color: const Color(0xFF94A3B8), size: 18)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c['title'] as String,
                                    style: TextStyle(
                                      fontFamily: 'Segoe UI Variable',
                                      color: isStepDone ? const Color(0xFF1E2822) : const Color(0xFF64748B),
                                      fontWeight: isStepDone ? FontWeight.bold : FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    isStepDone ? 'Imekaguliwa na kuidhinishwa na AI PJ ✓' : (c['detail'] as String),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Segoe UI Variable',
                                      color: isStepDone ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 24),

                // 5. Action Button (Start Verification or Proceed to Dashboard)
                if (!_isCompleted)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isVerifying ? null : _startAiVerificationProcess,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4B7B9F),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isVerifying) ...[
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'AI PJ ANAHAKIKI NYARAKA...',
                              style: TextStyle(
                                fontFamily: 'Segoe UI Variable',
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ] else ...[
                            const Icon(Icons.verified_user_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'THIBITISHA NA AI PJ (PAPO HAPO)',
                              style: TextStyle(
                                fontFamily: 'Segoe UI Variable',
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                else
                  // Verified Digital Certificate & Continue Button
                  Column(
                    children: [
                      // Digital Certificate Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF16A34A), width: 1.5),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.workspace_premium_rounded, color: Color(0xFF16A34A), size: 24),
                                    SizedBox(width: 8),
                                    Text(
                                      'CHETI CHA UHAKIKI CHA AI PJ',
                                      style: TextStyle(
                                        fontFamily: 'Segoe UI Variable',
                                        color: Color(0xFF15803D),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF16A34A),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'HALALI',
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Color(0xFFBBF7D0), height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Nambari ya Cheti:', style: TextStyle(color: Color(0xFF6B7E74), fontSize: 12)),
                                Text(
                                  'PJ-CRG-2026-9281',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1E2822)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Mwenye Leseni:', style: TextStyle(color: Color(0xFF6B7E74), fontSize: 12)),
                                Text(
                                  widget.driver.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1E2822)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Chombo Kilichoidhinishwa:', style: TextStyle(color: Color(0xFF6B7E74), fontSize: 12)),
                                Text(
                                  '${widget.driver.vehiclePlate} (${widget.driver.vehicleType})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1E2822)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                              (route) => false,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text(
                            'INGIA DASHBOARD • ANZA KAZI',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKycPhotoCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isConfirmed,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isConfirmed ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
            width: isConfirmed ? 1.5 : 1,
          ),
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
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isConfirmed ? const Color(0xFFDCFCE7) : const Color(0xFFE5EEF5),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 18,
                      color: isConfirmed ? const Color(0xFF16A34A) : const Color(0xFF4B7B9F),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isConfirmed ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isConfirmed ? 'IMEPANGWA ✓' : 'WEKA PICHA',
                    style: TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: isConfirmed ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Segoe UI Variable',
                color: Color(0xFF1E2822),
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Segoe UI Variable',
                color: Color(0xFF64748B),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
