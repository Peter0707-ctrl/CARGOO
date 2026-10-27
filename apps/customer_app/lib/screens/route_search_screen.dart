import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../services/session_manager.dart';
import '../services/google_places_service.dart';
import 'map_route_screen.dart';

class RouteSearchScreen extends StatefulWidget {
  final String currentPickup;
  final LatLng currentPickupLatLng;
  final int initialVehicleIndex;
  final String? scheduledFor;

  const RouteSearchScreen({
    super.key,
    required this.currentPickup,
    required this.currentPickupLatLng,
    this.initialVehicleIndex = 0,
    this.scheduledFor,
  });

  @override
  State<RouteSearchScreen> createState() => _RouteSearchScreenState();
}

class _RouteSearchScreenState extends State<RouteSearchScreen> {
  late TextEditingController _pickupController;
  final TextEditingController _dropoffController = TextEditingController();
  final FocusNode _pickupFocus = FocusNode();
  final FocusNode _dropoffFocus = FocusNode();

  late LatLng _pickupLatLng;
  LatLng? _dropoffLatLng;

  bool _isSelectingPickup = false; // true when user is searching/editing pickup
  bool _isSearchingOnline = false;
  String _currentQuery = '';
  Timer? _debounceTimer;

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _pickupController = TextEditingController(text: widget.currentPickup);
    _pickupLatLng = widget.currentPickupLatLng;

    _loadRecentSearches();

    _pickupFocus.addListener(() {
      if (_pickupFocus.hasFocus) {
        setState(() {
          _isSelectingPickup = true;
          _currentQuery = _pickupController.text.trim();
        });
        if (_currentQuery.isNotEmpty) {
          _performSearch(_currentQuery);
        } else {
          setState(() => _searchResults = []);
        }
      }
    });

    _dropoffFocus.addListener(() {
      if (_dropoffFocus.hasFocus) {
        setState(() {
          _isSelectingPickup = false;
          _currentQuery = _dropoffController.text.trim();
        });
        if (_currentQuery.isNotEmpty) {
          _performSearch(_currentQuery);
        } else {
          setState(() => _searchResults = []);
        }
      }
    });

    _pickupController.addListener(_onInputChanged);
    _dropoffController.addListener(_onInputChanged);

    // By default, focus dropoff field on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dropoffFocus.requestFocus();
    });
  }

  Future<void> _loadRecentSearches() async {
    final recent = await SessionManager.getRecentSearches();
    if (mounted) {
      setState(() => _recentSearches = recent);
    }
  }

  void _onInputChanged() {
    final activeText = _isSelectingPickup
        ? _pickupController.text.trim()
        : _dropoffController.text.trim();

    if (activeText == _currentQuery) return;
    _currentQuery = activeText;

    _debounceTimer?.cancel();
    if (activeText.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearchingOnline = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 320), () {
      _performSearch(activeText);
    });
  }

  static bool _isValidTzCoord(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat == 0.0 && lng == 0.0) return false;
    // Strict Tanzania geographic boundary: Latitude [-11.75 to -0.99], Longitude [29.30 to 40.50]
    return lat >= -11.75 && lat <= -0.99 && lng >= 29.30 && lng <= 40.50;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)); // In kilometers
  }

  static const List<Map<String, dynamic>> _tanzaniaLandmarks = [
    // Reliance Solutions & Local Tech Hubs (Requested by User)
    {
      'title': 'Reliance Solutions and Technology (T) Limited',
      'subtitle': 'Mikocheni B, Kinondoni, Dar es Salaam',
      'lat': -6.7645,
      'lng': 39.2475,
      'keywords': 'reliance solutions technology mikocheni erb smartsale teamtrack dar',
    },
    // Dar es Salaam - Major Markets, Commercial Centers & Ports
    {
      'title': 'Kariakoo Market',
      'subtitle': 'Swahili St, Kariakoo, Dar es Salaam',
      'lat': -6.8200,
      'lng': 39.2770,
      'keywords': 'kariakoo market soko msimbazi congo swahili kkoo dar es salaam',
    },
    {
      'title': 'Mlimani City Mall',
      'subtitle': 'Sam Nujoma Rd, Mwenge, Dar es Salaam',
      'lat': -6.7725,
      'lng': 39.2208,
      'keywords': 'mlimani city mall mwenge shopping sam nujoma dar',
    },
    {
      'title': 'Mwenge Bus Terminal & Market',
      'subtitle': 'Bagamoyo Rd / Sam Nujoma Rd, Mwenge',
      'lat': -6.7712,
      'lng': 39.2275,
      'keywords': 'mwenge stendi soko woodcarvers bagamoyo dar es salaam',
    },
    {
      'title': 'Magufuli Bus Terminal (Mbezi Luis)',
      'subtitle': 'Morogoro Rd, Mbezi Luis, Dar es Salaam',
      'lat': -6.7865,
      'lng': 39.1172,
      'keywords': 'magufuli terminal mbezi luis stand mabasi ya mikoani morogoro rd',
    },
    {
      'title': 'Julius Nyerere International Airport (JNIA)',
      'subtitle': 'Julius Nyerere Rd, Kipawa, Dar es Salaam',
      'lat': -6.8781,
      'lng': 39.2026,
      'keywords': 'jnia airport uwanja wa ndege terminal 2 terminal 3 dar',
    },
    {
      'title': 'Dar es Salaam Port (Bandari Kuu)',
      'subtitle': 'Bandari Rd, Kurasini, Dar es Salaam',
      'lat': -6.8378,
      'lng': 39.2892,
      'keywords': 'port bandari kurasini icd kontena containers harbour dar',
    },
    {
      'title': 'Posta Mpya & Kivukoni Front',
      'subtitle': 'Sokoine Drive, Kivukoni, Dar es Salaam',
      'lat': -6.8162,
      'lng': 39.2922,
      'keywords': 'posta mpya kivukoni posta sokoine city centre cbd dsm',
    },
    {
      'title': 'Kivukoni Ferry & Fish Market',
      'subtitle': 'Ocean Rd, Kivukoni, Dar es Salaam',
      'lat': -6.8211,
      'lng': 39.2995,
      'keywords': 'kivukoni ferry kivukoni soko la samaki kigamboni pantoni',
    },
    {
      'title': 'Muhimbili National Hospital',
      'subtitle': 'Kalenga St, Upanga West, Dar es Salaam',
      'lat': -6.8067,
      'lng': 39.2747,
      'keywords': 'muhimbili hospital mnh upanga kalenga daktari dar',
    },
    {
      'title': 'University of Dar es Salaam (UDSM)',
      'subtitle': 'University Rd, Mlimani Campus, Dar es Salaam',
      'lat': -6.7792,
      'lng': 39.2064,
      'keywords': 'udsm university chuo kikuu mlimani dar es salaam',
    },
    {
      'title': 'Sinza Mori',
      'subtitle': 'Shekilango Rd, Sinza, Dar es Salaam',
      'lat': -6.7834,
      'lng': 39.2241,
      'keywords': 'sinza mori shekilango barabara ya sinza dar',
    },
    {
      'title': 'Sinza Afrika Sana',
      'subtitle': 'Sinza, Dar es Salaam',
      'lat': -6.7885,
      'lng': 39.2289,
      'keywords': 'sinza afrika sana madukani stand sinza',
    },
    {
      'title': 'Sinza Palestina Hospital',
      'subtitle': 'Sinza C, Dar es Salaam',
      'lat': -6.7890,
      'lng': 39.2230,
      'keywords': 'sinza palestina hospitali zahanati sinza',
    },
    {
      'title': 'Mikocheni B (Rose Garden)',
      'subtitle': 'Rose Garden Rd, Mikocheni, Dar es Salaam',
      'lat': -6.7645,
      'lng': 39.2458,
      'keywords': 'mikocheni b rose garden mikocheni dar',
    },
    {
      'title': 'Mikocheni A (Old Bagamoyo Rd)',
      'subtitle': 'Old Bagamoyo Rd, Mikocheni, Dar es Salaam',
      'lat': -6.7610,
      'lng': 39.2510,
      'keywords': 'mikocheni a old bagamoyo rd shoppers plaza mikocheni',
    },
    {
      'title': 'Masaki Slipway & Waterfront',
      'subtitle': 'Slipway Rd, Masaki, Dar es Salaam',
      'lat': -6.7495,
      'lng': 39.2740,
      'keywords': 'masaki slipway peninsula sea cliff choole rd dar',
    },
    {
      'title': 'Oysterbay Coco Beach',
      'subtitle': 'Toure Drive, Oysterbay, Dar es Salaam',
      'lat': -6.7735,
      'lng': 39.2758,
      'keywords': 'coco beach toure drive oysterbay ufukweni dar',
    },
    {
      'title': 'Tegeta Nyuki Market',
      'subtitle': 'Bagamoyo Rd, Tegeta, Dar es Salaam',
      'lat': -6.6789,
      'lng': 39.2056,
      'keywords': 'tegeta nyuki soko la tegeta kibo complex bagamoyo rd',
    },
    {
      'title': 'Tegeta Kibaoni',
      'subtitle': 'Tegeta, Dar es Salaam',
      'lat': -6.6850,
      'lng': 39.2010,
      'keywords': 'tegeta kibaoni stand kituo tegeta',
    },
    {
      'title': 'Goba Center',
      'subtitle': 'Goba Main Rd, Kinondoni, Dar es Salaam',
      'lat': -6.7420,
      'lng': 39.1550,
      'keywords': 'goba center njia panda goba kulangwa makongo dar',
    },
    {
      'title': 'Kimara Mwisho Terminal',
      'subtitle': 'Morogoro Rd, Kimara, Dar es Salaam',
      'lat': -6.7932,
      'lng': 39.1685,
      'keywords': 'kimara mwisho mwendokasi morogoro rd dar',
    },
    {
      'title': 'Kimara Korogwe',
      'subtitle': 'Morogoro Rd, Kimara, Dar es Salaam',
      'lat': -6.7910,
      'lng': 39.1820,
      'keywords': 'kimara korogwe morogoro road dar',
    },
    {
      'title': 'Ubungo Interchange (Kijazi Flyover)',
      'subtitle': 'Morogoro Rd / Nelson Mandela Rd, Ubungo',
      'lat': -6.7812,
      'lng': 39.2134,
      'keywords': 'ubungo flyover kijazi interchange morogoro nelson mandela',
    },
    {
      'title': 'Ubungo Maji',
      'subtitle': 'Nelson Mandela Rd, Ubungo, Dar es Salaam',
      'lat': -6.7850,
      'lng': 39.2160,
      'keywords': 'ubungo maji dawasa nelson mandela rd ubungo',
    },
    {
      'title': 'Vingunguti Industrial Area',
      'subtitle': 'Nyerere Rd, Vingunguti, Dar es Salaam',
      'lat': -6.8354,
      'lng': 39.2312,
      'keywords': 'vingunguti viwandani nyerere rd machinjioni dar',
    },
    {
      'title': 'Buguruni Malapa & Market',
      'subtitle': 'Uhuru St / Mandela Rd, Buguruni, Dar es Salaam',
      'lat': -6.8285,
      'lng': 39.2541,
      'keywords': 'buguruni malapa soko rozana chama dar',
    },
    {
      'title': 'Ilala Boma (Uhuru Street)',
      'subtitle': 'Uhuru St, Ilala, Dar es Salaam',
      'lat': -6.8234,
      'lng': 39.2662,
      'keywords': 'ilala boma uhuru street manispaa ilala dar',
    },
    {
      'title': 'Ilala Amana Hospital',
      'subtitle': 'Uhuru St, Ilala, Dar es Salaam',
      'lat': -6.8260,
      'lng': 39.2630,
      'keywords': 'amana hospitali ya amana ilala uhuru st dar',
    },
    {
      'title': 'Temeke Stereo',
      'subtitle': 'Mandela Rd, Temeke, Dar es Salaam',
      'lat': -6.8521,
      'lng': 39.2642,
      'keywords': 'temeke stereo mandela rd mabatini dar',
    },
    {
      'title': 'Tandika Market',
      'subtitle': 'Tandika, Temeke, Dar es Salaam',
      'lat': -6.8584,
      'lng': 39.2731,
      'keywords': 'tandika soko sokoni temeke dar',
    },
    {
      'title': 'Kigamboni Ferry & Nyerere Bridge',
      'subtitle': 'Kigamboni, Dar es Salaam',
      'lat': -6.8361,
      'lng': 39.3082,
      'keywords': 'kigamboni ferry daraja la kigamboni nyerere bridge dar',
    },
    {
      'title': 'Tabata Relini',
      'subtitle': 'Tabata Main Rd, Ilala, Dar es Salaam',
      'lat': -6.8189,
      'lng': 39.2284,
      'keywords': 'tabata relini bima matumbi changombe dar',
    },
    {
      'title': 'Tabata Segerea',
      'subtitle': 'Segerea Rd, Tabata, Dar es Salaam',
      'lat': -6.8310,
      'lng': 39.1950,
      'keywords': 'tabata segerea gereza segerea dar',
    },
    {
      'title': 'Tabata Kinyerezi',
      'subtitle': 'Kinyerezi, Dar es Salaam',
      'lat': -6.8380,
      'lng': 39.1810,
      'keywords': 'kinyerezi tabata gas plant dar',
    },
    {
      'title': 'Kawe Roundabout (Mbezi Beach)',
      'subtitle': 'Bagamoyo Rd / Kawe, Dar es Salaam',
      'lat': -6.7321,
      'lng': 39.2378,
      'keywords': 'kawe mbezi beach bagamoyo rd tanganyika packers dar',
    },
    {
      'title': 'Kunduchi Beach & Wet N Wild',
      'subtitle': 'Kunduchi Mtongani, Dar es Salaam',
      'lat': -6.6698,
      'lng': 39.2212,
      'keywords': 'kunduchi beach wet n wild bahari dar',
    },
    {
      'title': 'Tandale Kwa Mtogole',
      'subtitle': 'Tandale, Kinondoni, Dar es Salaam',
      'lat': -6.7962,
      'lng': 39.2415,
      'keywords': 'tandale kwa mtogole sokoni kinondoni dar',
    },
    {
      'title': 'Manzese Argentina & Tip Top',
      'subtitle': 'Morogoro Rd, Manzese, Dar es Salaam',
      'lat': -6.8021,
      'lng': 39.2318,
      'keywords': 'manzese argentina tip top morogoro rd soko manzese dar',
    },
    {
      'title': 'Mbagala Rangi Tatu',
      'subtitle': 'Kilwa Rd, Mbagala, Dar es Salaam',
      'lat': -6.9123,
      'lng': 39.2643,
      'keywords': 'mbagala rangi tatu kilwa rd stendi zakhem mbagala dar',
    },
    {
      'title': 'Gongolamboto',
      'subtitle': 'Pugu Rd, Ilala, Dar es Salaam',
      'lat': -6.8834,
      'lng': 39.1523,
      'keywords': 'gongolamboto pugu kambi ndege dar',
    },
    {
      'title': 'Chanika Mwisho',
      'subtitle': 'Chanika, Ilala, Dar es Salaam',
      'lat': -6.9745,
      'lng': 39.0832,
      'keywords': 'chanika mwisho kituo ilala dar',
    },
    {
      'title': 'Kibaha Maili Moja',
      'subtitle': 'Morogoro Rd, Kibaha, Coast Region',
      'lat': -6.7712,
      'lng': 38.9954,
      'keywords': 'kibaha maili moja pwani morogoro rd',
    },
    {
      'title': 'Bagamoyo Historic Port',
      'subtitle': 'Bagamoyo, Coast Region',
      'lat': -6.4421,
      'lng': 38.9045,
      'keywords': 'bagamoyo bandari kaole pwani',
    },
    // Arusha & Northern Region
    {
      'title': 'Arusha Clock Tower',
      'subtitle': 'Boma Rd / Sokoine Rd, Arusha City',
      'lat': -3.3725,
      'lng': 36.6942,
      'keywords': 'arusha clock tower katikati ya jiji boma rd sokoine',
    },
    {
      'title': 'Kilombero Market Arusha',
      'subtitle': 'Market St, Arusha',
      'lat': -3.3765,
      'lng': 36.6852,
      'keywords': 'kilombero market soko la kilombero arusha',
    },
    // Dodoma Capital
    {
      'title': 'Nyerere Square Dodoma',
      'subtitle': 'Capital City Centre, Dodoma',
      'lat': -6.1731,
      'lng': 35.7482,
      'keywords': 'dodoma nyerere square bunge makao makuu',
    },
    {
      'title': 'Nanenane Terminal Dodoma',
      'subtitle': 'Nanenane, Dodoma',
      'lat': -6.1554,
      'lng': 35.7821,
      'keywords': 'nanenane stand stendi ya mabasi dodoma',
    },
    // Mwanza Lake Zone
    {
      'title': 'Mwanza Bismarck Rock',
      'subtitle': 'Capri Point, Mwanza',
      'lat': -2.5182,
      'lng': 32.8984,
      'keywords': 'mwanza bismarck rock jiwe capri point ziwa victoria',
    },
    {
      'title': 'Nyegezi Bus Terminal Mwanza',
      'subtitle': 'Nyegezi, Mwanza',
      'lat': -2.5740,
      'lng': 32.9050,
      'keywords': 'nyegezi bus stand mwanza mabasi ya mikoani',
    },
  ];

  /// Live, proximity-biased, typo-tolerant geocoding strictly bounded to Tanzania
  Future<void> _performSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearchingOnline = false;
      });
      return;
    }

    setState(() => _isSearchingOnline = true);
    final List<Map<String, dynamic>> liveList = [];
    final Set<String> seenKeys = {};
    final lowerQ = cleanQuery.toLowerCase();

    // 1. Instant match from verified Tanzania Landmarks catalog
    for (final loc in _tanzaniaLandmarks) {
      final title = loc['title'].toString().toLowerCase();
      final subtitle = loc['subtitle'].toString().toLowerCase();
      final keywords = (loc['keywords'] ?? '').toString().toLowerCase();

      if (title.contains(lowerQ) || subtitle.contains(lowerQ) || keywords.contains(lowerQ)) {
        final distKm = _calculateDistance(_pickupLatLng.latitude, _pickupLatLng.longitude, loc['lat'] as double, loc['lng'] as double);
        final key = '${loc['title']}_${loc['lat']}';
        seenKeys.add(key);
        liveList.add({
          'title': loc['title'],
          'subtitle': loc['subtitle'],
          'distance': '${distKm.toStringAsFixed(1)} km',
          'lat': loc['lat'],
          'lng': loc['lng'],
          'isVerified': true,
        });
      }
    }

    // 2. Parallel Geocoders: Google Places API + Photon + Nominatim strictly bounded to Tanzania
    try {
      final photonUri = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(cleanQuery)}&lat=${_pickupLatLng.latitude}&lon=${_pickupLatLng.longitude}&bbox=29.3,-11.75,40.5,-0.99&limit=12',
      );
      final nomUri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cleanQuery)}&format=json&countrycodes=tz&limit=10&addressdetails=1',
      );

      final responses = await Future.wait([
        GooglePlacesService.searchPlaces(
          query: cleanQuery,
          proximityLat: _pickupLatLng.latitude,
          proximityLng: _pickupLatLng.longitude,
        ).catchError((_) => <Map<String, dynamic>>[]),
        http.get(photonUri).timeout(const Duration(seconds: 4)).catchError((_) => http.Response('{}', 408)),
        http.get(nomUri, headers: {
          'User-Agent': 'CargooApp/1.0 (contact@cargoo.co.tz)',
          'Accept-Language': 'en',
        }).timeout(const Duration(seconds: 4)).catchError((_) => http.Response('[]', 408)),
      ]);

      // Parse Google Places results (Gold Standard for Tanzania businesses)
      final googleResults = responses[0] as List<Map<String, dynamic>>? ?? [];
      for (final gp in googleResults) {
        final title = gp['title']?.toString() ?? cleanQuery;
        final key = 'google_${gp['placeId'] ?? title}';
        if (!seenKeys.contains(key)) {
          seenKeys.add(key);
          liveList.add({
            'title': title,
            'subtitle': gp['subtitle'] ?? 'Tanzania',
            'distance': 'Google Maps',
            'placeId': gp['placeId'],
            'isGooglePlace': true,
            'isVerified': true,
          });
        }
      }

      // Parse Photon results
      final photonRes = responses[1] as http.Response;
      if (photonRes.statusCode == 200) {
        final data = jsonDecode(photonRes.body);
        final features = data['features'] as List? ?? [];
        for (final item in features) {
          final props = item['properties'] as Map<String, dynamic>? ?? {};
          final geom = item['geometry'] as Map<String, dynamic>? ?? {};
          final coords = geom['coordinates'] as List? ?? [0.0, 0.0];
          final lon = (coords[0] as num).toDouble();
          final lat = (coords[1] as num).toDouble();

          // Reject invalid or ocean coordinates
          if (!_isValidTzCoord(lat, lon)) continue;

          final name = (props['name'] ?? props['street'] ?? cleanQuery).toString();
          final parts = <String>[];
          if (props['street'] != null && props['street'] != name) {
            parts.add(props['street'].toString());
          }
          if (props['locality'] != null && props['locality'] != name) {
            parts.add(props['locality'].toString());
          }
          if (props['district'] != null && props['district'] != name) {
            parts.add(props['district'].toString());
          }
          if (props['city'] != null) {
            parts.add(props['city'].toString());
          } else if (props['state'] != null) {
            parts.add(props['state'].toString());
          }

          final subtitle = parts.isNotEmpty ? parts.join(', ') : 'Tanzania';
          final key = '${name}_$lat';
          if (!seenKeys.contains(key)) {
            seenKeys.add(key);
            final distKm = _calculateDistance(_pickupLatLng.latitude, _pickupLatLng.longitude, lat, lon);
            liveList.add({
              'title': name,
              'subtitle': subtitle,
              'distance': '${distKm.toStringAsFixed(1)} km',
              'lat': lat,
              'lng': lon,
            });
          }
        }
      }

      // Parse Nominatim results
      final nomRes = responses[2] as http.Response;
      if (nomRes.statusCode == 200) {
        final List results = jsonDecode(nomRes.body);
        for (final item in results) {
          final lat = double.tryParse(item['lat'].toString());
          final lon = double.tryParse(item['lon'].toString());

          // Reject invalid or ocean coordinates
          if (!_isValidTzCoord(lat, lon)) continue;

          final title = item['name'] != null && item['name'].toString().isNotEmpty
              ? item['name'].toString()
              : (item['display_name']?.toString().split(',').first ?? cleanQuery);
          final key = '${title}_$lat';
          if (!seenKeys.contains(key)) {
            seenKeys.add(key);
            final distKm = _calculateDistance(_pickupLatLng.latitude, _pickupLatLng.longitude, lat!, lon!);
            liveList.add({
              'title': title,
              'subtitle': item['display_name'] ?? '$cleanQuery, Tanzania',
              'distance': '${distKm.toStringAsFixed(1)} km',
              'lat': lat,
              'lng': lon,
            });
          }
        }
      }
    } catch (_) {}

    // 3. Fallback: If nothing matched yet, add dynamic direct address option with SAFE Tanzania coordinates
    if (liveList.isEmpty && cleanQuery.length >= 2) {
      final safeLat = _isValidTzCoord(_pickupLatLng.latitude, _pickupLatLng.longitude) ? _pickupLatLng.latitude : -6.7715;
      final safeLng = _isValidTzCoord(_pickupLatLng.latitude, _pickupLatLng.longitude) ? _pickupLatLng.longitude : 39.2399;
      liveList.add({
        'title': cleanQuery,
        'subtitle': 'Set as custom dropoff point in Dar es Salaam, Tanzania',
        'distance': '1.5 km',
        'lat': safeLat + 0.015,
        'lng': safeLng + 0.015,
        'isCustom': true,
      });
    }

    // Sort: Google Places and Verified Tanzanian catalog matches first, then by closest road distance
    liveList.sort((a, b) {
      final aPriority = a['isGooglePlace'] == true ? 0 : (a['isVerified'] == true ? 1 : 2);
      final bPriority = b['isGooglePlace'] == true ? 0 : (b['isVerified'] == true ? 1 : 2);
      if (aPriority != bPriority) return aPriority.compareTo(bPriority);

      final distA = double.tryParse(a['distance'].toString().replaceAll(' km', '')) ?? 999.0;
      final distB = double.tryParse(b['distance'].toString().replaceAll(' km', '')) ?? 999.0;
      return distA.compareTo(distB);
    });

    if (mounted) {
      setState(() {
        _searchResults = liveList;
        _isSearchingOnline = false;
      });
    }
  }

  void _swapLocations() {
    if (_dropoffController.text.trim().isEmpty && _dropoffLatLng == null) return;
    setState(() {
      final tempText = _pickupController.text;
      final tempLatLng = _pickupLatLng;

      _pickupController.text = _dropoffController.text;
      if (_dropoffLatLng != null) {
        _pickupLatLng = _dropoffLatLng!;
      }

      _dropoffController.text = tempText;
      _dropoffLatLng = tempLatLng;
    });
  }

  Future<void> _selectPlace(Map<String, dynamic> place) async {
    double? lat = (place['lat'] as num?)?.toDouble();
    double? lng = (place['lng'] as num?)?.toDouble();
    final title = place['title'] as String;

    // If it's a Google Place without resolved coordinates, fetch exact lat/lng
    if ((lat == null || lng == null) && place['placeId'] != null) {
      final coords = await GooglePlacesService.getPlaceCoordinates(place['placeId'] as String);
      if (coords != null) {
        lat = coords['lat'];
        lng = coords['lng'];
        place['lat'] = lat;
        place['lng'] = lng;
      }
    }

    final safePickupLat = _isValidTzCoord(_pickupLatLng.latitude, _pickupLatLng.longitude)
        ? _pickupLatLng.latitude
        : -6.7715;
    final safePickupLng = _isValidTzCoord(_pickupLatLng.latitude, _pickupLatLng.longitude)
        ? _pickupLatLng.longitude
        : 39.2399;

    double finalLat;
    double finalLng;

    if (_isValidTzCoord(lat, lng)) {
      finalLat = lat!;
      finalLng = lng!;
    } else {
      finalLat = safePickupLat - 0.015;
      finalLng = safePickupLng + 0.015;
    }
    place['lat'] = finalLat;
    place['lng'] = finalLng;

    await SessionManager.saveRecentSearch(place);
    _loadRecentSearches();

    if (_isSelectingPickup) {
      setState(() {
        _pickupController.text = title;
        _pickupLatLng = LatLng(finalLat, finalLng);
        _isSelectingPickup = false;
      });
      _dropoffFocus.requestFocus();
    } else {
      _dropoffController.text = title;
      _dropoffLatLng = LatLng(finalLat, finalLng);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MapRouteScreen(
            pickupName: _pickupController.text.isNotEmpty ? _pickupController.text : 'Pickup Location',
            pickupLatLng: LatLng(safePickupLat, safePickupLng),
            dropoffName: title,
            dropoffLatLng: LatLng(finalLat, finalLng),
            initialVehicleIndex: widget.initialVehicleIndex,
            scheduledFor: widget.scheduledFor,
          ),
        ),
      );
    }
  }

  void _useCurrentGpsLocation() {
    setState(() {
      _pickupController.text = widget.currentPickup;
      _pickupLatLng = widget.currentPickupLatLng;
      _isSelectingPickup = false;
    });
    _dropoffFocus.requestFocus();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pickupController.dispose();
    _dropoffController.dispose();
    _pickupFocus.dispose();
    _dropoffFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeText = _isSelectingPickup ? _pickupController.text : _dropoffController.text;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF1E2822), size: 26),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _isSelectingPickup ? 'Select Pickup Point' : 'Select Cargo Destination',
            style: const TextStyle(
              fontFamily: 'Segoe UI Variable',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E2822),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4B7B9F).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _isSelectingPickup ? 'PICKUP' : 'DROPOFF',
                    style: const TextStyle(
                      fontFamily: 'Segoe UI Variable',
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF4B7B9F),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
          children: [
            if (widget.scheduledFor != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF4B7B9F).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF4B7B9F).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFF4B7B9F)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Scheduled for: ${widget.scheduledFor}',
                        style: const TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2C4A63),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Dual Editable Route Box (Pickup & Dropoff with active highlight)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F5F1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFCAD4CC)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Visual line indicator
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4B7B9F),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 2,
                        height: 28,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: const Color(0xFFCAD4CC),
                      ),
                      const Icon(Icons.location_on_rounded, color: Color(0xFFDC2626), size: 16),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Input fields
                  Expanded(
                    child: Column(
                      children: [
                        // Pickup TextField (Editable from ANY location!)
                        TextField(
                          controller: _pickupController,
                          focusNode: _pickupFocus,
                          style: TextStyle(
                            fontFamily: 'Segoe UI Variable',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _isSelectingPickup ? const Color(0xFF4B7B9F) : const Color(0xFF1E2822),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter pickup address (Where to pick cargo)',
                            hintStyle: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 13,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w600,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 6),
                            border: InputBorder.none,
                            suffixIcon: _isSelectingPickup && _pickupController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                                    onPressed: () => _pickupController.clear(),
                                  )
                                : null,
                          ),
                        ),
                        const Divider(height: 14, thickness: 1, color: Color(0xFFCAD4CC)),

                        // Dropoff TextField
                        TextField(
                          controller: _dropoffController,
                          focusNode: _dropoffFocus,
                          style: TextStyle(
                            fontFamily: 'Segoe UI Variable',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: !_isSelectingPickup ? const Color(0xFF4B7B9F) : const Color(0xFF1E2822),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Where to deliver cargo?',
                            hintStyle: TextStyle(
                              fontFamily: 'Segoe UI Variable',
                              fontSize: 13.5,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w600,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 6),
                            border: InputBorder.none,
                            suffixIcon: !_isSelectingPickup && _dropoffController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                                    onPressed: () => _dropoffController.clear(),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Swap Button
                  IconButton(
                    icon: const Icon(Icons.swap_vert_rounded, color: Color(0xFF4B7B9F), size: 26),
                    tooltip: 'Swap pickup & dropoff',
                    onPressed: _swapLocations,
                  ),
                ],
              ),
            ),

            // Quick Shortcut Actions (Use Current Location, Set on Map)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _useCurrentGpsLocation,
                      icon: const Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF4B7B9F)),
                      label: const Text(
                        'Current location',
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4B7B9F),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCAD4CC)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Open map route directly so user can interactively select point
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MapRouteScreen(
                              pickupName: _pickupController.text.isNotEmpty ? _pickupController.text : 'Mwenge, Dar es Salaam',
                              pickupLatLng: _pickupLatLng,
                              dropoffName: _dropoffController.text.isNotEmpty ? _dropoffController.text : 'Kariakoo Market',
                              dropoffLatLng: _dropoffLatLng ?? const LatLng(-6.8200, 39.2770),
                              initialVehicleIndex: widget.initialVehicleIndex,
                              scheduledFor: widget.scheduledFor,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map_outlined, size: 16, color: Color(0xFF4B7B9F)),
                      label: const Text(
                        'Set on map',
                        style: TextStyle(
                          fontFamily: 'Segoe UI Variable',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4B7B9F),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCAD4CC)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_isSearchingOnline)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: SizedBox(
                  height: 2.5,
                  child: LinearProgressIndicator(
                    backgroundColor: Color(0xFFF2F5F1),
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4B7B9F)),
                  ),
                ),
              ),

            // Content Area: Search Results OR Dynamic Recents (NO HARDCODED PRE-POPULATED LIST!)
            Expanded(
              child: activeText.isNotEmpty
                  ? _buildSearchResultsView()
                  : _buildRecentSearchesView(),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildSearchResultsView() {
    final activeText = _isSelectingPickup ? _pickupController.text.trim() : _dropoffController.text.trim();

    if (_searchResults.isEmpty && !_isSearchingOnline) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF2F5F1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_off_rounded, size: 36, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              const Text(
                'No exact match found',
                style: TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E2822),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'You can deliver anywhere in Tanzania. Tap below to use "$activeText" directly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () {
                  final safeLat = _isValidTzCoord(_pickupLatLng.latitude, _pickupLatLng.longitude)
                      ? _pickupLatLng.latitude
                      : -6.7715;
                  final safeLng = _isValidTzCoord(_pickupLatLng.latitude, _pickupLatLng.longitude)
                      ? _pickupLatLng.longitude
                      : 39.2399;
                  _selectPlace({
                    'title': activeText,
                    'subtitle': '$activeText, Dar es Salaam, Tanzania',
                    'distance': '1.5 km',
                    'lat': safeLat - 0.015,
                    'lng': safeLng + 0.015,
                  });
                },
                icon: const Icon(Icons.pin_drop_rounded, size: 18),
                label: Text(
                  'Set "$activeText" on Map',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4B7B9F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF2F5F1)),
      itemBuilder: (context, index) {
        final place = _searchResults[index];
        final isVerified = place['isVerified'] == true;
        final isGooglePlace = place['isGooglePlace'] == true;
        final isCustom = place['isCustom'] == true;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isGooglePlace
                  ? const Color(0xFFE8F0FE)
                  : (isVerified ? const Color(0xFFE5EEF5) : (isCustom ? const Color(0xFFFEF3C7) : const Color(0xFFF2F5F1))),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isGooglePlace
                  ? Icons.travel_explore_rounded
                  : (isVerified ? Icons.verified_outlined : (isCustom ? Icons.edit_location_alt_rounded : Icons.location_on_outlined)),
              color: isGooglePlace
                  ? const Color(0xFF1A73E8)
                  : (isVerified ? const Color(0xFF4B7B9F) : (isCustom ? const Color(0xFFB45309) : const Color(0xFF4B7B9F))),
              size: 20,
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  place['title'] as String,
                  style: const TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E2822),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isGooglePlace) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'GOOGLE MAPS',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A73E8),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ] else if (isVerified) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5EEF5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'VERIFIED',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF4B7B9F),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            place['subtitle'] as String,
            style: const TextStyle(
              fontFamily: 'Segoe UI Variable',
              fontSize: 12,
              color: Color(0xFF6B7E74),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isGooglePlace ? const Color(0xFFE8F0FE) : const Color(0xFFE5EEF5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              place['distance'] as String? ?? 'Nearby',
              style: TextStyle(
                fontFamily: 'Segoe UI Variable',
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: isGooglePlace ? const Color(0xFF1A73E8) : const Color(0xFF2C4A63),
              ),
            ),
          ),
          onTap: () => _selectPlace(place),
        );
      },
    );
  }

  Widget _buildRecentSearchesView() {
    if (_recentSearches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF2F5F1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search_rounded, size: 36, color: Color(0xFF4B7B9F)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Search Any Location in Tanzania',
                style: TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E2822),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Type a street name, avenue, neighborhood, business, or landmark above to locate your cargo route.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Searches',
                style: TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E2822),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await SessionManager.clearRecentSearches();
                  _loadRecentSearches();
                },
                child: const Text(
                  'Clear',
                  style: TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4B7B9F),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _recentSearches.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF2F5F1)),
            itemBuilder: (context, index) {
              final place = _recentSearches[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F5F1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.history_rounded, color: Color(0xFF4B7B9F), size: 18),
                ),
                title: Text(
                  place['title'] as String,
                  style: const TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E2822),
                  ),
                ),
                subtitle: Text(
                  place['subtitle'] as String,
                  style: const TextStyle(
                    fontFamily: 'Segoe UI Variable',
                    fontSize: 12,
                    color: Color(0xFF6B7E74),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _selectPlace(place),
              );
            },
          ),
        ),
      ],
    );
  }
}
