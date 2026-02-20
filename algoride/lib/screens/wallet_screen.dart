import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/algorand_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  bool _balanceVisible = true;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // Wallet state
  String? _connectedAddress;
  AlgoAccountInfo? _accountInfo;
  List<AlgoTransaction> _transactions = [];
  double _algoPriceUsd = 0.0;
  bool _isLoading = false;
  bool _isConnecting = false;
  String? _error;

  final _addressCtrl = TextEditingController();
  final _algo = AlgorandService.instance;

  // Colour palette — matching the existing design system
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

  // Pera Wallet accent
  static const _peraYellow = Color(0xFFFFEE55);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _loadSavedWallet();
  }

  /// Load any previously saved wallet address from Firestore.
  Future<void> _loadSavedWallet() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final savedAddress = await _algo.getWalletAddress(user.uid);
      if (savedAddress != null && savedAddress.isNotEmpty && mounted) {
        await _connectWallet(savedAddress);
      }
    } catch (_) {
      // Silently ignore — user can still connect manually
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WALLET CONNECT / DATA FETCH
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _connectWallet(String address) async {
    final trimmed = address.trim();
    if (!_algo.isValidAddress(trimmed)) {
      setState(() => _error = 'Invalid Algorand address (must be 58 chars)');
      return;
    }

    setState(() {
      _isConnecting = true;
      _error = null;
    });

    try {
      final info = await _algo.fetchAccountInfo(trimmed);
      final txs = await _algo.fetchTransactions(trimmed);
      final price = await _algo.fetchAlgoPrice();

      // Save to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _algo.saveWalletAddress(user.uid, trimmed);
      }

      if (mounted) {
        setState(() {
          _connectedAddress = trimmed;
          _accountInfo = info;
          _transactions = txs;
          _algoPriceUsd = price;
          _isConnecting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('AlgorandException: ', '');
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    if (_connectedAddress == null) return;

    setState(() => _isLoading = true);
    try {
      final info = await _algo.fetchAccountInfo(_connectedAddress!);
      final txs = await _algo.fetchTransactions(_connectedAddress!);
      final price = await _algo.fetchAlgoPrice();

      if (mounted) {
        setState(() {
          _accountInfo = info;
          _transactions = txs;
          _algoPriceUsd = price;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('AlgorandException: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _disconnect() async {
    // Remove from Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _algo.removeWalletAddress(user.uid);
      } catch (_) {}
    }

    setState(() {
      _connectedAddress = null;
      _accountInfo = null;
      _transactions = [];
      _algoPriceUsd = 0.0;
      _error = null;
      _addressCtrl.clear();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: _connectedAddress == null
              ? _buildConnectView()
              : _buildWalletView(),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONNECT WALLET VIEW
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildConnectView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Pera wallet icon
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _peraYellow.withAlpha(20),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _peraYellow.withAlpha(15),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _peraYellow.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: _peraYellow,
                  size: 40,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Title
          const Center(
            child: Text(
              'Connect Pera Wallet',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Enter your Algorand wallet address\nto view your balance and transactions',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 36),

          // Address input
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wallet Address',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _addressCtrl,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g. ALGO7X2...',
                    hintStyle: const TextStyle(
                      color: _textSecondary,
                      fontSize: 13,
                    ),
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
                        size: 18,
                      ),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) {
                          _addressCtrl.text = data!.text!;
                        }
                      },
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(color: _error_, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 18),

                // Connect button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isConnecting
                        ? null
                        : () => _connectWallet(_addressCtrl.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _peraYellow,
                      foregroundColor: Colors.black87,
                      disabledBackgroundColor: _peraYellow.withAlpha(100),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isConnecting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black54,
                            ),
                          )
                        : const Text(
                            'Connect Wallet',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Network info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _accent.withAlpha(15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accent.withAlpha(40)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: _accent, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Connected to Algorand TestNet. Your address data is read-only and never stored.',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 11,
                      height: 1.4,
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

  // ═══════════════════════════════════════════════════════════════════════════
  // CONNECTED WALLET VIEW
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildWalletView() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: _accent,
      backgroundColor: _card,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildBalanceCard(),
            const SizedBox(height: 24),
            _buildQuickActions(),
            const SizedBox(height: 28),
            _buildTransactionList(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Wallet',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Pera Wallet · Algorand',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        // Connection status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _success.withAlpha(25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _success.withAlpha(60)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: _success.withAlpha(120), blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Connected',
                style: TextStyle(
                  color: _success,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Visibility toggle
        GestureDetector(
          onTap: () => setState(() => _balanceVisible = !_balanceVisible),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Icon(
              _balanceVisible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: _textSecondary,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BALANCE CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBalanceCard() {
    final balanceAlgo = _accountInfo?.balanceAlgo ?? 0.0;
    final balanceUsd = balanceAlgo * _algoPriceUsd;
    final shortAddr = _accountInfo?.shortAddress ?? '...';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1F3D), Color(0xFF0F1328)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _accent.withAlpha(30),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pera logo row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _peraYellow.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: _peraYellow,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Pera Wallet',
                style: TextStyle(
                  color: _peraYellow,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              // Disconnect
              GestureDetector(
                onTap: _disconnect,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _error_.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _error_.withAlpha(50)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link_off_rounded, color: _error_, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Disconnect',
                        style: TextStyle(
                          color: _error_,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Balance
          const Text(
            'Total Balance',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),

          // ALGO amount (primary)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              _balanceVisible
                  ? '${balanceAlgo.toStringAsFixed(6)} ALGO'
                  : '•••••• ALGO',
              key: ValueKey('algo_$_balanceVisible'),
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // USD equivalent
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              _balanceVisible
                  ? _algoPriceUsd > 0
                        ? '≈ \$${balanceUsd.toStringAsFixed(2)} USD'
                        : '≈ price unavailable'
                  : '≈ \$•••• USD',
              key: ValueKey('usd_$_balanceVisible'),
              style: TextStyle(
                color: _textSecondary.withAlpha(200),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          if (_algoPriceUsd > 0) ...[
            const SizedBox(height: 4),
            Text(
              '1 ALGO = \$${_algoPriceUsd.toStringAsFixed(4)}',
              style: TextStyle(
                color: _textSecondary.withAlpha(120),
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Wallet address
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _bg.withAlpha(150),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border.withAlpha(80)),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, color: _textSecondary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shortAddr,
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (_connectedAddress != null) {
                      Clipboard.setData(
                        ClipboardData(text: _connectedAddress!),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: _success,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          content: const Text(
                            'Address copied!',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _accentGlow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.copy_rounded,
                      color: _accent,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Network badge
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _accent.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Algorand TestNet',
                  style: TextStyle(
                    color: _accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (_isLoading) ...[
                const SizedBox(width: 10),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: _accent,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // QUICK ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildQuickActions() {
    return Row(
      children: [
        _buildActionButton(
          icon: Icons.arrow_upward_rounded,
          label: 'Send',
          color: _accent,
        ),
        const SizedBox(width: 12),
        _buildActionButton(
          icon: Icons.arrow_downward_rounded,
          label: 'Receive',
          color: _success,
        ),
        const SizedBox(width: 12),
        _buildActionButton(
          icon: Icons.refresh_rounded,
          label: 'Refresh',
          color: const Color(0xFF00C6FF),
          onTap: _refreshData,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TRANSACTION LIST
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTransactionList() {
    return Column(
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'On-Chain Transactions (${_transactions.length})',
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            if (_isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: _accent,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        if (_error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _error_.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _error_.withAlpha(40)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: _error_,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: _error_, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        if (_transactions.isEmpty && !_isLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  color: _textSecondary.withAlpha(80),
                  size: 48,
                ),
                const SizedBox(height: 12),
                const Text(
                  'No transactions yet',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fund your TestNet wallet to see activity',
                  style: TextStyle(
                    color: _textSecondary.withAlpha(150),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _transactions.length,
              separatorBuilder: (_, __) =>
                  Divider(color: _border.withAlpha(80), height: 1, indent: 66),
              itemBuilder: (context, index) {
                return _buildTransactionTile(_transactions[index]);
              },
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTransactionTile(AlgoTransaction tx) {
    final isCredit = tx.isIncoming;

    // Pick icon and color based on transaction type
    IconData icon;
    Color color;
    switch (tx.type) {
      case 'pay':
        icon = isCredit
            ? Icons.arrow_downward_rounded
            : Icons.arrow_upward_rounded;
        color = isCredit ? _success : _accent;
        break;
      case 'axfer':
        icon = Icons.token_rounded;
        color = const Color(0xFF00C6FF);
        break;
      case 'appl':
        icon = Icons.code_rounded;
        color = _peraYellow;
        break;
      default:
        icon = Icons.swap_horiz_rounded;
        color = _textSecondary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),

          // Title + time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.typeLabel,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tx.formattedTime,
                  style: const TextStyle(color: _textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),

          // Amount + TX ID
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (tx.amountAlgo > 0)
                Text(
                  '${isCredit ? '+' : '-'} ${tx.amountAlgo.toStringAsFixed(4)} ALGO',
                  style: TextStyle(
                    color: isCredit ? _success : _error_,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                Text(
                  tx.typeLabel,
                  style: TextStyle(
                    color: _textSecondary.withAlpha(150),
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                tx.shortId,
                style: TextStyle(
                  color: _textSecondary.withAlpha(100),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
