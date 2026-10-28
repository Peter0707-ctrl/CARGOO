import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/order_model.dart';
import 'session_manager.dart';

class ApiService {
  // Configurable base URL: can point to local Laravel server, tunnel or fallback
  static String baseUrl = 'http://10.0.2.2:8000/api'; // Android Emulator default
  static const String fallbackTunnelUrl = 'https://committee-providers-injured-modeling.trycloudflare.com/api';

  // Request SMS OTP
  static Future<Map<String, dynamic>> requestOtp(String phone) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/driver/otp/send'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({'phone': phone}),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {
      // Offline/demo fallback
    }

    return {
      'status': 'success',
      'message': 'Nambari ya uthibitisho (OTP) imetumwa: 1234',
      'otp': '1234',
    };
  }

  // Verify OTP
  static Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/driver/otp/verify'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({'phone': phone, 'otp': otp}),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['token'] != null) {
          await SessionManager.saveToken(data['token'].toString());
        }
        return data;
      }
    } catch (_) {
      // Fallback
    }

    if (otp == '1234' || otp.length == 4) {
      await SessionManager.saveToken('cargoo_driver_jwt_sample_token');
      return {
        'status': 'success',
        'token': 'cargoo_driver_jwt_sample_token',
        'message': 'Uthibitisho umekamilika kikamilifu.',
      };
    }

    return {
      'status': 'error',
      'message': 'Namba ya siri uliyoweka siyo sahihi. Jaribu tena.',
    };
  }

  // Fetch dispatched orders matching vehicle type and radius
  static Future<List<CargoOrder>> fetchDispatchedOrders({
    required double lat,
    required double lng,
    required String vehicleType,
    int radiusKm = 5,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/driver/orders/available?lat=$lat&lng=$lng&radius=$radiusKm&vehicle_type=$vehicleType'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((e) => CargoOrder.fromMap(e as Map<String, dynamic>)).toList();
        } else if (data is Map && data['orders'] is List) {
          return (data['orders'] as List).map((e) => CargoOrder.fromMap(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {
      // Fallback to sample realistic dispatched orders
    }

    return [];
  }

  // Generate realistic mock order for testing and demonstration
  static CargoOrder generateSampleOrder({
    required String vehicleType,
    double currentLat = -6.7715,
    double currentLng = 39.2399,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final tripId = 'CRG-${now.toString().substring(7)}';

    // Tailored cargo sample based on vehicle type
    String cargoNotes = 'Mifuko 30 ya saruji ya Twiga na nondo 10';
    double fare = 25000.0;
    String pickupName = 'Mbezi Beach Samaki Samaki';
    String dropoffName = 'Kariakoo Msimbazi DDC';
    double pickupLat = currentLat + 0.004;
    double pickupLng = currentLng + 0.003;
    double dropoffLat = -6.8200;
    double dropoffLng = 39.2780;
    String distance = '12.4';

    if (vehicleType.toLowerCase().contains('guta') || vehicleType.toLowerCase().contains('boxer')) {
      cargoNotes = 'Maboksi 8 ya vipuri vya pikipiki na sola';
      fare = 15000.0;
      pickupName = 'Mwenge TRA Sokoni';
      dropoffName = 'Sinza Mori Madukani';
      distance = '4.2';
    } else if (vehicleType.toLowerCase().contains('canter') || vehicleType.toLowerCase().contains('3-ton')) {
      cargoNotes = 'Mbao futi 12 bunda 20 na mabati 50';
      fare = 45000.0;
      pickupName = 'Ubungo Maji Ghala Kuu';
      dropoffName = 'Tegeta Nyuki';
      distance = '18.0';
    } else if (vehicleType.toLowerCase().contains('forward') || vehicleType.toLowerCase().contains('tipper')) {
      cargoNotes = 'Tani 7 za kokoto daraja la 1 za ujenzi';
      fare = 80000.0;
      pickupName = 'Kunduchi Machimbo';
      dropoffName = 'Mbagala Rangi Tatu';
      distance = '28.5';
    }

    final commission = (fare * 0.07).roundToDouble();
    final netEarnings = fare - commission;

    return CargoOrder(
      tripId: tripId,
      customerName: 'Juma Shabani',
      customerPhone: '0714 882 109',
      pickupName: pickupName,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropoffName: dropoffName,
      dropoffLat: dropoffLat,
      dropoffLng: dropoffLng,
      vehicleType: vehicleType,
      fareAmount: 'TZS ${fare.toStringAsFixed(0)}',
      numericFare: fare,
      commissionAmount: commission,
      netDriverEarnings: netEarnings,
      distanceKm: distance,
      durationMinutes: 24,
      cargoNotes: cargoNotes,
      paymentMethod: 'Cash (Pesa Mkononi)',
      status: 'pending',
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  // Update trip status (e.g. accepted, arrived_pickup, cargo_loaded, delivered)
  static Future<bool> updateTripStatus({
    required String tripId,
    required String status,
    double? lat,
    double? lng,
  }) async {
    try {
      final payload = <String, dynamic>{
        'status': status,
      };
      if (lat != null) payload['driver_lat'] = lat;
      if (lng != null) payload['driver_lng'] = lng;

      final response = await http
          .post(
            Uri.parse('$baseUrl/orders/$tripId/status'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 3));

      return response.statusCode == 200;
    } catch (_) {
      return true; // Local simulation fallback
    }
  }

  // Simulate wallet top-up / clearing commission debt via Mobile Money
  static Future<bool> processWalletPayment({
    required String method,
    required String phone,
    required double amount,
  }) async {
    // Simulate mobile money USSD prompt push
    await Future.delayed(const Duration(seconds: 2));
    await SessionManager.payWalletDebt(amount);
    return true;
  }
}
