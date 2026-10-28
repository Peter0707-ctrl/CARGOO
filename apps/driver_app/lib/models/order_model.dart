class CargoOrder {
  final String tripId;
  final String customerName;
  final String customerPhone;
  final String customerAvatar;
  final String pickupName;
  final double pickupLat;
  final double pickupLng;
  final String dropoffName;
  final double dropoffLat;
  final double dropoffLng;
  final List<dynamic> stops;
  final String vehicleType;
  final String fareAmount; // e.g. "TZS 20,000"
  final double numericFare; // e.g. 20000.0
  final double commissionAmount; // 7% e.g. 1400.0
  final double netDriverEarnings; // 93% e.g. 18600.0
  final String distanceKm;
  final int durationMinutes;
  final String cargoNotes;
  final String paymentMethod;
  final String status; // pending, accepted, arrived_pickup, cargo_loaded, en_route, arrived_dropoff, delivered, cancelled
  final String? createdAt;

  CargoOrder({
    required this.tripId,
    required this.customerName,
    required this.customerPhone,
    this.customerAvatar = '',
    required this.pickupName,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffName,
    required this.dropoffLat,
    required this.dropoffLng,
    this.stops = const [],
    required this.vehicleType,
    required this.fareAmount,
    required this.numericFare,
    required this.commissionAmount,
    required this.netDriverEarnings,
    required this.distanceKm,
    this.durationMinutes = 15,
    this.cargoNotes = '',
    this.paymentMethod = 'Cash',
    this.status = 'pending',
    this.createdAt,
  });

  factory CargoOrder.fromMap(Map<String, dynamic> map) {
    final rawFare = map['fare_amount']?.toString() ?? map['fare']?.toString() ?? 'TZS 10,000';
    final cleanedFareStr = rawFare.replaceAll(RegExp(r'[^0-9]'), '');
    final numFare = double.tryParse(cleanedFareStr) ?? 10000.0;
    final commission = (numFare * 0.07).roundToDouble(); // 7% launch commission
    final netEarnings = numFare - commission; // 93% to driver

    return CargoOrder(
      tripId: map['trip_id']?.toString() ?? map['id']?.toString() ?? 'CRG-${DateTime.now().millisecondsSinceEpoch}',
      customerName: map['customer_name']?.toString() ?? map['sender']?.toString() ?? 'Mteja wa CARGOO',
      customerPhone: map['customer_phone']?.toString() ?? map['senderPhone']?.toString() ?? '0714 882 109',
      customerAvatar: map['customer_avatar']?.toString() ?? '',
      pickupName: map['pickup_name']?.toString() ?? map['pickup']?.toString() ?? 'Eneo la Kuchukua Mzigo',
      pickupLat: (map['pickup_lat'] as num?)?.toDouble() ?? (map['pickupLat'] as num?)?.toDouble() ?? -6.7715,
      pickupLng: (map['pickup_lng'] as num?)?.toDouble() ?? (map['pickupLng'] as num?)?.toDouble() ?? 39.2399,
      dropoffName: map['dropoff_name']?.toString() ?? map['dropoff']?.toString() ?? 'Eneo la Kushusha',
      dropoffLat: (map['dropoff_lat'] as num?)?.toDouble() ?? (map['dropoffLat'] as num?)?.toDouble() ?? -6.8200,
      dropoffLng: (map['dropoff_lng'] as num?)?.toDouble() ?? (map['dropoffLng'] as num?)?.toDouble() ?? 39.2780,
      stops: map['stops'] is List ? map['stops'] as List : [],
      vehicleType: map['vehicle_type']?.toString() ?? map['vehicle']?.toString() ?? 'Kirikuu Pick-up',
      fareAmount: rawFare.startsWith('TZS') ? rawFare : 'TZS $rawFare',
      numericFare: numFare,
      commissionAmount: commission,
      netDriverEarnings: netEarnings,
      distanceKm: map['distance_km']?.toString() ?? map['distanceKm']?.toString() ?? '8.5',
      durationMinutes: (map['duration_minutes'] as num?)?.toInt() ?? 15,
      cargoNotes: map['cargo_notes']?.toString() ?? map['notes']?.toString() ?? '',
      paymentMethod: map['payment_method']?.toString() ?? map['paymentMethod']?.toString() ?? 'Cash',
      status: map['status']?.toString() ?? 'pending',
      createdAt: map['created_at']?.toString() ?? map['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trip_id': tripId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_avatar': customerAvatar,
      'pickup_name': pickupName,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'dropoff_name': dropoffName,
      'dropoff_lat': dropoffLat,
      'dropoff_lng': dropoffLng,
      'stops': stops,
      'vehicle_type': vehicleType,
      'fare_amount': fareAmount,
      'numeric_fare': numericFare,
      'commission_amount': commissionAmount,
      'net_driver_earnings': netDriverEarnings,
      'distance_km': distanceKm,
      'duration_minutes': durationMinutes,
      'cargo_notes': cargoNotes,
      'payment_method': paymentMethod,
      'status': status,
      'created_at': createdAt,
    };
  }
}
