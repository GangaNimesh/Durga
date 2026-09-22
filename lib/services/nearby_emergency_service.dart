import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class NearbyPlace {
  final String name;
  final String type; // 'police' or 'hospital'
  final double latitude;
  final double longitude;
  final double distanceKm;

  const NearbyPlace({
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
  });

  String get formattedDistance => '${distanceKm.toStringAsFixed(1)} km';
}

class NearbyEmergencyService {
  NearbyEmergencyService._();
  static final NearbyEmergencyService instance = NearbyEmergencyService._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
      headers: {
        'User-Agent': 'DurgaSafetyApp/1.0',
      },
    ),
  );

  Position? _cachedPosition;
  NearbyPlace? _cachedPolice;
  NearbyPlace? _cachedHospital;
  DateTime? _lastFetchTime;

  NearbyPlace? get cachedPolice => _cachedPolice;
  NearbyPlace? get cachedHospital => _cachedHospital;
  Position? get cachedPosition => _cachedPosition;

  /// Fetch or check current GPS position
  Future<Position?> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[NearbyEmergencyService] Location services disabled on device.');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[NearbyEmergencyService] Location permission denied.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[NearbyEmergencyService] Location permission permanently denied.');
        return null;
      }

      // Check last known position first so we have an instant reference point
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _cachedPosition = lastKnown;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 6),
      );

      _cachedPosition = pos;
      debugPrint('[NearbyEmergencyService] Current GPS location: ${pos.latitude}, ${pos.longitude}');
      return pos;
    } catch (e) {
      debugPrint('[NearbyEmergencyService] Error fetching GPS position: $e');
      return _cachedPosition;
    }
  }

  /// Fetch both nearest police station and hospital
  Future<Map<String, NearbyPlace?>> fetchNearestHelp({bool forceRefresh = false}) async {
    // Return cache if fetched within 3 minutes and valid (< 25km)
    if (!forceRefresh &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!).inMinutes < 3 &&
        _cachedPolice != null &&
        _cachedPolice!.distanceKm < 25 &&
        _cachedHospital != null &&
        _cachedHospital!.distanceKm < 25) {
      return {
        'police': _cachedPolice,
        'hospital': _cachedHospital,
      };
    }

    final pos = await getCurrentPosition();
    if (pos == null) {
      debugPrint('[NearbyEmergencyService] Could not get GPS location for facility search.');
      return {
        'police': _cachedPolice,
        'hospital': _cachedHospital,
      };
    }

    // Run searches in parallel
    final results = await Future.wait([
      _findNearestFacility(pos, 'police'),
      _findNearestFacility(pos, 'hospital'),
    ]);

    _cachedPolice = results[0];
    _cachedHospital = results[1];
    _lastFetchTime = DateTime.now();

    debugPrint('[NearbyEmergencyService] Nearest Police: ${_cachedPolice?.name} (${_cachedPolice?.formattedDistance})');
    debugPrint('[NearbyEmergencyService] Nearest Hospital: ${_cachedHospital?.name} (${_cachedHospital?.formattedDistance})');

    return {
      'police': _cachedPolice,
      'hospital': _cachedHospital,
    };
  }

  /// Searches for nearest facility using verified fast Overpass mirrors within a local radius
  Future<NearbyPlace?> _findNearestFacility(Position pos, String amenityType) async {
    final lat = pos.latitude;
    final lon = pos.longitude;
    final radius = amenityType == 'police' ? 7000 : 6000; // Search within 6-7km
    final query = '[out:json][timeout:8];(nwr["amenity"="$amenityType"](around:$radius,$lat,$lon););out center 8;';

    final endpoints = [
      'https://overpass.kumi.systems/api/interpreter',
      'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await _dio.post(
          endpoint,
          data: 'data=${Uri.encodeQueryComponent(query)}',
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            headers: {'User-Agent': 'DurgaSafetyApp/1.0'},
            sendTimeout: const Duration(seconds: 6),
            receiveTimeout: const Duration(seconds: 6),
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final elements = response.data['elements'] as List<dynamic>?;
          if (elements != null && elements.isNotEmpty) {
            NearbyPlace? closest;
            double minDistance = double.infinity;

            for (final el in elements) {
              double? elLat;
              double? elLon;

              if (el['lat'] != null && el['lon'] != null) {
                elLat = (el['lat'] as num).toDouble();
                elLon = (el['lon'] as num).toDouble();
              } else if (el['center'] != null) {
                elLat = (el['center']['lat'] as num?)?.toDouble();
                elLon = (el['center']['lon'] as num?)?.toDouble();
              }

              if (elLat == null || elLon == null) continue;

              final distanceMeters = Geolocator.distanceBetween(lat, lon, elLat, elLon);
              final distanceKm = distanceMeters / 1000.0;

              // Enforce strictly local distance: must be within 20 km
              if (distanceKm < minDistance && distanceKm <= 20.0) {
                minDistance = distanceKm;
                final tags = el['tags'] as Map<String, dynamic>?;
                String name = tags?['name'] ?? tags?['name:en'] ?? (amenityType == 'police' ? 'Police Station' : 'Hospital');

                closest = NearbyPlace(
                  name: name,
                  type: amenityType,
                  latitude: elLat,
                  longitude: elLon,
                  distanceKm: distanceKm,
                );
              }
            }

            if (closest != null) return closest;
          }
        }
      } catch (e) {
        debugPrint('[NearbyEmergencyService] $endpoint error for $amenityType: $e');
      }
    }

    return null;
  }

  /// Launch Google Maps directly in turn-by-turn DIRECTIONS mode from current location
  Future<void> openInGoogleMaps({
    required String type, // 'police' or 'hospital'
    NearbyPlace? place,
    Position? userPosition,
  }) async {
    // If we have verified local coordinates, navigate to exact point
    String destination;
    if (place != null && place.distanceKm <= 20) {
      destination = '${place.latitude},${place.longitude}';
    } else {
      // Use clean destination keyword for Google Maps directions
      destination = type == 'police' ? 'nearest+police+station' : 'nearest+hospital';
    }

    debugPrint('[NearbyEmergencyService] Opening navigation to $destination');

    // 1. First attempt: Launch Google Maps native Turn-by-Turn Navigation Intent on Android
    final navUri = Uri.parse('google.navigation:q=$destination&mode=d');
    try {
      if (await canLaunchUrl(navUri)) {
        await launchUrl(navUri);
        return;
      }
    } catch (e) {
      debugPrint('[NearbyEmergencyService] Native navigation intent failed: $e');
    }

    // 2. Second attempt: Direct Google Maps Directions Mode URL
    // Omitting 'origin' automatically locks to the device's real-time live GPS location
    final directionsUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destination&travelmode=driving',
    );

    try {
      final launched = await launchUrl(directionsUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(directionsUri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('[NearbyEmergencyService] Could not launch directions URL: $e');
    }
  }
}
