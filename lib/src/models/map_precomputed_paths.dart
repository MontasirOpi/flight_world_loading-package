import 'dart:ui';

/// Precomputed geometry, paths, and positions cached for 60fps canvas rendering.
class MapPrecomputedPaths {
  /// The canvas size for which these paths were calculated.
  final Size size;

  /// Combined path for filling all country landmasses.
  final Path countriesFillPath;

  /// Combined path for stroking country borders.
  final Path countriesStrokePath;

  /// Upward-arched quadratic Bezier curve connecting origin to destination.
  final Path flightArcPath;

  /// PathMetric derived from [flightArcPath] for efficient tangent/airplane calculation.
  final PathMetric arcMetric;

  /// Screen position of origin airport pin.
  final Offset startPoint;

  /// Screen position of destination airport pin.
  final Offset endPoint;

  /// Filtered list of visible country names and their center screen positions.
  final List<({String name, Offset position})> visibleLabels;

  const MapPrecomputedPaths({
    required this.size,
    required this.countriesFillPath,
    required this.countriesStrokePath,
    required this.flightArcPath,
    required this.arcMetric,
    required this.startPoint,
    required this.endPoint,
    required this.visibleLabels,
  });
}
