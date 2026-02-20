import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service for booking rides and confirming ALGO payments.
class BookingService {
  BookingService._();
  static final BookingService instance = BookingService._();

  String get _baseUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:5000/api';

  Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');
    final token = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Creates a booking on a trip. Returns the booking data with status 'pending'.
  Future<Map<String, dynamic>> createBooking({
    required String tripId,
    required int seatsBooked,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final headers = await _authHeaders();
    final body = jsonEncode({
      'tripId': tripId,
      'riderId': user.uid,
      'seatsBooked': seatsBooked,
    });

    final response = await http.post(
      Uri.parse('$_baseUrl/bookings'),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to create booking');
    }
  }

  /// Confirms a booking by submitting the on-chain tx ID for verification.
  /// The backend verifies the tx receiver, amount, and type on the Algorand Indexer.
  Future<Map<String, dynamic>> confirmPayment({
    required String bookingId,
    required String txId,
  }) async {
    final headers = await _authHeaders();
    final body = jsonEncode({'txId': txId});

    final response = await http.post(
      Uri.parse('$_baseUrl/bookings/$bookingId/confirm-payment'),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to confirm payment');
    }
  }

  /// Fetches all bookings for the current user.
  Future<List<Map<String, dynamic>>> getBookings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/bookings/${user.uid}'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to fetch bookings');
    }
  }
}
