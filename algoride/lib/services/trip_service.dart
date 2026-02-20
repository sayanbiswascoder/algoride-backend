import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service for interacting with the Trips API.
class TripService {
  TripService._();
  static final TripService instance = TripService._();

  String get _baseUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:5000/api';

  /// Gets an authorization header with the current user's Firebase ID token.
  Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');
    final token = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Creates a new trip via POST /api/trips.
  Future<Map<String, dynamic>> createTrip({
    required String origin,
    required String destination,
    required DateTime departureTime,
    required int seatsAvailable,
    required double price,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final headers = await _authHeaders();

    final body = jsonEncode({
      'driverId': user.uid,
      'origin': origin,
      'destination': destination,
      'departureTime': departureTime.toIso8601String(),
      'seatsAvailable': seatsAvailable,
      'price': price,
    });

    final response = await http.post(
      Uri.parse('$_baseUrl/trips'),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to create trip');
    }
  }

  /// Fetches available trips with optional origin/destination text filter.
  Future<List<Map<String, dynamic>>> getTrips({
    String? origin,
    String? destination,
  }) async {
    final headers = await _authHeaders();

    final queryParams = <String, String>{};
    if (origin != null && origin.trim().isNotEmpty) {
      queryParams['origin'] = origin.trim();
    }
    if (destination != null && destination.trim().isNotEmpty) {
      queryParams['destination'] = destination.trim();
    }

    final uri = Uri.parse(
      '$_baseUrl/trips',
    ).replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to fetch trips');
    }
  }

  /// Fetches the current user's bookings (as rider) via GET /api/bookings/:userId.
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

  /// Fetches the current user's trips (as driver) via GET /api/trips/driver/:driverId.
  Future<List<Map<String, dynamic>>> getMyTrips() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/trips/driver/${user.uid}'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to fetch your trips');
    }
  }

  /// Creates a booking on a trip via POST /api/bookings.
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

  /// Updates a booking's status via PATCH /api/bookings/:id/status.
  Future<Map<String, dynamic>> updateBookingStatus({
    required String bookingId,
    required String status,
    String? paymentTxId,
  }) async {
    final headers = await _authHeaders();
    final bodyMap = <String, dynamic>{'status': status};
    if (paymentTxId != null) bodyMap['paymentTxId'] = paymentTxId;

    final response = await http.patch(
      Uri.parse('$_baseUrl/bookings/$bookingId/status'),
      headers: headers,
      body: jsonEncode(bodyMap),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to update booking');
    }
  }
}
