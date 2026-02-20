import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for querying the Algorand blockchain via public REST APIs.
/// Uses TestNet by default — switch URLs for MainNet.
class AlgorandService {
  // Singleton
  AlgorandService._();
  static final AlgorandService instance = AlgorandService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Algorand TestNet public nodes
  static const String _algodBaseUrl = 'https://testnet-api.algonode.cloud';
  static const String _indexerBaseUrl = 'https://testnet-idx.algonode.cloud';

  // ─────────────────────────────────────────────────────────────────────────
  // WALLET / FIRESTORE PERSISTENCE
  // ─────────────────────────────────────────────────────────────────────────

  /// Save a wallet address to the user's Firestore document.
  Future<void> saveWalletAddress(String uid, String address) async {
    await _db.collection('users').doc(uid).set({
      'walletAddress': address,
    }, SetOptions(merge: true));
  }

  /// Get the saved wallet address from Firestore (null if none).
  Future<String?> getWalletAddress(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return doc.data()?['walletAddress'] as String?;
    }
    return null;
  }

  /// Remove the wallet address from Firestore.
  Future<void> removeWalletAddress(String uid) async {
    await _db.collection('users').doc(uid).update({
      'walletAddress': FieldValue.delete(),
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACCOUNT INFO (balance)
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetches account info from algod. Returns balance in microAlgos.
  /// Throws on network/API errors.
  Future<AlgoAccountInfo> fetchAccountInfo(String address) async {
    final url = Uri.parse('$_algodBaseUrl/v2/accounts/$address');
    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw AlgorandException(
        'Failed to fetch account info (${response.statusCode})',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final microAlgos = json['amount'] as int? ?? 0;
    final minBalance = json['min-balance'] as int? ?? 0;

    return AlgoAccountInfo(
      address: address,
      balanceMicroAlgos: microAlgos,
      minBalanceMicroAlgos: minBalance,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TRANSACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetches recent transactions for an address from the Indexer API.
  /// Returns the most recent [limit] transactions.
  Future<List<AlgoTransaction>> fetchTransactions(
    String address, {
    int limit = 15,
  }) async {
    final url = Uri.parse(
      '$_indexerBaseUrl/v2/accounts/$address/transactions?limit=$limit',
    );
    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw AlgorandException(
        'Failed to fetch transactions (${response.statusCode})',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final txList = json['transactions'] as List<dynamic>? ?? [];

    return txList.map((tx) {
      final txMap = tx as Map<String, dynamic>;
      final type = txMap['tx-type'] as String? ?? 'unknown';
      final roundTime = txMap['round-time'] as int? ?? 0;
      final confirmedRound = txMap['confirmed-round'] as int? ?? 0;
      final id = txMap['id'] as String? ?? '';

      // Payment transaction details
      int amountMicroAlgos = 0;
      String sender = txMap['sender'] as String? ?? '';
      String receiver = '';

      if (type == 'pay') {
        final payTx =
            txMap['payment-transaction'] as Map<String, dynamic>? ?? {};
        amountMicroAlgos = payTx['amount'] as int? ?? 0;
        receiver = payTx['receiver'] as String? ?? '';
      } else if (type == 'axfer') {
        final axferTx =
            txMap['asset-transfer-transaction'] as Map<String, dynamic>? ?? {};
        amountMicroAlgos = axferTx['amount'] as int? ?? 0;
        receiver = axferTx['receiver'] as String? ?? '';
      }

      // Determine if this is incoming or outgoing relative to the queried address
      final isIncoming = receiver.toLowerCase() == address.toLowerCase();

      return AlgoTransaction(
        id: id,
        type: type,
        sender: sender,
        receiver: receiver,
        amountMicroAlgos: amountMicroAlgos,
        roundTime: roundTime,
        confirmedRound: confirmedRound,
        isIncoming: isIncoming,
      );
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ALGO PRICE
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetches current ALGO/USD price from CoinGecko free API.
  Future<double> fetchAlgoPrice() async {
    try {
      final url = Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price?ids=algorand&vs_currencies=usd',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final algo = json['algorand'] as Map<String, dynamic>?;
        return (algo?['usd'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (_) {
      // Price fetch is non-critical — return 0 on failure
    }
    return 0.0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ADDRESS VALIDATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Basic validation: Algorand addresses are 58 characters (base32).
  bool isValidAddress(String address) {
    if (address.length != 58) return false;
    // Algorand addresses use base32 alphabet
    final base32Regex = RegExp(r'^[A-Z2-7]{58}$');
    return base32Regex.hasMatch(address.toUpperCase());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PERA WALLET PAYMENT HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Constructs a Pera Wallet deep-link URI for a payment.
  /// [receiver] — Algorand address to receive payment
  /// [amountMicroAlgos] — Amount in microAlgos (1 ALGO = 1,000,000)
  /// [note] — Optional note to attach to the transaction
  Uri buildPeraPaymentUri({
    required String receiver,
    required int amountMicroAlgos,
    String? note,
  }) {
    final params = <String, String>{
      'receiver': receiver,
      'amount': amountMicroAlgos.toString(),
    };
    if (note != null && note.isNotEmpty) {
      params['note'] = note;
    }
    return Uri(scheme: 'perawallet', host: 'payment', queryParameters: params);
  }

  /// Verifies a transaction on-chain via the Algorand Indexer.
  /// Returns the transaction data if found, or throws on failure.
  Future<Map<String, dynamic>> verifyTransaction(String txId) async {
    final url = Uri.parse('$_indexerBaseUrl/v2/transactions/$txId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final tx = json['transaction'] as Map<String, dynamic>?;
        if (tx == null) {
          throw const AlgorandException('Transaction data not found');
        }
        return tx;
      } else {
        throw AlgorandException(
          'Transaction not found (status ${response.statusCode})',
        );
      }
    } catch (e) {
      if (e is AlgorandException) rethrow;
      throw AlgorandException('Failed to verify transaction: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════════════════════════

class AlgoAccountInfo {
  final String address;
  final int balanceMicroAlgos;
  final int minBalanceMicroAlgos;

  const AlgoAccountInfo({
    required this.address,
    required this.balanceMicroAlgos,
    required this.minBalanceMicroAlgos,
  });

  /// Balance in ALGO (1 ALGO = 1,000,000 microAlgos)
  double get balanceAlgo => balanceMicroAlgos / 1000000.0;

  /// Available balance (total - minimum)
  double get availableAlgo =>
      (balanceMicroAlgos - minBalanceMicroAlgos) / 1000000.0;

  /// Truncated address for display (first 6 + last 4)
  String get shortAddress {
    if (address.length < 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}

class AlgoTransaction {
  final String id;
  final String type;
  final String sender;
  final String receiver;
  final int amountMicroAlgos;
  final int roundTime;
  final int confirmedRound;
  final bool isIncoming;

  const AlgoTransaction({
    required this.id,
    required this.type,
    required this.sender,
    required this.receiver,
    required this.amountMicroAlgos,
    required this.roundTime,
    required this.confirmedRound,
    required this.isIncoming,
  });

  /// Amount in ALGO
  double get amountAlgo => amountMicroAlgos / 1000000.0;

  /// Human-readable timestamp
  String get formattedTime {
    if (roundTime == 0) return 'Pending';
    final dt = DateTime.fromMillisecondsSinceEpoch(roundTime * 1000);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final months = [
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
    return '${months[dt.month - 1]} ${dt.day}, ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Human-readable type label
  String get typeLabel {
    switch (type) {
      case 'pay':
        return isIncoming ? 'Received' : 'Sent';
      case 'axfer':
        return isIncoming ? 'Asset Received' : 'Asset Sent';
      case 'appl':
        return 'App Call';
      case 'acfg':
        return 'Asset Config';
      case 'afrz':
        return 'Asset Freeze';
      case 'keyreg':
        return 'Key Registration';
      default:
        return type.toUpperCase();
    }
  }

  /// Short transaction ID for display
  String get shortId {
    if (id.length < 12) return id;
    return '${id.substring(0, 8)}...';
  }
}

class AlgorandException implements Exception {
  final String message;
  const AlgorandException(this.message);

  @override
  String toString() => 'AlgorandException: $message';
}
