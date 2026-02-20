import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/booking_service.dart';
import '../services/algorand_service.dart';

/// Full-screen ride detail & booking page.
/// Shows trip info, seat selector, fare, and ALGO payment flow.
class RideDetailScreen extends StatefulWidget {
  final Map<String, dynamic> trip;

  const RideDetailScreen({super.key, required this.trip});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen>
    with SingleTickerProviderStateMixin {
  // Design tokens — matching app-wide palette
  static const _bg = Color(0xFF0A0E1A);
  static const _surface = Color(0xFF121826);
  static const _card = Color(0xFF1A2235);
  static const _accent = Color(0xFF6C63FF);
  static const _border = Color(0xFF2A3550);
  static const _textPrimary = Color(0xFFE8EDF5);
  static const _textSecondary = Color(0xFF8A96B0);
  static const _success = Color(0xFF00E5A0);
  static const _errorColor = Color(0xFFFF5C7A);
  static const _peraYellow = Color(0xFFFFEE55);

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  int _seats = 1;
  bool _isBooking = false;
  bool _isConfirming = false;
  String? _bookingId;
  String? _error;
  bool _bookingSuccess = false;

  final _txIdCtrl = TextEditingController();

  Map<String, dynamic> get trip => widget.trip;
  int get maxSeats => trip['seatsAvailable'] ?? 1;
  double get pricePerSeat => (trip['price'] as num?)?.toDouble() ?? 0.0;
  double get totalFare => pricePerSeat * _seats;
  int get totalFareMicroAlgos => (totalFare * 1000000).round();

  String get driverWallet => trip['driver']?['walletAddress'] as String? ?? '';
  String get driverName => trip['driver']?['name'] ?? 'Unknown Driver';
  String get origin => trip['origin'] ?? 'Unknown';
  String get destination => trip['destination'] ?? 'Unknown';

  bool get isOwnTrip {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && trip['driverId'] == user.uid;
  }

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _txIdCtrl.dispose();
    super.dispose();
  }

  // ── BOOKING FLOW ─────────────────────────────────────────────────────────

  Future<void> _createBooking() async {
    setState(() {
      _isBooking = true;
      _error = null;
    });

    try {
      final booking = await BookingService.instance.createBooking(
        tripId: trip['id'],
        seatsBooked: _seats,
      );
      if (mounted) {
        setState(() {
          _bookingId = booking['id'];
          _isBooking = false;
        });
        // Now open Pera Wallet for payment
        _openPeraWallet();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isBooking = false;
        });
      }
    }
  }

  void _openPeraWallet() async {
    if (driverWallet.isEmpty) {
      setState(() => _error = 'Driver has not connected a wallet');
      return;
    }

    // Construct Pera Wallet deep-link for payment
    final note = 'AlgoRide:${_bookingId ?? "booking"}';
    final peraUri = Uri.parse(
      'perawallet://payment?receiver=$driverWallet'
      '&amount=$totalFareMicroAlgos'
      '&note=$note',
    );

    try {
      final canOpen = await canLaunchUrl(peraUri);
      if (canOpen) {
        await launchUrl(peraUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: show manual payment instructions
        if (mounted) _showManualPaymentDialog();
      }
    } catch (_) {
      if (mounted) _showManualPaymentDialog();
    }
  }

  void _showManualPaymentDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Complete Payment',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Send the following payment using Pera Wallet:',
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              'To',
              driverWallet.length > 16
                  ? '${driverWallet.substring(0, 8)}...${driverWallet.substring(driverWallet.length - 6)}'
                  : driverWallet,
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Amount', '${totalFare.toStringAsFixed(6)} ALGO'),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: driverWallet));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: const Text('Wallet address copied!'),
                    backgroundColor: _success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _accent.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _accent.withAlpha(50)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.copy_rounded, color: _accent, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Copy Wallet Address',
                      style: TextStyle(
                        color: _accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done', style: TextStyle(color: _accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmPayment() async {
    final txId = _txIdCtrl.text.trim();
    if (txId.isEmpty) {
      setState(() => _error = 'Please enter the transaction ID');
      return;
    }
    if (_bookingId == null) {
      setState(() => _error = 'No booking to confirm');
      return;
    }

    setState(() {
      _isConfirming = true;
      _error = null;
    });

    try {
      await BookingService.instance.confirmPayment(
        bookingId: _bookingId!,
        txId: txId,
      );
      if (mounted) {
        setState(() {
          _isConfirming = false;
          _bookingSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isConfirming = false;
        });
      }
    }
  }

  // ── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRouteCard(),
                      const SizedBox(height: 16),
                      _buildDriverCard(),
                      const SizedBox(height: 16),
                      if (!isOwnTrip && !_bookingSuccess) ...[
                        _buildSeatSelector(),
                        const SizedBox(height: 16),
                        _buildFareCard(),
                        if (_bookingId != null) ...[
                          const SizedBox(height: 16),
                          _buildTxIdInput(),
                        ],
                      ],
                      if (_bookingSuccess) ...[
                        const SizedBox(height: 16),
                        _buildSuccessCard(),
                      ],
                      if (isOwnTrip) ...[
                        const SizedBox(height: 16),
                        _buildOwnTripNotice(),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _buildErrorBanner(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomSheet: (!isOwnTrip && !_bookingSuccess)
          ? _buildBottomAction()
          : null,
    );
  }

  // ── APP BAR ──────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context, _bookingSuccess),
            icon: const Icon(Icons.arrow_back_rounded, color: _textPrimary),
          ),
          const Expanded(
            child: Text(
              'Ride Details',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _success.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _success.withAlpha(50)),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_seat_rounded, color: _success, size: 14),
                const SizedBox(width: 4),
                Text(
                  '$maxSeats seats left',
                  style: const TextStyle(
                    color: _success,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── ROUTE CARD ───────────────────────────────────────────────────────────

  Widget _buildRouteCard() {
    String departureLabel = '';
    if (trip['departureTime'] != null) {
      try {
        final dt = DateTime.parse(trip['departureTime']).toLocal();
        final months = [
          '',
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        final hour = dt.hour > 12
            ? dt.hour - 12
            : (dt.hour == 0 ? 12 : dt.hour);
        final amPm = dt.hour >= 12 ? 'PM' : 'AM';
        final minute = dt.minute.toString().padLeft(2, '0');
        departureLabel = '${months[dt.month]} ${dt.day} · $hour:$minute $amPm';
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Route dots
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _success,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _success.withAlpha(100),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 40,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _success.withAlpha(80),
                          _errorColor.withAlpha(80),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _errorColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _errorColor.withAlpha(100),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PICKUP',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      origin,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'DROP-OFF',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      destination,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (departureLabel.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border.withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    color: _textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Departure: $departureLabel',
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── DRIVER CARD ──────────────────────────────────────────────────────────

  Widget _buildDriverCard() {
    final rating = trip['driver']?['rating']?.toStringAsFixed(1) ?? '—';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_accent, Color(0xFF8B7BFF)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                driverName.isNotEmpty ? driverName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driverName,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Driver',
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (rating != '—')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFFFD700).withAlpha(40),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFD700),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    rating,
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── SEAT SELECTOR ────────────────────────────────────────────────────────

  Widget _buildSeatSelector() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_seat_rounded, color: _accent, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seats',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Select number of seats',
                  style: TextStyle(color: _textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          // Stepper
          Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                _buildStepperButton(
                  icon: Icons.remove_rounded,
                  onTap: _seats > 1 && _bookingId == null
                      ? () => setState(() => _seats--)
                      : null,
                ),
                Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: Text(
                    '$_seats',
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _buildStepperButton(
                  icon: Icons.add_rounded,
                  onTap: _seats < maxSeats && _bookingId == null
                      ? () => setState(() => _seats++)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperButton({required IconData icon, VoidCallback? onTap}) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Icon(
          icon,
          color: enabled ? _accent : _textSecondary.withAlpha(60),
          size: 20,
        ),
      ),
    );
  }

  // ── FARE CARD ────────────────────────────────────────────────────────────

  Widget _buildFareCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1F3D), Color(0xFF0F1328)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withAlpha(40)),
        boxShadow: [
          BoxShadow(
            color: _accent.withAlpha(15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Fare',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$_seats × ${pricePerSeat.toStringAsFixed(2)} ALGO',
                style: const TextStyle(color: _textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                totalFare.toStringAsFixed(6),
                style: const TextStyle(
                  color: _accent,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 6, left: 6),
                child: Text(
                  'ALGO',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── TX ID INPUT ──────────────────────────────────────────────────────────

  Widget _buildTxIdInput() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _peraYellow.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _peraYellow.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: _peraYellow,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confirm Payment',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Paste the transaction ID from Pera Wallet',
                      style: TextStyle(color: _textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _txIdCtrl,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: 'Transaction ID (e.g. ABCDE...)',
              hintStyle: const TextStyle(color: _textSecondary, fontSize: 12),
              filled: true,
              fillColor: _surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _peraYellow, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              suffixIcon: IconButton(
                icon: const Icon(
                  Icons.paste_rounded,
                  color: _textSecondary,
                  size: 18,
                ),
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) {
                    _txIdCtrl.text = data!.text!;
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isConfirming ? null : _confirmPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: _success,
                foregroundColor: Colors.black87,
                disabledBackgroundColor: _success.withAlpha(80),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              icon: _isConfirming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black54,
                      ),
                    )
                  : const Icon(Icons.verified_rounded, size: 18),
              label: Text(
                _isConfirming ? 'Verifying...' : 'Verify & Confirm',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── SUCCESS CARD ─────────────────────────────────────────────────────────

  Widget _buildSuccessCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _success.withAlpha(15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _success.withAlpha(50)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _success.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: _success,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Booking Confirmed!',
            style: TextStyle(
              color: _success,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your ride has been booked and payment verified on-chain.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _success,
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Back to Home',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── OWN TRIP NOTICE ──────────────────────────────────────────────────────

  Widget _buildOwnTripNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accent.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withAlpha(40)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: _accent, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'This is your trip. You cannot book your own ride.',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── ERROR BANNER ─────────────────────────────────────────────────────────

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _errorColor.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _errorColor.withAlpha(40)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _errorColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color: _errorColor,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _error = null),
            child: const Icon(
              Icons.close_rounded,
              color: _textSecondary,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  // ── BOTTOM ACTION BUTTON ─────────────────────────────────────────────────

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border.withAlpha(80))),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: _bookingId == null
              ? ElevatedButton.icon(
                  onPressed: (_isBooking || maxSeats == 0)
                      ? null
                      : _createBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _accent.withAlpha(80),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  icon: _isBooking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white70,
                          ),
                        )
                      : const Icon(Icons.bolt_rounded, size: 22),
                  label: Text(
                    _isBooking
                        ? 'Booking...'
                        : 'Book & Pay ${totalFare.toStringAsFixed(2)} ALGO',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: _openPeraWallet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _peraYellow,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 22,
                  ),
                  label: const Text(
                    'Open Pera Wallet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
        ),
      ),
    );
  }
}
