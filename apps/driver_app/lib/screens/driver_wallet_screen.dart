import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';

class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen> {
  double _debt = 0.0;
  bool _isLocked = false;
  List<CargoOrder> _trips = [];
  bool _isProcessingPayment = false;

  String _selectedProvider = 'mpesa';
  double _selectedAmount = 5000.0;

  final List<Map<String, dynamic>> _providers = [
    {
      'id': 'mpesa',
      'name': 'M-Pesa',
      'brand': 'Vodacom',
      'gradient': const LinearGradient(
        colors: [Color(0xFFE60000), Color(0xFF990000)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'tag': 'Vodacom Tanzania',
    },
    {
      'id': 'tigopesa',
      'name': 'Tigo Pesa',
      'brand': 'Mixx by Yas',
      'gradient': const LinearGradient(
        colors: [Color(0xFF00377B), Color(0xFF0056B3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'tag': 'Yas Tanzania',
    },
    {
      'id': 'airtelmoney',
      'name': 'Airtel Money',
      'brand': 'Airtel',
      'gradient': const LinearGradient(
        colors: [Color(0xFFED1C24), Color(0xFF8B0000)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'tag': 'Airtel Tanzania',
    },
    {
      'id': 'halopesa',
      'name': 'HaloPesa',
      'brand': 'Halotel',
      'gradient': const LinearGradient(
        colors: [Color(0xFFFF6600), Color(0xFFB84500)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'tag': 'Halotel Tanzania',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    try {
      final debt = await SessionManager.getWalletDebt();
      final locked = await SessionManager.isDebtLimitExceeded();
      final trips = await SessionManager.getCompletedTrips();

      if (mounted) {
        setState(() {
          _debt = debt;
          _isLocked = locked;
          _trips = trips;
          if (_debt > 0 && _debt < _selectedAmount) {
            _selectedAmount = _debt;
          }
        });
      }
    } catch (_) {}
  }

  String _getProviderDisplayName(String id) {
    final match = _providers.firstWhere((p) => p['id'] == id, orElse: () => _providers[0]);
    return match['name'] as String;
  }

  Future<void> _payCommission() async {
    if (_selectedAmount <= 0) return;

    setState(() => _isProcessingPayment = true);

    final driver = await SessionManager.getDriver();
    final phone = driver?.phone ?? '+255 714 882 109';
    final providerName = _getProviderDisplayName(_selectedProvider);

    if (!mounted) return;

    // Show realistic USSD Push dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.phone_android_rounded, color: Color(0xFF16A34A), size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'USSD Push ya Malipo',
                style: TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
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
            Text(
              'Ombi la malipo ya TZS ${_selectedAmount.toStringAsFixed(0)} limerushwa kwenda namba yako ($phone) kupitia $providerName.',
              style: const TextStyle(
                fontFamily: 'Segoe UI Variable',
                fontSize: 13,
                color: Color(0xFF1E2822),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.lock_outline_rounded, color: Color(0xFF64748B), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tafadhali weka PIN ya mtandao kwenye skrini ya simu yako kukamilisha.',
                      style: TextStyle(
                        fontFamily: 'Segoe UI Variable',
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF16A34A)),
              ),
            ),
          ],
        ),
      ),
    );

    // Call Real Laravel Backend API
    final res = await ApiService.initiateWalletPayment(
      phone: phone,
      amount: _selectedAmount,
      paymentMethod: _selectedProvider,
    );

    await Future.delayed(const Duration(milliseconds: 1800));

    // Deduct debt locally
    await SessionManager.payWalletDebt(_selectedAmount);

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // Dismiss USSD dialog

    setState(() => _isProcessingPayment = false);
    await _loadWallet();

    if (!mounted) return;
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message'] ?? 'Malipo ya TZS ${_selectedAmount.toStringAsFixed(0)} yamekamilika kikamilifu!'),
        backgroundColor: const Color(0xFF16A34A),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double remainingBuffer = (10000.0 - _debt).clamp(0.0, 10000.0);
    final providerName = _getProviderDisplayName(_selectedProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E2822)),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Pochi ya Dereva',
          style: TextStyle(
            fontFamily: 'Segoe UI Variable',
            color: Color(0xFF1E2822),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Clean Balance / Debt Card (No clutter)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'DENI LA KAMASHENI (7%)',
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          color: Color(0xFF64748B),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isLocked ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _isLocked ? 'KAZI ZIMEFUNGWA ✕' : 'RUHUSA HAI ✓',
                          style: TextStyle(
                            fontFamily: 'Segoe UI Variable',
                            color: _isLocked ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        'TZS ${_debt.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          color: _isLocked ? const Color(0xFFEF4444) : const Color(0xFF1E2822),
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '/ Ukomo TZS 10,000',
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (_debt / 10000.0).clamp(0.0, 1.0),
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isLocked
                            ? const Color(0xFFEF4444)
                            : _debt > 7000
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF16A34A),
                      ),
                      minHeight: 7,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLocked
                        ? 'Deni limezidi ukomo. Lipa sasa ili uweze kupokea oda mpya za mizigo.'
                        : 'Nafasi iliyobaki kabla ya ukomo wa deni: TZS ${remainingBuffer.toStringAsFixed(0)}.',
                    style: TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      color: _isLocked ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. Mobile Money Actual Brand Cards
            const Text(
              'Chagua Mtandao wa Malipo',
              style: TextStyle(
                fontFamily: 'Segoe UI Variable',
                color: Color(0xFF1E2822),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _providers.length,
                itemBuilder: (context, idx) {
                  final p = _providers[idx];
                  final isSelected = _selectedProvider == p['id'];
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedProvider = p['id'] as String);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 170,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: p['gradient'] as LinearGradient,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? (p['gradient'] as LinearGradient).colors.first.withValues(alpha: 0.4)
                                : Colors.black.withValues(alpha: 0.08),
                            blurRadius: isSelected ? 10 : 4,
                            offset: const Offset(0, 3),
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
                              _buildCardLogo(p['id'] as String),
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check,
                                    size: 11,
                                    color: (p['gradient'] as LinearGradient).colors.first,
                                  ),
                                )
                              else
                                Icon(
                                  Icons.contactless_rounded,
                                  size: 16,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['name'] as String,
                                style: const TextStyle(
                                  fontFamily: 'Segoe UI Variable',
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p['tag'] as String,
                                style: TextStyle(
                                  fontFamily: 'Segoe UI Variable',
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 18),

            // 3. Amount Selector Pills
            const Text(
              'Chagua Kiasi cha Kulipa',
              style: TextStyle(
                fontFamily: 'Segoe UI Variable',
                color: Color(0xFF1E2822),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                _buildAmountPill(2000.0),
                const SizedBox(width: 8),
                _buildAmountPill(5000.0),
                const SizedBox(width: 8),
                _buildAmountPill(10000.0),
                if (_debt > 0) ...[
                  const SizedBox(width: 8),
                  _buildDebtFullPill(),
                ],
              ],
            ),

            const SizedBox(height: 20),

            // 4. Pay Action Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isProcessingPayment ? null : _payCommission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isProcessingPayment
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'LIPA TZS ${_selectedAmount.toStringAsFixed(0)} KUPITIA $providerName',
                            style: const TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // 5. Minimalist Recent Ledger
            const Text(
              'Historia ya Miamala',
              style: TextStyle(
                fontFamily: 'Segoe UI Variable',
                color: Color(0xFF1E2822),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),

            if (_trips.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Text(
                    'Hakuna miamala ya kamasheni iliyorekodiwa leo.',
                    style: TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _trips.take(4).length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Color(0xFFF1F5F9),
                  ),
                  itemBuilder: (context, idx) {
                    final t = _trips[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.tripId,
                                style: const TextStyle(
                                  fontFamily: 'Segoe UI Variable',
                                  color: Color(0xFF1E2822),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Nauli: ${t.fareAmount}',
                                style: const TextStyle(
                                  fontFamily: 'Segoe UI Variable',
                                  color: Color(0xFF64748B),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '- TZS ${t.commissionAmount.toStringAsFixed(0)} (7%)',
                            style: const TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              color: Color(0xFFEF4444),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildCardLogo(String providerId) {
    switch (providerId) {
      case 'mpesa':
        return Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFE60000), size: 10),
              ),
            ),
            const SizedBox(width: 5),
            const Text(
              'M-PESA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ],
        );
      case 'tigopesa':
        return Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF00377B),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFFACC15), width: 1.2),
              ),
              child: const Text(
                'tigo',
                style: TextStyle(
                  color: Color(0xFFFACC15),
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'pesa',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
              ),
            ),
          ],
        );
      case 'airtelmoney':
        return Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: Text(
                  'a',
                  style: TextStyle(
                    color: Color(0xFFED1C24),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'airtel',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        );
      case 'halopesa':
      default:
        return Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: Text(
                  'H',
                  style: TextStyle(
                    color: Color(0xFFFF6600),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'halopesa',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildAmountPill(double amt) {
    final isSelected = _selectedAmount == amt;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedAmount = amt);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF16A34A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '${(amt / 1000).toStringAsFixed(0)}k',
              style: TextStyle(
                fontFamily: 'Segoe UI Variable',
                color: isSelected ? Colors.white : const Color(0xFF1E2822),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDebtFullPill() {
    final isSelected = _selectedAmount == _debt;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedAmount = _debt);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF16A34A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              'Deni (${(_debt / 1000).toStringAsFixed(1)}k)',
              style: TextStyle(
                fontFamily: 'Segoe UI Variable',
                color: isSelected ? Colors.white : const Color(0xFF1E2822),
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
