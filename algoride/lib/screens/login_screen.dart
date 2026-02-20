import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'signup_screen.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _walletAddress;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // Colour palette matching Stitch reference
  static const _bg = Color(0xFF0A0E1A);
  static const _surface = Color(0xFF121826);
  static const _card = Color(0xFF1A2235);
  static const _accent = Color(0xFF6C63FF);
  static const _accentGlow = Color(0x446C63FF);
  static const _border = Color(0xFF2A3550);
  static const _textPrimary = Color(0xFFE8EDF5);
  static const _textSecondary = Color(0xFF8A96B0);
  static const _error = Color(0xFFFF5C7A);
  static const _success = Color(0xFF00E5A0);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    if (v == null || v.isEmpty) return 'Email is required';
    final emailReg = RegExp(r'^[\w\.\-]+@[\w\-]+\.\w+$');
    if (!emailReg.hasMatch(v)) return 'Enter a valid email address';
    if (v.toLowerCase().endsWith('.edu')) {
      return '.edu emails are not supported — use a personal email';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  void _connectWallet() {
    // Simulate wallet connection dialog
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => _WalletConnectDialog(
        onConnect: (address) {
          setState(() => _walletAddress = address);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _disconnectWallet() {
    setState(() => _walletAddress = null);
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await AuthService.instance.signInWithEmail(
        _emailCtrl.text,
        _passwordCtrl.text,
      );
      // StreamBuilder in main.dart handles navigation automatically
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            content: Text(
              e
                  .toString()
                  .replaceAll('Exception: ', '')
                  .replaceAll(RegExp(r'\[.*?\]'), '')
                  .trim(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await AuthService.instance.signInWithGoogle();
      // StreamBuilder in main.dart handles navigation automatically
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            content: Text(
              e
                  .toString()
                  .replaceAll('Exception: ', '')
                  .replaceAll(RegExp(r'\[.*?\]'), '')
                  .trim(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──────────────────────────────────────────────
                _buildHeader(),
                const SizedBox(height: 36),

                // ── Form Card ────────────────────────────────────────────
                _buildFormCard(),
                const SizedBox(height: 20),

                // ── Divider ──────────────────────────────────────────────
                _buildDivider(),
                const SizedBox(height: 20),

                // ── Google Login ─────────────────────────────────────────
                _buildGoogleButton(),
                const SizedBox(height: 28),

                // ── Wallet (Optional) ────────────────────────────────────
                _buildWalletSection(),
                const SizedBox(height: 32),

                // ── Footer ───────────────────────────────────────────────
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo mark
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF00C6FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: _accentGlow,
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.directions_car_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Welcome Back',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sign in to continue your AlgoRide experience',
          style: TextStyle(color: _textSecondary, fontSize: 14, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x20000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Email
            _buildInputLabel('Email Address'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: _textPrimary, fontSize: 15),
              validator: _validateEmail,
              decoration: _inputDecoration(
                hint: 'you@example.com',
                icon: Icons.mail_outline_rounded,
              ),
            ),
            const SizedBox(height: 18),

            // Password
            _buildInputLabel('Password'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              style: const TextStyle(color: _textPrimary, fontSize: 15),
              validator: _validatePassword,
              decoration: _inputDecoration(
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: _textSecondary,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Forgot password
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {},
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: _accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit
            _buildPrimaryButton(
              label: 'Sign In',
              onTap: _handleLogin,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: const [
        Expanded(child: Divider(color: _border)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or',
            style: TextStyle(color: _textSecondary, fontSize: 13),
          ),
        ),
        Expanded(child: Divider(color: _border)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return OutlinedButton.icon(
      onPressed: _handleGoogleSignIn,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: _border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: _surface,
      ),
      icon: _GoogleIcon(),
      label: const Text(
        'Continue with Google',
        style: TextStyle(
          color: _textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildWalletSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _walletAddress != null ? _success.withAlpha(100) : _border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accentGlow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: _accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connect Wallet',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Optional — for on-chain payments',
                    style: TextStyle(color: _textSecondary, fontSize: 11),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _accentGlow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Optional',
                  style: TextStyle(
                    color: _accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (_walletAddress != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5A010),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _success.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: _success,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _walletAddress!,
                      style: const TextStyle(
                        color: _success,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: _disconnectWallet,
                    child: const Icon(
                      Icons.close,
                      color: _textSecondary,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: _connectWallet,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: _accent, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_link_rounded, color: _accent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Link Wallet',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'We support Algorand, Ethereum and Solana networks.',
            style: TextStyle(color: _textSecondary, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(color: _textSecondary, fontSize: 14),
            children: [
              const TextSpan(text: "Don't have an account? "),
              TextSpan(
                text: 'Sign Up',
                style: const TextStyle(
                  color: _accent,
                  fontWeight: FontWeight.w600,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    );
                  },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 11,
              height: 1.6,
            ),
            children: [
              const TextSpan(text: 'By continuing, you agree to our '),
              TextSpan(
                text: 'Terms of Service',
                style: const TextStyle(color: _accent),
                recognizer: TapGestureRecognizer()..onTap = () {},
              ),
              const TextSpan(text: ' and '),
              TextSpan(
                text: 'Privacy Policy',
                style: const TextStyle(color: _accent),
                recognizer: TapGestureRecognizer()..onTap = () {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textSecondary, fontSize: 14),
      prefixIcon: Icon(icon, color: _textSecondary, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _error, width: 1.5),
      ),
      errorStyle: const TextStyle(color: _error, fontSize: 12),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: _textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _accent.withAlpha(150),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ).copyWith(overlayColor: WidgetStateProperty.all(Colors.white12)),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wallet connect dialog
// ─────────────────────────────────────────────────────────────────────────────

class _WalletConnectDialog extends StatefulWidget {
  final void Function(String address) onConnect;
  const _WalletConnectDialog({required this.onConnect});

  @override
  State<_WalletConnectDialog> createState() => _WalletConnectDialogState();
}

class _WalletConnectDialogState extends State<_WalletConnectDialog> {
  final _ctrl = TextEditingController();
  String? _err;

  static const _bg = Color(0xFF1A2235);
  static const _border = Color(0xFF2A3550);
  static const _accent = Color(0xFF6C63FF);
  static const _textPrimary = Color(0xFFE8EDF5);
  static const _textSecondary = Color(0xFF8A96B0);
  static const _surface = Color(0xFF121826);

  static const _providers = [
    {'name': 'Pera Wallet', 'icon': Icons.account_balance_wallet_rounded},
    {'name': 'MyAlgo Wallet', 'icon': Icons.wallet_rounded},
    {'name': 'MetaMask', 'icon': Icons.currency_exchange_rounded},
    {'name': 'Phantom', 'icon': Icons.blur_circular_rounded},
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final addr = _ctrl.text.trim();
    if (addr.isEmpty) {
      setState(() => _err = 'Please enter a wallet address');
      return;
    }
    widget.onConnect(
      '${addr.substring(0, 6.clamp(0, addr.length))}...${addr.substring((addr.length - 4).clamp(0, addr.length))}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Connect Wallet',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose a provider or enter your address manually',
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),
            // Provider chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _providers.map((p) {
                return InkWell(
                  onTap: () => setState(
                    () => _ctrl.text =
                        '0xDemo${p['name'].toString().hashCode.abs()}',
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(p['icon'] as IconData, color: _accent, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          p['name'] as String,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            const Divider(color: _border),
            const SizedBox(height: 14),
            const Text(
              'Or enter address manually',
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrl,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                hintText: 'e.g. 0x... or ALGO...',
                hintStyle: const TextStyle(color: _textSecondary, fontSize: 13),
                filled: true,
                fillColor: _surface,
                errorText: _err,
                errorStyle: const TextStyle(
                  color: Color(0xFFFF5C7A),
                  fontSize: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _accent, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: _textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Connect',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Google SVG Icon placeholder
// ─────────────────────────────────────────────────────────────────────────────
class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: const Text(
        'G',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w700,
          fontSize: 16,
          height: 1.2,
        ),
      ),
    );
  }
}
