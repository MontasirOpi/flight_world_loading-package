import 'dart:ui';

/// Represents a country's boundaries and metadata parsed from GeoJSON polygons.
class CountryPolygon {
  /// Country name (e.g. 'United States', 'Bangladesh').
  final String name;

  /// ISO 2-letter or 3-letter code (e.g. 'US', 'BD').
  final String iso;

  /// Minimum latitude bounding box coordinate.
  final double minLat;

  /// Maximum latitude bounding box coordinate.
  final double maxLat;

  /// Minimum longitude bounding box coordinate.
  final double minLng;

  /// Maximum longitude bounding box coordinate.
  final double maxLng;

  /// List of polygon rings where each ring is a list of [Offset(lng, lat)] points.
  final List<List<Offset>> rings;

  const CountryPolygon({
    required this.name,
    required this.iso,
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
    required this.rings,
  });

  /// Bounding box center point as [Offset(longitude, latitude)].
  Offset get center => Offset((minLng + maxLng) / 2.0, (minLat + maxLat) / 2.0);
}
