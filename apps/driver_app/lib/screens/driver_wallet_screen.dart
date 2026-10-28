import 'package:flutter/material.dart';
import '../models/order_model.dart';
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

  String _selectedProvider = 'M-Pesa';
  double _selectedAmount = 10000.0;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    final debt = await SessionManager.getWalletDebt();
    final locked = await SessionManager.isDebtLimitExceeded();
    final trips = await SessionManager.getCompletedTrips();

    if (mounted) {
      setState(() {
        _debt = debt;
        _isLocked = locked;
        _trips = trips;
      });
    }
  }

  void _payCommission() async {
    setState(() => _isProcessingPayment = true);

    // Simulate mobile money push prompt
    await Future.delayed(const Duration(milliseconds: 1600));
    await SessionManager.payWalletDebt(_selectedAmount);

    if (!mounted) return;
    setState(() => _isProcessingPayment = false);
    await _loadWallet();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Malipo ya TZS ${_selectedAmount.toStringAsFixed(0)} kupitia $_selectedProvider yamefanikiwa!'),
        backgroundColor: const Color(0xFF22C55E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double remainingBuffer = (10000.0 - _debt).clamp(0.0, 10000.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text(
          'Pochi ya Kamasheni (Driver Wallet)',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8), size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Wateja wanakupa pesa taslimu (Cash) mkononi 100%. Kamasheni ya CARGOO ni 7% tu. Fanya kazi kwa uhuru mpaka deni lifikie ukomo wa TZS 10,000.',
                        style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Debt Meter Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _isLocked ? const Color(0xFF3B1515) : const Color(0xFF162032),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isLocked ? const Color(0xFFEF4444) : const Color(0xFF334155),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SALIO LA DENI LA KAMASHENI (7%)',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isLocked ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _isLocked ? 'KAZI ZIMEFUNGWA' : 'RUHUSA HAI',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'TZS ${_debt.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: _isLocked ? const Color(0xFFEF4444) : Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '/ Ukomo TZS 10,000',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (_debt / 10000.0).clamp(0.0, 1.0),
                        backgroundColor: const Color(0xFF334155),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _isLocked
                              ? const Color(0xFFEF4444)
                              : _debt > 7000
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF22C55E),
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isLocked
                          ? 'Umezidi kiwango cha deni. Lipa sasa ili uweze kupokea kazi tena.'
                          : 'Bado una nafasi ya kufanya safari zenye thamani ya TZS ${(remainingBuffer / 0.07).toStringAsFixed(0)} bila kufungiwa.',
                      style: TextStyle(
                        color: _isLocked ? const Color(0xFFFCA5A5) : const Color(0xFF94A3B8),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Payment Section
              const Text(
                'LIPA KAMASHENI (TOP UP / CLEAR DEBT)',
                style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(height: 12),

              // Provider options
              Row(
                children: [
                  _providerCard('M-Pesa', const Color(0xFFDC2626)),
                  const SizedBox(width: 10),
                  _providerCard('Tigo Pesa', const Color(0xFF0284C7)),
                  const SizedBox(width: 10),
                  _providerCard('Airtel Money', const Color(0xFFE11D48)),
                ],
              ),

              const SizedBox(height: 16),

              // Amount Chips
              Row(
                children: [
                  _amountChip(5000.0),
                  const SizedBox(width: 10),
                  _amountChip(10000.0),
                  const SizedBox(width: 10),
                  _amountChip(20000.0),
                ],
              ),

              const SizedBox(height: 20),

              // Pay Action Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isProcessingPayment ? null : _payCommission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isProcessingPayment
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'LIPA TZS ${_selectedAmount.toStringAsFixed(0)} KUPITIA $_selectedProvider',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                ),
              ),

              const SizedBox(height: 28),

              // Trips History / Ledger
              const Text(
                'HISTORIA YA KAMASHENI ZA SAFARI (7%)',
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              if (_trips.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Bado haujakamilisha safari yoyote leo.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _trips.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final t = _trips[idx];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.tripId,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${t.pickupName} ➔ ${t.dropoffName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                t.fareAmount,
                                style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                '- TZS ${t.commissionAmount.toStringAsFixed(0)} (7%)',
                                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _providerCard(String name, Color color) {
    final isSelected = _selectedProvider == name;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedProvider = name),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0x33DC2626) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : const Color(0xFF334155),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              name,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _amountChip(double amt) {
    final isSelected = _selectedAmount == amt;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedAmount = amt),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF22C55E) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? const Color(0xFF22C55E) : const Color(0xFF334155)),
          ),
          child: Center(
            child: Text(
              '${(amt / 1000).toStringAsFixed(0)}k TZS',
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
