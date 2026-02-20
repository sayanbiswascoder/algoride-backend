import 'dart:async';
import 'package:flutter/material.dart';
import 'wallet_screen.dart';
import 'add_trip_screen.dart';
import 'activity_screen.dart';
import 'ride_detail_screen.dart';
import '../services/auth_service.dart';
import '../services/trip_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentNavIndex = 0;

  // Search controllers
  final _pickupCtrl = TextEditingController();
  final _dropCtrl = TextEditingController();
  Timer? _searchDebounce;

  // Trip data
  List<Map<String, dynamic>> _trips = [];
  bool _isLoading = true;
  String? _error;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // Colour palette — matching the existing Stitch design system
  static const _bg = Color(0xFF0A0E1A);
  static const _surface = Color(0xFF121826);
  static const _card = Color(0xFF1A2235);
  static const _accent = Color(0xFF6C63FF);
  static const _accentGlow = Color(0x446C63FF);
  static const _border = Color(0xFF2A3550);
  static const _textPrimary = Color(0xFFE8EDF5);
  static const _textSecondary = Color(0xFF8A96B0);
  static const _success = Color(0xFF00E5A0);
  static const _error_ = Color(0xFFFF5C7A);

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _fadeCtrl.forward();
    });

    _fetchTrips();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pickupCtrl.dispose();
    _dropCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────
  Future<void> _fetchTrips() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final trips = await TripService.instance.getTrips(
        origin: _pickupCtrl.text.trim().isEmpty
            ? null
            : _pickupCtrl.text.trim(),
        destination: _dropCtrl.text.trim().isEmpty
            ? null
            : _dropCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _trips = trips;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _fetchTrips();
    });
  }

  void _showAccountMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Account',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await AuthService.instance.signOut();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _error_,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return SafeArea(
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBars(),
            Expanded(child: _buildRideList()),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: IndexedStack(
        index: _currentNavIndex <= 3 ? _currentNavIndex : 0,
        children: [
          _buildHomeContent(), // 0 — Home
          const ActivityScreen(), // 1 — Activity
          const SizedBox.shrink(), // 2 — placeholder (FAB)
          const WalletScreen(), // 3 — Wallet
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AlgoRide',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Find your next ride',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _success.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _success.withAlpha(60)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: _success.withAlpha(80), blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_trips.length} rides',
                  style: const TextStyle(
                    color: _success,
                    fontSize: 12,
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

  // ═══════════════════════════════════════════════════════════════════════════
  // SEARCH BARS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSearchBars() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Pickup
          _buildSearchField(
            controller: _pickupCtrl,
            hint: 'Pickup location',
            dotColor: _success,
            icon: Icons.trip_origin_rounded,
          ),
          // Connector line
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Row(
              children: [
                Container(
                  width: 2,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_success.withAlpha(60), _error_.withAlpha(60)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Drop-off
          _buildSearchField(
            controller: _dropCtrl,
            hint: 'Drop-off location',
            dotColor: _error_,
            icon: Icons.location_on_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String hint,
    required Color dotColor,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border.withAlpha(120)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: dotColor.withAlpha(80), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => _onSearchChanged(),
              style: const TextStyle(color: _textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: _textSecondary, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                _onSearchChanged();
              },
              child: const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.close_rounded,
                  color: _textSecondary,
                  size: 18,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(icon, color: dotColor.withAlpha(100), size: 18),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RIDE LIST
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildRideList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }

    if (_error != null) {
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
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchTrips,
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

    if (_trips.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.directions_car_filled_rounded,
                color: _accent.withAlpha(60),
                size: 56,
              ),
              const SizedBox(height: 16),
              const Text(
                'No rides available',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Be the first to offer a ride!',
                style: TextStyle(color: _textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _accent,
      backgroundColor: _card,
      onRefresh: _fetchTrips,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        itemCount: _trips.length,
        itemBuilder: (context, index) {
          final trip = _trips[index];
          return GestureDetector(
            onTap: () async {
              final booked = await Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => RideDetailScreen(trip: trip),
                  transitionsBuilder: (_, animation, __, child) {
                    return SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: child,
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 350),
                ),
              );
              if (booked == true && mounted) _fetchTrips();
            },
            child: _buildTripCard(trip),
          );
        },
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final origin = trip['origin'] ?? 'Unknown';
    final destination = trip['destination'] ?? 'Unknown';
    final price = trip['price']?.toStringAsFixed(2) ?? '0.00';
    final seats = trip['seatsAvailable'] ?? 0;
    final driver = trip['driver'];
    final driverName = driver?['name'] ?? 'Unknown Driver';
    final rating = driver?['rating']?.toStringAsFixed(1) ?? '—';

    // Format departure time
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
          // ── Route row ──────────────────────────────────────────────
          Row(
            children: [
              // Route dots
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
                    height: 28,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_success.withAlpha(60), _error_.withAlpha(60)],
                      ),
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _error_,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: _error_.withAlpha(80), blurRadius: 6),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // Route texts
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
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Price badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1440), Color(0xFF2A1B5E)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _accent.withAlpha(60)),
                ),
                child: Column(
                  children: [
                    Text(
                      '\$$price',
                      style: const TextStyle(
                        color: _accent,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'ALGO',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Divider
          Container(height: 1, color: _border.withAlpha(80)),
          const SizedBox(height: 12),

          // ── Bottom info row ────────────────────────────────────────
          Row(
            children: [
              // Driver
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _accent.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: _accent,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  driverName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Rating
              if (rating != '—') ...[
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFFD700),
                  size: 14,
                ),
                const SizedBox(width: 3),
                Text(
                  rating,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
              ],

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
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$seats',
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Departure time
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
  // BOTTOM NAVIGATION BAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border, width: 0.5)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.explore_rounded, 'Explore', 0),
              _buildNavItem(Icons.receipt_long_rounded, 'Activity', 1),
              _buildAddTripButton(),
              _buildNavItem(Icons.account_balance_wallet_rounded, 'Wallet', 3),
              _buildNavItem(Icons.person_rounded, 'Account', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddTripButton() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const AddTripScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 350),
          ),
        );
        // Refresh trips when returning from add trip screen
        if (result == true && mounted) {
          _fetchTrips();
        }
      },
      child: Container(
        width: 56,
        height: 56,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_accent, Color(0xFF8B7BFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _accent.withAlpha(100),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: _accent.withAlpha(40),
              blurRadius: 32,
              spreadRadius: 4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isSelected = _currentNavIndex == index;

    return GestureDetector(
      onTap: () {
        if (index == 4) {
          _showAccountMenu();
          return;
        }
        setState(() => _currentNavIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _accentGlow : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? _accent : _textSecondary, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? _accent : _textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
