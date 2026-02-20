import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/trip_service.dart';
import '../services/booking_service.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with TickerProviderStateMixin {
  static const _bg = Color(0xFF0A0E1A);
  static const _surface = Color(0xFF121826);
  static const _card = Color(0xFF1A2235);
  static const _accent = Color(0xFF6C63FF);
  static const _accentGlow = Color(0x446C63FF);
  static const _border = Color(0xFF2A3550);
  static const _textPrimary = Color(0xFFE8EDF5);
  static const _textSecondary = Color(0xFF8A96B0);
  static const _success = Color(0xFF00E5A0);
  static const _errorColor = Color(0xFFFF5C7A);
  static const _warning = Color(0xFFFFB347);

  late TabController _tabCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // Data
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _myTrips = [];
  bool _loadingBookings = true;
  bool _loadingTrips = true;
  String? _errorBookings;
  String? _errorTrips;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _fetchBookings();
    _fetchMyTrips();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _loadingBookings = true;
      _errorBookings = null;
    });
    try {
      final data = await TripService.instance.getBookings();
      if (mounted) {
        setState(() {
          _bookings = data;
          _loadingBookings = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorBookings = e.toString().replaceFirst('Exception: ', '');
          _loadingBookings = false;
        });
      }
    }
  }

  Future<void> _fetchMyTrips() async {
    setState(() {
      _loadingTrips = true;
      _errorTrips = null;
    });
    try {
      final data = await TripService.instance.getMyTrips();
      if (mounted) {
        setState(() {
          _myTrips = data;
          _loadingTrips = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorTrips = e.toString().replaceFirst('Exception: ', '');
          _loadingTrips = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [_buildBookingsTab(), _buildMyTripsTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_accent, Color(0xFF8B7BFF)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: _textSecondary,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.confirmation_num_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('My Bookings'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.directions_car_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('My Trips'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOOKINGS TAB
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBookingsTab() {
    if (_loadingBookings) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }
    if (_errorBookings != null) {
      return _buildErrorState(_errorBookings!, _fetchBookings);
    }
    if (_bookings.isEmpty) {
      return _buildEmptyState(
        icon: Icons.confirmation_num_rounded,
        title: 'No bookings yet',
        subtitle: 'Book a ride from the home screen!',
      );
    }

    return RefreshIndicator(
      color: _accent,
      backgroundColor: _card,
      onRefresh: _fetchBookings,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        itemCount: _bookings.length,
        itemBuilder: (_, i) => _buildBookingCard(_bookings[i]),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final trip = booking['trip'] as Map<String, dynamic>?;
    final origin = trip?['origin'] ?? 'Unknown';
    final destination = trip?['destination'] ?? 'Unknown';
    final driverName = trip?['driver']?['name'] ?? 'Unknown Driver';
    final status = booking['status'] ?? 'pending';
    final seats = booking['seatsBooked'] ?? 1;
    final fare = booking['totalFare']?.toStringAsFixed(2) ?? '0.00';
    final createdAt = _formatDate(booking['createdAt']);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status + Date header ──────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusChip(status),
              Text(
                createdAt,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Route ─────────────────────────────────────────────────
          Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _success,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: _success.withAlpha(80), blurRadius: 6),
                      ],
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 24,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _success.withAlpha(60),
                          _errorColor.withAlpha(60),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _errorColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _errorColor.withAlpha(80),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      origin,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: _border.withAlpha(80)),
          const SizedBox(height: 12),

          // ── Bottom info ───────────────────────────────────────────
          Row(
            children: [
              // Driver
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: _accent.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: _accent,
                  size: 14,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  driverName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Seats
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_seat_rounded,
                      color: _textSecondary,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$seats',
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Fare
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1440), Color(0xFF2A1B5E)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _accent.withAlpha(50)),
                ),
                child: Text(
                  '\$$fare ALGO',
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          // ── Action buttons for pending / confirmed ──────────────────
          if (status == 'pending') ..._buildPendingActions(booking),
          if (status == 'confirmed' && booking['paymentTxId'] != null)
            _buildTxLink(booking['paymentTxId']),
        ],
      ),
    );
  }

  List<Widget> _buildPendingActions(Map<String, dynamic> booking) {
    return [
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        height: 42,
        child: ElevatedButton.icon(
          onPressed: () => _showPaymentDialog(booking),
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          icon: const Icon(Icons.account_balance_wallet_rounded, size: 16),
          label: const Text(
            'Pay Now',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ];
  }

  void _showPaymentDialog(Map<String, dynamic> booking) {
    final trip = booking['trip'] as Map<String, dynamic>?;
    final driverWallet = trip?['driver']?['walletAddress'] as String? ?? '';
    final fare = booking['totalFare']?.toDouble() ?? 0.0;
    final bookingId = booking['id'] ?? '';
    final txCtrl = TextEditingController();

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
            Text(
              'Send ${fare.toStringAsFixed(6)} ALGO to:',
              style: const TextStyle(color: _textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: driverWallet));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: const Text('Address copied!'),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        driverWallet.length > 20
                            ? '${driverWallet.substring(0, 10)}...${driverWallet.substring(driverWallet.length - 8)}'
                            : driverWallet,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const Icon(Icons.copy_rounded, color: _accent, size: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: txCtrl,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                hintText: 'Paste Transaction ID...',
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
                  borderSide: const BorderSide(color: _accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.paste_rounded,
                    color: _textSecondary,
                    size: 16,
                  ),
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) txCtrl.text = data!.text!;
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final txId = txCtrl.text.trim();
              if (txId.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await BookingService.instance.confirmPayment(
                  bookingId: bookingId,
                  txId: txId,
                );
                if (mounted) {
                  _fetchBookings();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Payment verified & confirmed!'),
                      backgroundColor: _success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString().replaceFirst('Exception: ', ''),
                      ),
                      backgroundColor: _errorColor,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _success,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Verify & Confirm',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTxLink(String txId) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        onTap: () {
          final url = Uri.parse(
            'https://testnet.explorer.perawallet.app/tx/$txId',
          );
          launchUrl(url, mode: LaunchMode.externalApplication);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _success.withAlpha(12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _success.withAlpha(40)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_rounded, color: _success, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tx: ${txId.length > 16 ? '${txId.substring(0, 8)}...${txId.substring(txId.length - 6)}' : txId}',
                  style: const TextStyle(
                    color: _success,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.open_in_new_rounded, color: _success, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MY TRIPS TAB
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMyTripsTab() {
    if (_loadingTrips) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }
    if (_errorTrips != null) {
      return _buildErrorState(_errorTrips!, _fetchMyTrips);
    }
    if (_myTrips.isEmpty) {
      return _buildEmptyState(
        icon: Icons.directions_car_rounded,
        title: 'No trips offered yet',
        subtitle: 'Tap + to create your first trip!',
      );
    }

    return RefreshIndicator(
      color: _accent,
      backgroundColor: _card,
      onRefresh: _fetchMyTrips,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        itemCount: _myTrips.length,
        itemBuilder: (_, i) => _buildMyTripCard(_myTrips[i]),
      ),
    );
  }

  Widget _buildMyTripCard(Map<String, dynamic> trip) {
    final origin = trip['origin'] ?? 'Unknown';
    final destination = trip['destination'] ?? 'Unknown';
    final status = trip['status'] ?? 'active';
    final price = trip['price']?.toStringAsFixed(2) ?? '0.00';
    final seats = trip['seatsAvailable'] ?? 0;
    final departureLabel = _formatDeparture(trip['departureTime']);
    final bookings = trip['bookings'] as List? ?? [];
    final bookedCount = bookings.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status + Price header ─────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusChip(status),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1440), Color(0xFF2A1B5E)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _accent.withAlpha(50)),
                ),
                child: Text(
                  '\$$price ALGO',
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Route ─────────────────────────────────────────────────
          Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _success,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: _success.withAlpha(80), blurRadius: 6),
                      ],
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 24,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _success.withAlpha(60),
                          _errorColor.withAlpha(60),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _errorColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _errorColor.withAlpha(80),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      origin,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: _border.withAlpha(80)),
          const SizedBox(height: 12),

          // ── Bottom info ───────────────────────────────────────────
          Row(
            children: [
              // Bookings count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bookedCount > 0 ? _success.withAlpha(15) : _surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: bookedCount > 0
                        ? _success.withAlpha(60)
                        : _border.withAlpha(80),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.people_rounded,
                      color: bookedCount > 0 ? _success : _textSecondary,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$bookedCount booked',
                      style: TextStyle(
                        color: bookedCount > 0 ? _success : _textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Seats remaining
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_seat_rounded,
                      color: _textSecondary,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$seats left',
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Departure
              if (departureLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _border.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        color: _textSecondary,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        departureLabel,
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case 'active':
        color = _success;
        icon = Icons.radio_button_checked_rounded;
        label = 'Active';
        break;
      case 'confirmed':
        color = _accent;
        icon = Icons.check_circle_rounded;
        label = 'Confirmed';
        break;
      case 'in_progress':
        color = _warning;
        icon = Icons.directions_car_rounded;
        label = 'In Progress';
        break;
      case 'completed':
        color = const Color(0xFF00C6FF);
        icon = Icons.done_all_rounded;
        label = 'Completed';
        break;
      case 'cancelled':
        color = _errorColor;
        icon = Icons.cancel_rounded;
        label = 'Cancelled';
        break;
      case 'pending':
      default:
        color = _warning;
        icon = Icons.hourglass_top_rounded;
        label = 'Pending';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _accentGlow,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _accent.withAlpha(120), size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: _textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              color: _textSecondary.withAlpha(80),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
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
      return '${months[dt.month]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  String _formatDeparture(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
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
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month]} ${dt.day} · $hour:$minute $amPm';
    } catch (_) {
      return '';
    }
  }
}
