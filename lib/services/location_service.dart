import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// A place on the map: the party venue, or where to search for providers.
class Place {
  const Place({required this.label, required this.lat, required this.lng, this.address = '', this.countryCode = ''});

  /// Short name for chips and headers, e.g. "Edison, NJ".
  final String label;

  /// Fuller address when the user typed one, e.g. "123 Oak Tree Rd, Edison, NJ".
  final String address;
  final double lat;
  final double lng;

  /// "us", "in", ... (used to pick °F or °C).
  final String countryCode;

  bool get usesFahrenheit => countryCode.isEmpty || const {'us', 'bs', 'bz', 'ky', 'pw', 'lr'}.contains(countryCode);

  Map<String, dynamic> toMap() => {'label': label, 'address': address, 'lat': lat, 'lng': lng, 'countryCode': countryCode};

  static Place? fromMap(Object? m) {
    if (m is! Map) return null;
    final lat = (m['lat'] as num?)?.toDouble();
    final lng = (m['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return Place(
      label: m['label'] as String? ?? '',
      address: m['address'] as String? ?? '',
      lat: lat,
      lng: lng,
      countryCode: m['countryCode'] as String? ?? '',
    );
  }
}

/// Miles between two points (great-circle distance).
double milesBetween(double lat1, double lng1, double lat2, double lng2) {
  const r = 3958.8;
  double rad(double d) => d * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) + cos(rad(lat1)) * cos(rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

String distanceLabel(double miles) => miles < 10 ? '${miles.toStringAsFixed(1)} mi' : '${miles.round()} mi';

/// "Edison, NJ" from an OpenStreetMap (Nominatim) address block.
String shortLabel(Map<String, dynamic> address, {String fallback = ''}) {
  final town = address['city'] ?? address['town'] ?? address['village'] ?? address['suburb'] ?? address['hamlet'] ?? address['county'];
  final iso = address['ISO3166-2-lvl4'] as String?; // e.g. "US-NJ"
  final region = (iso != null && iso.contains('-')) ? iso.split('-').last : (address['state'] as String? ?? '');
  final parts = [if (town != null) '$town', if (region.isNotEmpty) region];
  return parts.isEmpty ? fallback : parts.join(', ');
}

/// Current location and address search. Uses the phone's/browser's location and
/// OpenStreetMap's free Nominatim service for addresses (no API key).
class LocationService {
  LocationService._();

  static const _nominatim = 'nominatim.openstreetmap.org';
  static Map<String, String> get _headers => kIsWeb ? const {} : const {'User-Agent': 'Hoopla/1.0 (northbitapps@gmail.com)'};

  /// Asks for permission if needed. Throws a friendly message when it can't.
  static Future<Place> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Location is turned off. Turn it on, or type an address instead.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw StateError('Hoopla can\'t see your location. Allow it in Settings, or type an address instead.');
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 15)),
    );
    return reverse(pos.latitude, pos.longitude);
  }

  /// The current location only when permission was already given (never shows a prompt).
  static Future<Place?> currentIfAllowed() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.always && perm != LocationPermission.whileInUse) return null;
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      return await current();
    } catch (_) {
      return null;
    }
  }

  /// A place name for coordinates. Falls back to "Current location".
  static Future<Place> reverse(double lat, double lng) async {
    try {
      final res = await http
          .get(Uri.https(_nominatim, '/reverse', {'format': 'jsonv2', 'lat': '$lat', 'lon': '$lng', 'zoom': '14', 'addressdetails': '1'}),
              headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final address = Map<String, dynamic>.from(data['address'] as Map? ?? {});
        return Place(
          label: shortLabel(address, fallback: 'Current location'),
          lat: lat,
          lng: lng,
          countryCode: '${address['country_code'] ?? ''}',
        );
      }
    } catch (e) {
      debugPrint('Reverse geocode failed: $e');
    }
    return Place(label: 'Current location', lat: lat, lng: lng);
  }

  /// Up to 5 matches for a typed address, venue or city.
  static Future<List<Place>> search(String query) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    final res = await http
        .get(Uri.https(_nominatim, '/search', {'format': 'jsonv2', 'q': q, 'limit': '5', 'addressdetails': '1'}), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw StateError('Address search is busy. Try again in a moment.');
    final list = jsonDecode(res.body) as List;
    return [
      for (final m in list.cast<Map<String, dynamic>>())
        Place(
          label: shortLabel(Map<String, dynamic>.from(m['address'] as Map? ?? {}), fallback: '${m['name'] ?? q}'),
          address: _shortAddress('${m['display_name'] ?? q}'),
          lat: double.parse('${m['lat']}'),
          lng: double.parse('${m['lon']}'),
          countryCode: '${(m['address'] as Map?)?['country_code'] ?? ''}',
        ),
    ];
  }

  /// "123, Oak Tree Road, Edison, Middlesex County, New Jersey, 08820, United States"
  /// → "123, Oak Tree Road, Edison, Middlesex County"
  static String _shortAddress(String full) {
    final parts = full.split(', ');
    return parts.length <= 4 ? full : parts.take(4).join(', ');
  }
}
