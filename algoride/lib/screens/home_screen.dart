import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final Completer<GoogleMapController> _mapController = Completer();
  int _currentNavIndex = 0;

  // Selected destination from search
  SelectedPlace? _selectedPlace;
  Set<Marker> _markers = {};

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
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

  // Default map position (New York)
  static const _initialPosition = CameraPosition(
    target: LatLng(40.7128, -74.0060),
    zoom: 14.0,
  );

  // Dark map style
  static const String _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#0a0e1a"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8a96b0"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0a0e1a"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#1a2235"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#121826"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#121826"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#1a2235"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#2a3550"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2a3550"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#1a2235"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0d1420"}]}
]
''';

  // Suggested rides data
  final List<Map<String, dynamic>> _suggestedRides = [
    {
      'name': 'Tesla Model 3',
      'type': 'Electric · Premium',
      'rating': 4.9,
      'price': '\$12.50',
      'eta': '3 min',
      'icon': Icons.electric_car_rounded,
      'color': Color(0xFF00E5A0),
    },
    {
      'name': 'Honda Civic',
      'type': 'Sedan · Economy',
      'rating': 4.7,
      'price': '\$8.00',
      'eta': '5 min',
      'icon': Icons.directions_car_rounded,
      'color': Color(0xFF6C63FF),
    },
    {
      'name': 'Toyota Camry',
      'type': 'Sedan · Comfort',
      'rating': 4.8,
      'price': '\$10.00',
      'eta': '4 min',
      'icon': Icons.directions_car_filled_rounded,
      'color': Color(0xFF00C6FF),
    },
  ];

  @override
  void initState() {
    super.initState();

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    // Stagger the animations
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _slideCtrl.forward();
        _fadeCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── Full-screen Google Map ──────────────────────────────────
          _buildMap(),

          // ── Top gradient overlay ───────────────────────────────────
          _buildTopGradient(),

          // ── Search bar ─────────────────────────────────────────────
          _buildSearchBar(),

          // ── Bottom sheet with rides ─────────────────────────────────
          _buildBottomSheet(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MAP
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: _initialPosition,
      mapType: MapType.normal,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      markers: _markers,
      onMapCreated: (GoogleMapController controller) {
        _mapController.complete(controller);
        controller.setMapStyle(_darkMapStyle);
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TOP GRADIENT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTopGradient() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 160,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xE60A0E1A), Color(0x000A0E1A)],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SEARCH BAR
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _openSearch() async {
    final result = await Navigator.of(context).push<SelectedPlace>(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const SearchScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
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

    if (result != null && mounted) {
      setState(() {
        _selectedPlace = result;
        _markers = {
          Marker(
            markerId: const MarkerId('destination'),
            position: result.latLng,
            infoWindow: InfoWindow(title: result.name),
          ),
        };
      });

      // Animate the camera to the selected place
      final controller = await _mapController.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: result.latLng, zoom: 15.0),
        ),
      );
    }
  }

  Widget _buildSearchBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 20,
      right: 20,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: GestureDetector(
          onTap: _openSearch,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // Pulsing green dot
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _selectedPlace != null ? _accent : _success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_selectedPlace != null ? _accent : _success)
                            .withAlpha(100),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _selectedPlace?.name ?? 'Where to?',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _selectedPlace != null
                          ? _textPrimary
                          : _textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accentGlow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    color: _accent,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTTOM SHEET — SUGGESTED RIDES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBottomSheet() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Container(
            decoration: const BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x60000000),
                  blurRadius: 24,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 16),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Suggested Rides',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _accentGlow,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'View All',
                          style: TextStyle(
                            color: _accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Ride cards — horizontal scroll
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _suggestedRides.length,
                    itemBuilder: (context, index) {
                      return _buildRideCard(_suggestedRides[index], index);
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride, int index) {
    final color = ride['color'] as Color;

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x20000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row — icon + rating
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(ride['icon'] as IconData, color: color, size: 22),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFD700),
                    size: 16,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${ride['rating']}',
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),

          // Name
          Text(
            ride['name'] as String,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            ride['type'] as String,
            style: const TextStyle(color: _textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 10),

          // Bottom row — price + ETA
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ride['price'] as String,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: _textSecondary,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      ride['eta'] as String,
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
              _buildNavItem(Icons.map_rounded, 'Explore', 0),
              _buildNavItem(Icons.receipt_long_rounded, 'Activity', 1),
              _buildNavItem(Icons.account_balance_wallet_rounded, 'Wallet', 2),
              _buildNavItem(Icons.person_rounded, 'Account', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isSelected = _currentNavIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentNavIndex = index),
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
