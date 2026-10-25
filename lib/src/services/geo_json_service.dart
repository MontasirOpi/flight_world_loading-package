import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/country_polygon.dart';

/// High-performance service for loading and parsing offline world vector GeoJSON.
class GeoJsonService {
  static List<CountryPolygon>? _cachedCountries;

  /// Loads the Natural Earth GeoJSON dataset, parsing it in a background isolate
  /// and caching the result in memory for instant reuse across widget rebuilds.
  static Future<List<CountryPolygon>> loadCountries({
    String? customAssetPath,
  }) async {
    if (_cachedCountries != null && _cachedCountries!.isNotEmpty) {
      return _cachedCountries!;
    }

    String? jsonString;
    final List<String> pathsToTry = [
      if (customAssetPath != null) customAssetPath,
      'packages/flight_world_loading/assets/geo/countries.json',
      'assets/geo/countries.json',
    ];

    for (final path in pathsToTry) {
      try {
        jsonString = await rootBundle.loadString(path);
        if (jsonString.isNotEmpty) break;
      } catch (_) {
        // Continue trying next candidate path
      }
    }

    if (jsonString == null || jsonString.isEmpty) {
      debugPrint('GeoJsonService: Warning - Could not load countries.json asset.');
      return [];
    }

    try {
      final result = await compute(_parseGeoJsonIsolate, jsonString);
      _cachedCountries = result;
      return result;
    } catch (e) {
      debugPrint('GeoJsonService: Error parsing countries: $e');
      return [];
    }
  }

  /// Manually set pre-parsed country polygons (e.g., during tests).
  @visibleForTesting
  static void setCountries(List<CountryPolygon> countries) {
    _cachedCountries = countries;
  }

  /// Clears in-memory cache.
  @visibleForTesting
  static void clearCache() {
    _cachedCountries = null;
  }

  /// Returns the bounding box centroid (latitude, longitude) for a country by ISO code or name.
  static (double, double)? getCountryCentroid(String query) {
    if (_cachedCountries == null || _cachedCountries!.isEmpty) return null;
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return null;

    for (final c in _cachedCountries!) {
      if (c.iso.toLowerCase() == clean || c.name.toLowerCase() == clean) {
        return (c.center.dy, c.center.dx);
      }
    }
    for (final c in _cachedCountries!) {
      if (c.name.toLowerCase().contains(clean)) {
        return (c.center.dy, c.center.dx);
      }
    }
    return null;
  }

  /// Top-level or static isolate function for non-blocking JSON decoding.
  static List<CountryPolygon> _parseGeoJsonIsolate(String jsonString) {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    final List<dynamic> features = data['features'] ?? [];
    final List<CountryPolygon> countries = [];

    for (final feature in features) {
      final props = feature['properties'] as Map<String, dynamic>? ?? {};
      final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
      final String name = (props['name'] ?? '').toString();
      final String iso = (props['iso'] ?? '').toString();
      final String geomType = (geometry['type'] ?? '').toString();
      final coordinates = geometry['coordinates'];

      if (coordinates == null) continue;

      final List<List<Offset>> rings = [];
      double minLat = 90.0, maxLat = -90.0;
      double minLng = 180.0, maxLng = -180.0;

      void processRing(List<dynamic> ring) {
        final List<Offset> points = [];
        for (final pt in ring) {
          if (pt is List && pt.length >= 2) {
            final double lng = (pt[0] as num).toDouble();
            final double lat = (pt[1] as num).toDouble();
            points.add(Offset(lng, lat));

            if (lat < minLat) minLat = lat;
            if (lat > maxLat) maxLat = lat;
            if (lng < minLng) minLng = lng;
            if (lng > maxLng) maxLng = lng;
          }
        }
        if (points.isNotEmpty) {
          rings.add(points);
        }
      }

      if (geomType == 'Polygon') {
        for (final ring in coordinates) {
          if (ring is List) processRing(ring);
        }
      } else if (geomType == 'MultiPolygon') {
        for (final poly in coordinates) {
          if (poly is List) {
            for (final ring in poly) {
              if (ring is List) processRing(ring);
            }
          }
        }
      }

      if (rings.isNotEmpty) {
        countries.add(CountryPolygon(
          name: name,
          iso: iso,
          minLat: minLat,
          maxLat: maxLat,
          minLng: minLng,
          maxLng: maxLng,
          rings: rings,
        ));
      }
    }

    return countries;
  }
}
