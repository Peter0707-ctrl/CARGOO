class DriverModel {
  final String id;
  final String name;
  final String phone;
  final String nida;
  final String licenseNumber;
  final String licenseClass;
  final String vehicleType;
  final String vehiclePlate;
  final String loadCapacity;
  final String vehicleColor;
  final String avatar;
  final bool isPjVerified;
  final double rating;
  final double walletDebt; // Negative or 0.0, max -10,000 before app lock
  final bool isOnline;

  // KYC Photo documents
  final String driverPhoto;
  final String nidaPhoto;
  final String licensePhoto;
  final String vehiclePhoto;
  final String kycCertificateId;
  final String kycVerificationDate;

  DriverModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.nida,
    required this.licenseNumber,
    required this.licenseClass,
    required this.vehicleType,
    required this.vehiclePlate,
    this.loadCapacity = 'Tani 1.5 (Kilo 1,500)',
    this.vehicleColor = '',
    this.avatar = '',
    this.isPjVerified = false,
    this.rating = 5.0,
    this.walletDebt = 0.0,
    this.isOnline = false,
    this.driverPhoto = '',
    this.nidaPhoto = '',
    this.licensePhoto = '',
    this.vehiclePhoto = '',
    this.kycCertificateId = '',
    this.kycVerificationDate = '',
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
      'load_capacity': loadCapacity,
      'vehicle_color': vehicleColor,
      'avatar': avatar,
      'is_pj_verified': isPjVerified,
      'rating': rating,
      'wallet_debt': walletDebt,
      'is_online': isOnline,
      'driver_photo': driverPhoto,
      'nida_photo': nidaPhoto,
      'license_photo': licensePhoto,
      'vehicle_photo': vehiclePhoto,
      'kyc_certificate_id': kycCertificateId,
      'kyc_verification_date': kycVerificationDate,
    };
  }

  factory DriverModel.fromMap(Map<String, dynamic> map) {
    return DriverModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      nida: map['nida']?.toString() ?? '',
      licenseNumber: map['license_number']?.toString() ?? '',
      licenseClass: map['license_class']?.toString() ?? 'Daraja C1 (Kirikuu & Canter Ndogo)',
      vehicleType: map['vehicle_type']?.toString() ?? 'Kirikuu Pick-up',
      vehiclePlate: map['vehicle_plate']?.toString() ?? 'T 482 DWK',
      loadCapacity: map['load_capacity']?.toString() ?? 'Tani 1.5 (Kilo 1,500)',
      vehicleColor: map['vehicle_color']?.toString() ?? '',
      avatar: map['avatar']?.toString() ?? '',
      isPjVerified: map['is_pj_verified'] == true || map['is_pj_verified'] == 1,
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      walletDebt: (map['wallet_debt'] as num?)?.toDouble() ?? 0.0,
      isOnline: map['is_online'] == true || map['is_online'] == 1,
      driverPhoto: map['driver_photo']?.toString() ?? '',
      nidaPhoto: map['nida_photo']?.toString() ?? '',
      licensePhoto: map['license_photo']?.toString() ?? '',
      vehiclePhoto: map['vehicle_photo']?.toString() ?? '',
      kycCertificateId: map['kyc_certificate_id']?.toString() ?? '',
      kycVerificationDate: map['kyc_verification_date']?.toString() ?? '',
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
    String? loadCapacity,
    String? vehicleColor,
    String? avatar,
    bool? isPjVerified,
    double? rating,
    double? walletDebt,
    bool? isOnline,
    String? driverPhoto,
    String? nidaPhoto,
    String? licensePhoto,
    String? vehiclePhoto,
    String? kycCertificateId,
    String? kycVerificationDate,
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
      loadCapacity: loadCapacity ?? this.loadCapacity,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      avatar: avatar ?? this.avatar,
      isPjVerified: isPjVerified ?? this.isPjVerified,
      rating: rating ?? this.rating,
      walletDebt: walletDebt ?? this.walletDebt,
      isOnline: isOnline ?? this.isOnline,
      driverPhoto: driverPhoto ?? this.driverPhoto,
      nidaPhoto: nidaPhoto ?? this.nidaPhoto,
      licensePhoto: licensePhoto ?? this.licensePhoto,
      vehiclePhoto: vehiclePhoto ?? this.vehiclePhoto,
      kycCertificateId: kycCertificateId ?? this.kycCertificateId,
      kycVerificationDate: kycVerificationDate ?? this.kycVerificationDate,
    );
  }
}
