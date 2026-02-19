import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Data model returned when the user selects a place.
class SelectedPlace {
  final String name;
  final LatLng latLng;
  const SelectedPlace({required this.name, required this.latLng});
}

/// Full-screen location search using the Google Geocoding REST API.
/// Returns a [SelectedPlace] via Navigator.pop when the user picks a result.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  List<_GeoResult> _results = [];
  bool _loading = false;
  String? _error;

  // Design system colours — same as HomeScreen
  static const _bg = Color(0xFF0A0E1A);
  static const _surface = Color(0xFF121826);
  static const _card = Color(0xFF1A2235);
  static const _accent = Color(0xFF6C63FF);
  static const _accentGlow = Color(0x446C63FF);
  static const _border = Color(0xFF2A3550);
  static const _textPrimary = Color(0xFFE8EDF5);
  static const _textSecondary = Color(0xFF8A96B0);
  static const _success = Color(0xFF00E5A0);

  String get _apiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Geocode via REST ──────────────────────────────────────────────────────
  Future<void> _search(String query) async {
    if (query.trim().length < 3) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'address': query,
        'key': _apiKey,
      });

      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final status = data['status'] as String;
      print(status);

      if (status == 'OK') {
        final rawResults = data['results'] as List;
        setState(() {
          _results = rawResults.take(6).map((r) {
            final loc = r['geometry']['location'];
            return _GeoResult(
              name: r['formatted_address'] as String,
              latLng: LatLng(
                (loc['lat'] as num).toDouble(),
                (loc['lng'] as num).toDouble(),
              ),
            );
          }).toList();
        });
      } else if (status == 'ZERO_RESULTS') {
        setState(() => _results = []);
      } else {
        setState(() => _error = 'Geocoding error: $status');
      }
    } catch (e) {
      setState(() => _error = 'Search failed. Check your connection.');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _search(value);
    });
  }

  void _selectPlace(_GeoResult result) {
    Navigator.of(
      context,
    ).pop(SelectedPlace(name: result.name, latLng: result.latLng));
  }

  // ── Quick-access suggestions (static) ─────────────────────────────────────
  static const _quickPlaces = [
    {'icon': Icons.school_rounded, 'label': 'Campus'},
    {'icon': Icons.train_rounded, 'label': 'Station'},
    {'icon': Icons.local_airport_rounded, 'label': 'Airport'},
    {'icon': Icons.local_hospital_rounded, 'label': 'Hospital'},
  ];

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_error != null) _buildError(),
            Expanded(
              child: _results.isEmpty && !_loading
                  ? _buildQuickAccess()
                  : _buildResultsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back + title row
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: _textPrimary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Where to?',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search input
          Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
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
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _onQueryChanged,
                    style: const TextStyle(color: _textPrimary, fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'Search address or place…',
                      hintStyle: TextStyle(color: _textSecondary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _accent,
                      ),
                    ),
                  )
                else if (_controller.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _controller.clear();
                      setState(() {
                        _results = [];
                        _error = null;
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.close_rounded,
                        color: _textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x20FF5252),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x40FF5252)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFFF5252),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccess() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Search',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _quickPlaces.map((p) {
              return GestureDetector(
                onTap: () {
                  final label = p['label'] as String;
                  _controller.text = label;
                  _onQueryChanged(label);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(p['icon'] as IconData, color: _accent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        p['label'] as String,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 30),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.search_rounded,
                  color: _textSecondary.withAlpha(80),
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'Search for a destination',
                  style: TextStyle(
                    color: _textSecondary.withAlpha(120),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (_loading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (_, __) =>
          const Divider(color: _border, height: 1, indent: 56),
      itemBuilder: (context, index) {
        final r = _results[index];
        return ListTile(
          onTap: () => _selectPlace(r),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _accentGlow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: _accent,
              size: 20,
            ),
          ),
          title: Text(
            r.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            '${r.latLng.latitude.toStringAsFixed(4)}, ${r.latLng.longitude.toStringAsFixed(4)}',
            style: const TextStyle(color: _textSecondary, fontSize: 11),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios_rounded,
            color: _textSecondary,
            size: 14,
          ),
        );
      },
    );
  }
}

// Internal model for geocoding results
class _GeoResult {
  final String name;
  final LatLng latLng;
  const _GeoResult({required this.name, required this.latLng});
}
