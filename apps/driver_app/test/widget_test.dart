import 'package:flutter_test/flutter_test.dart';
import 'package:driver_app/models/driver_model.dart';
import 'package:driver_app/models/order_model.dart';
import 'package:driver_app/services/session_manager.dart';

void main() {
  test('DriverModel serialization and PJ verification status test', () {
    final driver = DriverModel(
      id: 'DRV-TZ-1082',
      name: 'Juma Shabani Mussa',
      phone: '0714 882 109',
      nida: '19920814-14102-00001-24',
      licenseNumber: 'DL-TZ-772910',
      licenseClass: 'Class C (Kirikuu & Canter)',
      vehicleType: 'Kirikuu Pick-up',
      vehiclePlate: 'T 482 DWK',
      vehicleColor: 'Nyeupe (White)',
      rating: 4.95,
      isPjVerified: true,
      walletDebt: 0.0,
      isOnline: true,
    );

    final map = driver.toMap();
    expect(map['name'], 'Juma Shabani Mussa');
    expect(map['is_pj_verified'], true);
    expect(map['vehicle_plate'], 'T 482 DWK');

    final reconstructed = DriverModel.fromMap(map);
    expect(reconstructed.name, driver.name);
    expect(reconstructed.isPjVerified, true);
    expect(reconstructed.vehicleType, 'Kirikuu Pick-up');
  });

  test('CargoOrder commission calculation (7% CARGOO, 93% Driver)', () {
    final order = CargoOrder.fromMap({
      'trip_id': 'CRG-TEST-100',
      'fare_amount': 'TZS 20,000',
      'customer_name': 'John Mwangi',
      'pickup_name': 'Mbezi Beach',
      'dropoff_name': 'Kariakoo Msimbazi',
      'cargo_notes': 'Mifuko 30 ya sementi, ipo getini',
    });

    expect(order.numericFare, 20000.0);
    expect(order.commissionAmount, 1400.0); // 7%
    expect(order.netDriverEarnings, 18600.0); // 93%
  });

  test('Commission debt limit constant test', () {
    expect(SessionManager.maxDebtLimit, 10000.0);
  });
}
