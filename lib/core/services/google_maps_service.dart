import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class GoogleMapsService {
  // Replace with your Google Maps API Key from Google Cloud Console
  static const String apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  /// Obtains the real hardware GPS location from the customer device
  static Future<Map<String, double>?> getCurrentGpsLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      if (isValidPhilippinesCoordinate(position.latitude, position.longitude)) {
        return {'lat': position.latitude, 'lng': position.longitude};
      }
    } catch (e) {
      debugPrint('Geolocator GPS location error: $e');
    }
    return null;
  }

  /// Validates if coordinates are within Philippines geographical bounds (Lat 4-21, Lng 116-127)
  static bool isValidPhilippinesCoordinate(double lat, double lng) {
    return lat >= 4.0 && lat <= 21.0 && lng >= 116.0 && lng <= 127.0;
  }

  /// Clamps coordinates to valid Philippines defaults if invalid or outside Philippines
  static Map<String, double> sanitizeCoordinates(double lat, double lng) {
    if (isValidPhilippinesCoordinate(lat, lng)) {
      return {'lat': lat, 'lng': lng};
    }
    return {'lat': 14.2818, 'lng': 121.4167}; // Default PRY-ARR Store (Santa Cruz, Laguna)
  }

  /// Resolves a house address string to exact GPS coordinates (Latitude & Longitude)
  static Future<Map<String, dynamic>?> geocodeAddress(String address) async {
    if (address.trim().isEmpty) return null;
    final cleanAddr = address.trim();

    // 1. Try Google Maps Geocoding API if key is configured
    if (apiKey != 'YOUR_GOOGLE_MAPS_API_KEY') {
      try {
        final encodedAddress = Uri.encodeComponent(cleanAddr);
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?address=$encodedAddress&key=$apiKey',
        );
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
            final result = data['results'][0];
            final location = result['geometry']['location'];
            final lat = (location['lat'] as num).toDouble();
            final lng = (location['lng'] as num).toDouble();
            if (isValidPhilippinesCoordinate(lat, lng)) {
              return {
                'lat': lat,
                'lng': lng,
                'formattedAddress': result['formatted_address'] ?? cleanAddr,
              };
            }
          }
        }
      } catch (e) {
        debugPrint('Google Maps Geocoding Error: $e');
      }
    }

    // 2. Fallback to OpenStreetMap Nominatim API for accurate Philippines geocoding
    try {
      final query = Uri.encodeComponent('$cleanAddr, Philippines');
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1');
      final response = await http.get(url, headers: {'User-Agent': 'pry_arr_hardware_app/1.0'});
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat'].toString());
          final lng = double.parse(data[0]['lon'].toString());
          final sanitized = sanitizeCoordinates(lat, lng);
          return {
            'lat': sanitized['lat']!,
            'lng': sanitized['lng']!,
            'formattedAddress': data[0]['display_name'] ?? cleanAddr,
          };
        }
      }
    } catch (e) {
      debugPrint('OSM Nominatim Geocoding Error: $e');
    }

    return {
      'lat': 14.2818,
      'lng': 121.4167,
      'formattedAddress': cleanAddr,
    };
  }

  /// Resolves GPS coordinates (Lat, Lng) to an exact house street address
  static Future<String?> reverseGeocode(double lat, double lng) async {
    final sanitized = sanitizeCoordinates(lat, lng);
    final validLat = sanitized['lat']!;
    final validLng = sanitized['lng']!;

    // 1. Try Google Maps API if key is configured
    if (apiKey != 'YOUR_GOOGLE_MAPS_API_KEY') {
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$validLat,$validLng&key=$apiKey',
        );
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
            return data['results'][0]['formatted_address'];
          }
        }
      } catch (e) {
        debugPrint('Google Maps Reverse Geocode Error: $e');
      }
    }

    // 2. Fallback to OSM Nominatim API
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=$validLat&lon=$validLng&format=json');
      final response = await http.get(url, headers: {'User-Agent': 'pry_arr_hardware_app/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['display_name'] != null) {
          return data['display_name'].toString();
        }
      }
    } catch (e) {
      debugPrint('OSM Nominatim Reverse Geocode Error: $e');
    }

    return 'Metro Manila, Philippines';
  }

  /// Fetches real driving road network route points between origin and destination coordinates
  static Future<List<LatLng>> fetchRoadRoutePoints(double originLat, double originLng, double destLat, double destLng) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$originLng,$originLat;$destLng,$destLat?overview=full&geometries=geojson',
      );
      final response = await http.get(url, headers: {'User-Agent': 'pry_arr_hardware_app/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final List coords = data['routes'][0]['geometry']['coordinates'];
          return coords.map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
        }
      }
    } catch (e) {
      debugPrint('OSRM Road Route API Error: $e');
    }
    // Fallback: direct line points
    return [LatLng(originLat, originLng), LatLng(destLat, destLng)];
  }

  /// Launches the native Google Maps Turn-by-Turn Driving Navigation app (or web fallback)
  static Future<bool> launchNativeGoogleMapsNavigation(double lat, double lng) async {
    final sanitized = sanitizeCoordinates(lat, lng);
    final targetLat = sanitized['lat']!;
    final targetLng = sanitized['lng']!;

    // 1. Try native Google Maps navigation intent scheme
    final nativeUri = Uri.parse('google.navigation:q=$targetLat,$targetLng&mode=d');
    try {
      if (await canLaunchUrl(nativeUri)) {
        return await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    // 2. Universal Google Maps web / app navigation URL
    final universalUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$targetLat,$targetLng&travelmode=driving');
    try {
      return await launchUrl(universalUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching Google Maps Navigation: $e');
    }
    return false;
  }

  /// Generates a Google Maps Static Map image URL with a red house marker at the exact customer pinned location
  static String getStaticMapUrl(
    double lat,
    double lng, {
    int zoom = 17,
    int width = 600,
    int height = 350,
    String mapType = 'roadmap',
  }) {
    final sanitized = sanitizeCoordinates(lat, lng);
    final marker = Uri.encodeComponent('color:red|label:H|${sanitized['lat']},${sanitized['lng']}');
    return 'https://maps.googleapis.com/maps/api/staticmap?center=${sanitized['lat']},${sanitized['lng']}&zoom=$zoom&size=${width}x$height&maptype=$mapType&markers=$marker&key=$apiKey';
  }

  /// Builds the Google Maps Turn-by-Turn Driving Navigation URL to the customer house pin
  static String getNavigationUrl(double lat, double lng) {
    final sanitized = sanitizeCoordinates(lat, lng);
    return 'https://www.google.com/maps/dir/?api=1&destination=${sanitized['lat']},${sanitized['lng']}&travelmode=driving';
  }

  /// Builds the Google Maps Web Embed URL for viewing exact customer house location
  static String getEmbedUrl(double lat, double lng) {
    final sanitized = sanitizeCoordinates(lat, lng);
    return 'https://www.google.com/maps/embed/v1/place?key=$apiKey&q=${sanitized['lat']},${sanitized['lng']}&zoom=17';
  }
}
