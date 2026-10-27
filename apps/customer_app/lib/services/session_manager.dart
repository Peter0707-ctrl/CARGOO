import 'dart:convert';
import 'dart:io';

class SessionManager {
  static Future<File> _getFile() async {
    // Android internal private app directory
    final dir = Directory('/data/data/com.cargoo.customer.customer_app/files');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return File('${dir.path}/cargoo_user_session.json');
  }

  /// Checks if user has already completed registration
  static Future<bool> isLoggedIn() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return false;
      final content = await file.readAsString();
      if (content.isEmpty) return false;
      final data = jsonDecode(content);
      return data != null && data['name'] != null && data['name'].toString().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Retrieves saved user details
  static Future<Map<String, dynamic>?> getUser() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Saves user details upon successful registration
  static Future<void> saveUser(Map<String, dynamic> user) async {
    try {
      final file = await _getFile();
      await file.writeAsString(jsonEncode(user));
    } catch (_) {}
  }

  /// Clears session when logging out
  static Future<void> clearSession() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  static Future<File> _getSearchesFile() async {
    final dir = Directory('/data/data/com.cargoo.customer.customer_app/files');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return File('${dir.path}/cargoo_recent_searches.json');
  }

  /// Retrieves dynamically saved search history
  static Future<List<Map<String, dynamic>>> getRecentSearches() async {
    try {
      final file = await _getSearchesFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final List list = jsonDecode(content);
          return list.map((item) => Map<String, dynamic>.from(item)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Saves a dynamically chosen search place to history
  static Future<void> saveRecentSearch(Map<String, dynamic> place) async {
    try {
      final list = await getRecentSearches();
      list.removeWhere((item) => item['title'] == place['title']);
      list.insert(0, {
        'title': place['title'],
        'subtitle': place['subtitle'],
        'distance': place['distance'],
        'lat': place['lat'],
        'lng': place['lng'],
      });
      if (list.length > 8) {
        list.removeRange(8, list.length);
      }
      final file = await _getSearchesFile();
      await file.writeAsString(jsonEncode(list));
    } catch (_) {}
  }

  /// Clears recent searches
  static Future<void> clearRecentSearches() async {
    try {
      final file = await _getSearchesFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  static Future<File> _getTripsFile() async {
    final dir = Directory('/data/data/com.cargoo.customer.customer_app/files');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return File('${dir.path}/cargoo_booked_trips.json');
  }

  /// Retrieves dynamically saved booked trips (Activity history)
  static Future<List<Map<String, dynamic>>> getBookedTrips() async {
    try {
      final file = await _getTripsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final List list = jsonDecode(content);
          return list.map((item) => Map<String, dynamic>.from(item)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Saves a newly confirmed cargo booking to persistent history
  static Future<void> saveBookedTrip(Map<String, dynamic> trip) async {
    try {
      final list = await getBookedTrips();
      // Remove any existing entry with the same id to avoid duplicates
      list.removeWhere((item) => item['id'] == trip['id']);
      list.insert(0, trip);
      if (list.length > 20) {
        list.removeRange(20, list.length);
      }
      final file = await _getTripsFile();
      await file.writeAsString(jsonEncode(list));
    } catch (_) {}
  }

  /// Updates an existing booked trip by trip_id (e.g. marking as Cancelled, Driver Dispatched, or Completed)
  static Future<void> updateBookedTripStatus(String tripId, String status, {String? reason}) async {
    try {
      final list = await getBookedTrips();
      bool found = false;
      for (int i = 0; i < list.length; i++) {
        if (list[i]['id'] == tripId || list[i]['trip_id'] == tripId) {
          list[i]['status'] = status;
          list[i]['is_active'] = status == 'Driver Dispatched' || status == 'In Transit';
          if (reason != null) {
            list[i]['cancellation_reason'] = reason;
          }
          if (status == 'Cancelled' || status == 'Canceled') {
            list[i]['cancelled_at'] = DateTime.now().toIso8601String();
          }
          found = true;
          break;
        }
      }
      if (found) {
        final file = await _getTripsFile();
        await file.writeAsString(jsonEncode(list));
      }
    } catch (_) {}
  }

  /// Clears booked trips
  static Future<void> clearBookedTrips() async {
    try {
      final file = await _getTripsFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  static Future<File> _getActiveTripFile() async {
    final dir = Directory('/data/data/com.cargoo.customer.customer_app/files');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return File('${dir.path}/cargoo_active_trip.json');
  }

  /// Retrieves currently active ongoing cargo trip (if any)
  static Future<Map<String, dynamic>?> getActiveTrip() async {
    try {
      final file = await _getActiveTripFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final data = jsonDecode(content);
          if (data is Map<String, dynamic> && data['is_active'] == true) {
            return data;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Sets or updates the active trip
  static Future<void> saveActiveTrip(Map<String, dynamic> trip) async {
    try {
      final file = await _getActiveTripFile();
      final data = Map<String, dynamic>.from(trip);
      data['is_active'] = true;
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  /// Clears or completes the active trip once cargo has arrived safely
  static Future<void> clearActiveTrip() async {
    try {
      final file = await _getActiveTripFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Persistent hardware/device security fingerprint for Admin Fraud Dossier ONLY
  /// Survives user logouts so fraudulent accounts cannot evade detection by switching numbers
  static Future<Map<String, String>> getDeviceSecurityFingerprint() async {
    try {
      final dir = Directory('/data/data/com.cargoo.customer.customer_app/files');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final file = File('${dir.path}/cargoo_device_fingerprint.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final parsed = jsonDecode(content) as Map<String, dynamic>;
          return parsed.map((k, v) => MapEntry(k, v.toString()));
        }
      }
      final ts = DateTime.now().millisecondsSinceEpoch;
      final hwHash = 'CRG-HW-${Platform.operatingSystem.toUpperCase()}-${(ts % 99999999).toString().padLeft(8, '0')}';
      final fingerprint = {
        'device_id': hwHash,
        'os_platform': '${Platform.operatingSystem} (${Platform.operatingSystemVersion})',
        'first_seen_utc': DateTime.now().toUtc().toIso8601String(),
      };
      await file.writeAsString(jsonEncode(fingerprint));
      return fingerprint;
    } catch (_) {
      return {
        'device_id': 'CRG-HW-ANDROID-SECURE',
        'os_platform': 'android',
      };
    }
  }
}
