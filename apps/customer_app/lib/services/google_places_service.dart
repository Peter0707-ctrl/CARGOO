import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'session_manager.dart';

class GooglePlacesService {
  static const String _sessionKey = 'cargoo_google_maps_api_key';
  static String? _cachedApiKey;

  /// Retrieve the configured Google Maps API Key from SessionManager or backend
  static Future<String?> getApiKey() async {
    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey;
    }
    final user = await SessionManager.getUser();
    final key = user?[_sessionKey]?.toString();
    if (key != null && key.isNotEmpty) {
      _cachedApiKey = key;
      return key;
    }

    // Try fetching from backend API
    try {
      final res = await http.get(Uri.parse('${ApiService.baseUrl}/config/google-maps-key'))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['key'] != null && data['key'].toString().isNotEmpty) {
          _cachedApiKey = data['key'].toString();
          return _cachedApiKey;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Save API Key to local session and backend
  static Future<void> saveApiKey(String apiKey) async {
    _cachedApiKey = apiKey.trim();
    final user = await SessionManager.getUser() ?? {};
    user[_sessionKey] = _cachedApiKey;
    await SessionManager.saveUser(user);

    // Save to backend
    try {
      await http.post(
        Uri.parse('${ApiService.baseUrl}/config/google-maps-key'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'key': _cachedApiKey}),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  /// Perform live Google Places Autocomplete search across Tanzania
  static Future<List<Map<String, dynamic>>> searchPlaces({
    required String query,
    double? proximityLat,
    double? proximityLng,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return [];
    }

    try {
      final lat = proximityLat ?? -6.7725;
      final lng = proximityLng ?? 39.2208;

      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&components=country:tz'
        '&location=$lat,$lng'
        '&radius=50000'
        '&language=en'
        '&key=$apiKey',
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final status = data['status'];
        if (status == 'OK') {
          final predictions = data['predictions'] as List? ?? [];
          final List<Map<String, dynamic>> results = [];

          for (final item in predictions) {
            final placeId = item['place_id']?.toString() ?? '';
            final description = item['description']?.toString() ?? query;
            final structured = item['structured_formatting'] as Map<String, dynamic>? ?? {};
            final mainText = structured['main_text']?.toString() ?? description.split(',').first;
            final secondaryText = structured['secondary_text']?.toString() ?? 'Tanzania';

            results.add({
              'placeId': placeId,
              'title': mainText,
              'subtitle': secondaryText,
              'description': description,
              'isGooglePlace': true,
              'isVerified': true,
            });
          }
          return results;
        } else {
          debugPrint('Google Places API status: $status');
        }
      }
    } catch (e) {
      debugPrint('Google Places search error: $e');
    }
    return [];
  }

  /// Retrieve exact latitude and longitude for a Google Place ID
  static Future<Map<String, double>?> getPlaceCoordinates(String placeId) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty || placeId.isEmpty) {
      return null;
    }

    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=geometry,name,formatted_address'
        '&key=$apiKey',
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'OK') {
          final result = data['result'] as Map<String, dynamic>? ?? {};
          final geometry = result['geometry'] as Map<String, dynamic>? ?? {};
          final location = geometry['location'] as Map<String, dynamic>? ?? {};
          final lat = (location['lat'] as num?)?.toDouble();
          final lng = (location['lng'] as num?)?.toDouble();

          if (lat != null && lng != null) {
            return {'lat': lat, 'lng': lng};
          }
        }
      }
    } catch (e) {
      debugPrint('Google Places details error: $e');
    }
    return null;
  }
}
