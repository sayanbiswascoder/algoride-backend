import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/trip_service.dart';

class AddTripScreen extends StatefulWidget {
  const AddTripScreen({super.key});

  @override
  State<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends State<AddTripScreen>
    with SingleTickerProviderStateMixin {
  // ── Colour Palette (matching home_screen.dart) ──────────────────────────
  static const _bg = Color(0xFF0A0E1A);
  static const _surface = Color(0xFF121826);
  static const _card = Color(0xFF1A2235);
  static const _accent = Color(0xFF6C63FF);
  static const _accentGlow = Color(0x446C63FF);
  static const _border = Color(0xFF2A3550);
  static const _textPrimary = Color(0xFFE8EDF5);
  static const _textSecondary = Color(0xFF8A96B0);
  static const _success = Color(0xFF00E5A0);
  static const _error = Color(0xFFFF5C7A);

  // ── Controllers ─────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  int _seats = 1;
  DateTime? _departureTime;
  bool _isLoading = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _originCtrl.dispose();
    _destCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  // ── Date / Time picker ──────────────────────────────────────────────────
  Future<void> _pickDepartureTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _accent,
            surface: _card,
            onSurface: _textPrimary,
          ),
          dialogBackgroundColor: _surface,
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _accent,
            surface: _card,
            onSurface: _textPrimary,
          ),
          dialogBackgroundColor: _surface,
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    setState(() {
      _departureTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  // ── Submit ──────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_departureTime == null) {
      _showSnackBar('Please select a departure time', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await TripService.instance.createTrip(
        origin: _originCtrl.text.trim(),
        destination: _destCtrl.text.trim(),
        departureTime: _departureTime!,
        seatsAvailable: _seats,
        price: double.parse(_priceCtrl.text.trim()),
      );

      if (!mounted) return;
      _showSnackBar('Trip created successfully! 🚗', isError: false);
      Navigator.pop(context, true); // true = trip was created
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _error : _success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header illustration ─────────────────────────────────
                  _buildHeader(),
                  const SizedBox(height: 28),

                  // ── Origin ──────────────────────────────────────────────
                  _buildSectionLabel('Pickup Location'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _originCtrl,
                    hint: 'e.g. Main Campus Gate',
                    icon: Icons.trip_origin_rounded,
                    iconColor: _success,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),

                  // ── Destination ─────────────────────────────────────────
                  _buildSectionLabel('Drop-off Location'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _destCtrl,
                    hint: 'e.g. Downtown Station',
                    icon: Icons.location_on_rounded,
                    iconColor: _error,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),

                  // ── Departure Time ─────────────────────────────────────
                  _buildSectionLabel('Departure Time'),
                  const SizedBox(height: 8),
                  _buildTimePicker(),
                  const SizedBox(height: 20),

                  // ── Seats & Price row ───────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionLabel('Seats Available'),
                            const SizedBox(height: 8),
                            _buildSeatStepper(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionLabel('Price (ALGO)'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _priceCtrl,
                              hint: '0.00',
                              icon: Icons.attach_money_rounded,
                              iconColor: _success,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}'),
                                ),
                              ],
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Required';
                                }
                                final n = double.tryParse(v.trim());
                                if (n == null || n <= 0) return 'Invalid';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),

                  // ── Submit button ───────────────────────────────────────
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _textPrimary,
            size: 16,
          ),
        ),
      ),
      title: const Text(
        'Create Trip',
        style: TextStyle(
          color: _textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1440), Color(0xFF121826)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _accentGlow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.add_road_rounded, color: _accent, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offer a Ride',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Share your trip and split costs with fellow riders',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(color: _textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textSecondary, fontSize: 14),
        prefixIcon: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        filled: true,
        fillColor: _card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _error, width: 1.5),
        ),
        errorStyle: const TextStyle(color: _error, fontSize: 12),
      ),
    );
  }

  Widget _buildTimePicker() {
    final hasTime = _departureTime != null;
    String label;
    if (hasTime) {
      final d = _departureTime!;
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
      final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
      final amPm = d.hour >= 12 ? 'PM' : 'AM';
      final minute = d.minute.toString().padLeft(2, '0');
      label = '${months[d.month]} ${d.day}, ${d.year}  ·  $hour:$minute $amPm';
    } else {
      label = 'Select date & time';
    }

    return GestureDetector(
      onTap: _pickDepartureTime,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hasTime ? _accent : _border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _accent.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.schedule_rounded,
                color: _accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: hasTime ? _textPrimary : _textSecondary,
                  fontSize: 14,
                  fontWeight: hasTime ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: hasTime ? _accent : _textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stepperButton(Icons.remove_rounded, () {
            if (_seats > 1) setState(() => _seats--);
          }),
          Column(
            children: [
              Text(
                '$_seats',
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'seats',
                style: TextStyle(color: _textSecondary, fontSize: 11),
              ),
            ],
          ),
          _stepperButton(Icons.add_rounded, () {
            if (_seats < 8) setState(() => _seats++);
          }),
        ],
      ),
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Icon(icon, color: _accent, size: 20),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isLoading
                  ? [_card, _card]
                  : [_accent, const Color(0xFF8B7BFF)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isLoading
                ? []
                : [
                    BoxShadow(
                      color: _accent.withAlpha(80),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Container(
            alignment: Alignment.center,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _textSecondary,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.rocket_launch_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Create Trip',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
