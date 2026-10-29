import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/driver_model.dart';
import '../models/order_model.dart';

class SessionManager {
  static const String _keyDriver = 'cargoo_driver_profile';
  static const String _keyOnline = 'cargoo_driver_online';
  static const String _keyPjVerified = 'cargoo_driver_pj_verified';
  static const String _keyWalletDebt = 'cargoo_driver_wallet_debt';
  static const String _keyActiveTrip = 'cargoo_driver_active_trip';
  static const String _keyTripHistory = 'cargoo_driver_trip_history';
  static const String _keyToken = 'cargoo_driver_token';
  static const String _keyLanguage = 'cargoo_app_language';

  // Language Preference (Kiswahili / English)
  static Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguage) ?? 'sw';
  }

  static Future<void> setLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, lang);
  }

  // Maximum commission debt limit before app locks
  static const double maxDebtLimit = 10000.0;

  // Save driver profile
  static Future<void> saveDriver(DriverModel driver) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDriver, jsonEncode(driver.toMap()));
  }

  // Get driver profile
  static Future<DriverModel?> getDriver() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyDriver);
    if (data == null || data.isEmpty) return null;
    try {
      return DriverModel.fromMap(jsonDecode(data) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // Online / Offline toggle
  static Future<void> setOnline(bool online) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnline, online);
  }

  static Future<bool> isOnline() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnline) ?? false;
  }

  // AI PJ Verification Status
  static Future<void> setPjVerified(bool verified) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPjVerified, verified);
    final current = await getDriver();
    if (current != null) {
      await saveDriver(current.copyWith(isPjVerified: verified));
    }
  }

  static Future<bool> isPjVerified() async {
    final prefs = await SharedPreferences.getInstance();
    final isVer = prefs.getBool(_keyPjVerified);
    if (isVer != null) return isVer;
    final driver = await getDriver();
    return driver?.isPjVerified ?? false;
  }

  // Wallet Debt Management (Post-Pay 7% Commission)
  static Future<double> getWalletDebt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyWalletDebt) ?? 0.0;
  }

  static Future<double> addCommissionDebt(double commissionAmount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getWalletDebt();
    final newDebt = current + commissionAmount;
    await prefs.setDouble(_keyWalletDebt, newDebt);
    return newDebt;
  }

  static Future<double> payWalletDebt(double amountPaid) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getWalletDebt();
    final newDebt = (current - amountPaid) > 0 ? (current - amountPaid) : 0.0;
    await prefs.setDouble(_keyWalletDebt, newDebt);
    return newDebt;
  }

  static Future<bool> isDebtLimitExceeded() async {
    final debt = await getWalletDebt();
    return debt >= maxDebtLimit;
  }

  // Active Trip Persistence
  static Future<void> saveActiveTrip(CargoOrder order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActiveTrip, jsonEncode(order.toMap()));
  }

  static Future<CargoOrder?> getActiveTrip() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyActiveTrip);
    if (data == null || data.isEmpty) return null;
    try {
      return CargoOrder.fromMap(jsonDecode(data) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearActiveTrip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyActiveTrip);
  }

  // Completed Trips History
  static Future<void> saveCompletedTrip(CargoOrder order) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getCompletedTrips();
    list.insert(0, order);
    final encoded = list.map((e) => e.toMap()).toList();
    await prefs.setString(_keyTripHistory, jsonEncode(encoded));
  }

  static Future<List<CargoOrder>> getCompletedTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyTripHistory);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => CargoOrder.fromMap(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  // Token Management
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
