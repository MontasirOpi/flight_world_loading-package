import 'dart:ui';

/// Precomputed geometry and path metric for a single flight leg.
class FlightLegPath {
  /// Screen position of departure airport pin.
  final Offset startPoint;

  /// Screen position of arrival airport pin.
  final Offset endPoint;

  /// Curved Bezier arc connecting start to end.
  final Path arcPath;

  /// PathMetric derived from [arcPath] for tangent-aligned airplane placement.
  final PathMetric arcMetric;

  /// Whether this leg is a return leg (e.g. for round-trip return flight).
  final bool isReturn;

  /// Zero-based index of this flight leg in the itinerary.
  final int legIndex;

  const FlightLegPath({
    required this.startPoint,
    required this.endPoint,
    required this.arcPath,
    required this.arcMetric,
    this.isReturn = false,
    this.legIndex = 0,
  });
}

/// Precomputed geometry, paths, and positions cached for 60fps canvas rendering.
class MapPrecomputedPaths {
  /// The canvas size for which these paths were calculated.
  final Size size;

  /// Combined path for filling all country landmasses.
  final Path countriesFillPath;

  /// Combined path for stroking country borders.
  final Path countriesStrokePath;

  /// Primary or combined upward-arched flight path (maintained for backwards compatibility).
  final Path flightArcPath;

  /// Primary PathMetric (maintained for backwards compatibility).
  final PathMetric arcMetric;

  /// Screen position of primary origin airport pin.
  final Offset startPoint;

  /// Screen position of primary destination airport pin.
  final Offset endPoint;

  /// Filtered list of visible country names and their center screen positions.
  final List<({String name, Offset position})> visibleLabels;

  /// All individual flight leg paths in this itinerary.
  final List<FlightLegPath> legs;

  /// Screen positions of all unique airport stops in the route.
  final List<Offset> stopScreenPositions;

  const MapPrecomputedPaths({
    required this.size,
    required this.countriesFillPath,
    required this.countriesStrokePath,
    required this.flightArcPath,
    required this.arcMetric,
    required this.startPoint,
    required this.endPoint,
    required this.visibleLabels,
    this.legs = const [],
    this.stopScreenPositions = const [],
  });
}
