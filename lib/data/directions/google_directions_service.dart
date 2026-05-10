import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:t_rider_services_app/config/maps_config.dart';

/// Decoded driving route plus optional leg totals from Google Directions.
class DrivingRouteSummary {
  const DrivingRouteSummary({
    required this.points,
    required this.durationSeconds,
    required this.distanceMeters,
  });

  final List<LatLng> points;

  /// Total driving time (sum of legs), seconds.
  final int durationSeconds;

  /// Total distance (sum of legs), meters.
  final int distanceMeters;

  Duration get duration => Duration(seconds: durationSeconds);
}

/// Fetches a driving route between two points using the Google Directions API.
class GoogleDirectionsService {
  GoogleDirectionsService._();

  static const _timeout = Duration(seconds: 20);

  /// Roads-accurate route with overview polyline and leg totals (sum of legs).
  static Future<DrivingRouteSummary?> fetchDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final key = MapsConfig.googleMapsApiKey.trim();
    if (key.isEmpty) {
      debugPrint(
        '[GoogleDirectionsService] Missing API key. Set GOOGLE_MAPS_API_KEY '
        'or MapsConfig.googleMapsApiKey.',
      );
      return null;
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      <String, String>{
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': 'driving',
        'key': key,
      },
    );

    try {
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode != 200) {
        debugPrint(
          '[GoogleDirectionsService] HTTP ${res.statusCode} for directions '
          '(origin → destination). Body (truncated): '
          '${_truncate(res.body, 400)}',
        );
        return null;
      }

      final data = jsonDecode(res.body);
      if (data is! Map<String, dynamic>) {
        debugPrint(
          '[GoogleDirectionsService] Response JSON was not an object.',
        );
        return null;
      }

      final apiStatus = data['status']?.toString() ?? 'unknown';
      if (data['status'] != 'OK') {
        final err = data['error_message']?.toString();
        debugPrint(
          '[GoogleDirectionsService] Directions API status: $apiStatus'
          '${err != null ? ' — $err' : ''}',
        );
        return null;
      }

      final routes = data['routes'];
      if (routes is! List || routes.isEmpty) {
        debugPrint(
          '[GoogleDirectionsService] status OK but no routes in response.',
        );
        return null;
      }

      final first = routes.first;
      if (first is! Map<String, dynamic>) {
        debugPrint(
          '[GoogleDirectionsService] First route entry has invalid shape.',
        );
        return null;
      }

      final overview = first['overview_polyline'];
      if (overview is! Map<String, dynamic>) {
        debugPrint(
          '[GoogleDirectionsService] Missing overview_polyline on route.',
        );
        return null;
      }

      final encoded = overview['points'];
      if (encoded is! String || encoded.isEmpty) {
        debugPrint(
          '[GoogleDirectionsService] overview_polyline.points missing or empty.',
        );
        return null;
      }

      final pts = _decodeEncodedPolyline(encoded);

      var durationSec = 0;
      var distanceM = 0;
      final legs = first['legs'];
      if (legs is List) {
        for (final leg in legs) {
          if (leg is! Map<String, dynamic>) continue;
          final d = leg['duration'];
          if (d is Map && d['value'] is num) {
            durationSec += (d['value'] as num).round();
          }
          final dist = leg['distance'];
          if (dist is Map && dist['value'] is num) {
            distanceM += (dist['value'] as num).round();
          }
        }
      }

      return DrivingRouteSummary(
        points: pts,
        durationSeconds: durationSec <= 0 ? 1 : durationSec,
        distanceMeters: distanceM <= 0 ? 1 : distanceM,
      );
    } on TimeoutException catch (e, st) {
      debugPrint('[GoogleDirectionsService] Request timed out: $e\n$st');
      return null;
    } catch (e, st) {
      debugPrint(
        '[GoogleDirectionsService] Error fetching route: $e\n$st',
      );
      return null;
    }
  }

  /// Returns decoded points only (same Roads API pipeline as [fetchDrivingRoute]).
  static Future<List<LatLng>?> fetchDrivingPolyline({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final r = await fetchDrivingRoute(origin: origin, destination: destination);
    return r?.points;
  }

  static String _truncate(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}…';
  }

  /// Google Encoded Polyline Algorithm Format.
  static List<LatLng> _decodeEncodedPolyline(String encoded) {
    final poly = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      poly.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return poly;
  }
}
