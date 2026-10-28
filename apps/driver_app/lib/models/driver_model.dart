class DriverModel {
  final String id;
  final String name;
  final String phone;
  final String nida;
  final String licenseNumber;
  final String licenseClass;
  final String vehicleType;
  final String vehiclePlate;
  final String vehicleColor;
  final String avatar;
  final bool isPjVerified;
  final double rating;
  final double walletDebt; // Negative or 0.0, max -10,000 before app lock
  final bool isOnline;

  DriverModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.nida,
    required this.licenseNumber,
    required this.licenseClass,
    required this.vehicleType,
    required this.vehiclePlate,
    required this.vehicleColor,
    this.avatar = '',
    this.isPjVerified = false,
    this.rating = 5.0,
    this.walletDebt = 0.0,
    this.isOnline = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'nida': nida,
      'license_number': licenseNumber,
      'license_class': licenseClass,
      'vehicle_type': vehicleType,
      'vehicle_plate': vehiclePlate,
      'vehicle_color': vehicleColor,
      'avatar': avatar,
      'is_pj_verified': isPjVerified,
      'rating': rating,
      'wallet_debt': walletDebt,
      'is_online': isOnline,
    };
  }

  factory DriverModel.fromMap(Map<String, dynamic> map) {
    return DriverModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      nida: map['nida']?.toString() ?? '',
      licenseNumber: map['license_number']?.toString() ?? '',
      licenseClass: map['license_class']?.toString() ?? 'Class C',
      vehicleType: map['vehicle_type']?.toString() ?? 'Kirikuu Pick-up',
      vehiclePlate: map['vehicle_plate']?.toString() ?? 'T 482 DWK',
      vehicleColor: map['vehicle_color']?.toString() ?? 'White',
      avatar: map['avatar']?.toString() ?? '',
      isPjVerified: map['is_pj_verified'] == true || map['is_pj_verified'] == 1,
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      walletDebt: (map['wallet_debt'] as num?)?.toDouble() ?? 0.0,
      isOnline: map['is_online'] == true || map['is_online'] == 1,
    );
  }

  DriverModel copyWith({
    String? name,
    String? phone,
    String? nida,
    String? licenseNumber,
    String? licenseClass,
    String? vehicleType,
    String? vehiclePlate,
    String? vehicleColor,
    String? avatar,
    bool? isPjVerified,
    double? rating,
    double? walletDebt,
    bool? isOnline,
  }) {
    return DriverModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      nida: nida ?? this.nida,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      licenseClass: licenseClass ?? this.licenseClass,
      vehicleType: vehicleType ?? this.vehicleType,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      avatar: avatar ?? this.avatar,
      isPjVerified: isPjVerified ?? this.isPjVerified,
      rating: rating ?? this.rating,
      walletDebt: walletDebt ?? this.walletDebt,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
