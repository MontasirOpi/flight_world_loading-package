import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/airport.dart';

/// Service for registering, caching, and searching airport datasets
/// without blocking the UI thread.
class AirportService {
  static final List<Airport> _allAirports = [];
  static final Map<String, Airport> _airportMap = {};
  static bool _isLoading = false;

  static bool get isLoading => _isLoading;
  static int get count => _allAirports.length;
  static List<Airport> get allAirports => List.unmodifiable(_allAirports);

  /// Registers a single [Airport] into the in-memory lookup cache.
  static void registerAirport(Airport airport) {
    final cleanCode = airport.code.trim().toUpperCase();
    if (cleanCode.isEmpty) return;
    _airportMap[cleanCode] = airport;
    final existingIdx = _allAirports.indexWhere((a) => a.code == cleanCode);
    if (existingIdx >= 0) {
      _allAirports[existingIdx] = airport;
    } else {
      _allAirports.add(airport);
    }
  }

  /// Bulk registers a collection of [Airport]s into the in-memory lookup cache.
  static void registerAirports(Iterable<Airport> airports) {
    for (final airport in airports) {
      registerAirport(airport);
    }
  }

  /// Retrieves an [Airport] by its 3-letter IATA or ICAO code.
  static Airport? getAirportByCode(String code) {
    final cleanCode = code.trim().toUpperCase();
    return _airportMap[cleanCode];
  }

  /// Clears all dynamically registered airports.
  static void clear() {
    _allAirports.clear();
    _airportMap.clear();
  }

  /// Loads airports from a JSON string in a background isolate.
  static Future<int> loadFromJsonString(String jsonString) async {
    _isLoading = true;
    try {
      final airports = await compute(_parseAirportsIsolate, jsonString);
      registerAirports(airports);
      return airports.length;
    } finally {
      _isLoading = false;
    }
  }

  /// Loads airports from an asset bundle path.
  static Future<int> loadFromAsset(String assetPath) async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      return await loadFromJsonString(jsonString);
    } catch (e) {
      debugPrint('AirportService: Error loading airports from $assetPath: $e');
      return 0;
    }
  }

  /// Searches loaded airports by code, city, name, or country.
  static List<Airport> search(String query, {int limit = 20}) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return [];

    final List<Airport> results = [];
    for (final airport in _allAirports) {
      if (airport.code.toLowerCase().startsWith(clean) ||
          airport.city.toLowerCase().startsWith(clean) ||
          airport.name.toLowerCase().contains(clean) ||
          airport.country.toLowerCase().contains(clean)) {
        results.add(airport);
        if (results.length >= limit) break;
      }
    }
    return results;
  }

  static List<Airport> _parseAirportsIsolate(String jsonString) {
    final dynamic decoded = jsonDecode(jsonString);
    final List<Airport> list = [];

    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          list.add(Airport.fromJson(item));
        } else if (item is Map) {
          list.add(Airport.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    } else if (decoded is Map<String, dynamic>) {
      final airportsList = decoded['airports'] ?? decoded['data'];
      if (airportsList is List) {
        for (final item in airportsList) {
          if (item is Map<String, dynamic>) {
            list.add(Airport.fromJson(item));
          } else if (item is Map) {
            list.add(Airport.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
    }

    return list;
  }
}
