import 'dart:math' as math;
import 'dart:ui';

/// Helper for Web Mercator map projection, dynamic distance-based viewport calculation,
/// and quadratic Bezier flight trajectory arcs.
class MapProjectionHelper {
  /// Converts geographic (latitude, longitude) coordinates in degrees to normalized
  /// Web Mercator Cartesian space [0.0..1.0, 0.0..1.0].
  static Offset projectToMercator(double lat, double lng) {
    // Clamp latitude to standard Web Mercator limits (-85.05112878 to 85.05112878)
    final clampedLat = lat.clamp(-85.05112878, 85.05112878);
    final clampedLng = lng.clamp(-180.0, 180.0);

    final double x = (clampedLng + 180.0) / 360.0;
    final double radLat = clampedLat * math.pi / 180.0;
    final double sinLat = math.sin(radLat);
    final double y = 0.5 - math.log((1.0 + sinLat) / (1.0 - sinLat)) / (4.0 * math.pi);

    return Offset(x, y.clamp(0.0, 1.0));
  }

  /// Calculates a viewport scale and offset to fit two points on the canvas
  /// with dynamic adaptive zoom.
  static ({
    double scale,
    Offset centerNorm,
    Offset Function(Offset norm) toScreen,
  }) calculateViewport({
    required Size canvasSize,
    required Offset p1Norm,
    required Offset p2Norm,
    double paddingRatio = 0.35,
    double? minSpan,
    double verticalOffset = 14.0,
  }) {
    return calculateViewportForPoints(
      canvasSize: canvasSize,
      pointsNorm: [p1Norm, p2Norm],
      paddingRatio: paddingRatio,
      minSpan: minSpan,
      verticalOffset: verticalOffset,
    );
  }

  /// Calculates a viewport scale and offset to fit multiple normalized points
  /// (e.g. multi-city or round-trip stops) on the canvas with dynamic adaptive zoom.
  static ({
    double scale,
    Offset centerNorm,
    Offset Function(Offset norm) toScreen,
  }) calculateViewportForPoints({
    required Size canvasSize,
    required List<Offset> pointsNorm,
    double paddingRatio = 0.35,
    double? minSpan,
    double verticalOffset = 14.0,
  }) {
    if (pointsNorm.isEmpty) {
      final defaultCenter = const Offset(0.5, 0.5);
      return (
        scale: canvasSize.width,
        centerNorm: defaultCenter,
        toScreen: (norm) => Offset(
          (norm.dx - defaultCenter.dx) * canvasSize.width + canvasSize.width / 2.0,
          (norm.dy - defaultCenter.dy) * canvasSize.width + canvasSize.height / 2.0 + verticalOffset,
        ),
      );
    }

    if (pointsNorm.length == 1) {
      final singlePoint = pointsNorm.first;
      const adaptiveMinSpan = 0.035;
      final scale = canvasSize.width / adaptiveMinSpan;
      return (
        scale: scale,
        centerNorm: singlePoint,
        toScreen: (norm) => Offset(
          (norm.dx - singlePoint.dx) * scale + canvasSize.width / 2.0,
          (norm.dy - singlePoint.dy) * scale + canvasSize.height / 2.0 + verticalOffset,
        ),
      );
    }

    double minX = pointsNorm.first.dx;
    double maxX = pointsNorm.first.dx;
    double minY = pointsNorm.first.dy;
    double maxY = pointsNorm.first.dy;

    for (int i = 1; i < pointsNorm.length; i++) {
      final p = pointsNorm[i];
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    final double midX = (minX + maxX) / 2.0;
    final double midY = (minY + maxY) / 2.0;
    final Offset centerNorm = Offset(midX, midY);

    final double dx = maxX - minX;
    final double dy = maxY - minY;
    final double normDistance = math.sqrt(dx * dx + dy * dy);

    // Adaptive minimum span: enables high zoom for short/domestic flights
    // without exceeding vector boundary fidelity limits.
    double adaptiveMinSpan;
    if (normDistance < 0.005) {
      adaptiveMinSpan = 0.016; // ~5.7 deg: close domestic/regional
    } else if (normDistance < 0.025) {
      adaptiveMinSpan = 0.016 + (normDistance / 0.025) * (0.032 - 0.016);
    } else if (normDistance < 0.08) {
      adaptiveMinSpan = 0.032 + ((normDistance - 0.025) / 0.055) * (0.065 - 0.032);
    } else {
      adaptiveMinSpan = 0.070; // Continental / global
    }

    if (minSpan != null) {
      adaptiveMinSpan = math.max(adaptiveMinSpan, minSpan);
    }

    // Short-haul routes receive extra breathing room for floating cards and arched trajectories
    final double effectivePadding = (normDistance < 0.04) ? 0.48 : paddingRatio;

    double spanX = dx * (1.0 + effectivePadding * 2);
    double spanY = dy * (1.0 + effectivePadding * 2);

    spanX = math.max(spanX, adaptiveMinSpan);
    // Vertical headroom for upward flight arc and top/bottom IATA cards
    spanY = math.max(spanY, adaptiveMinSpan * 1.15);

    // Maintain aspect ratio with canvas
    final double scaleX = canvasSize.width / spanX;
    final double scaleY = canvasSize.height / spanY;
    double scale = math.min(scaleX, scaleY);

    // Clamp zoom scale to safe visual limits
    final double maxScale = canvasSize.width / 0.015;
    final double minScale = canvasSize.width / 0.98;
    scale = scale.clamp(minScale, maxScale);

    Offset toScreen(Offset norm) {
      final double screenX = (norm.dx - centerNorm.dx) * scale + canvasSize.width / 2.0;
      final double screenY = (norm.dy - centerNorm.dy) * scale + canvasSize.height / 2.0 + verticalOffset;
      return Offset(screenX, screenY);
    }

    return (
      scale: scale,
      centerNorm: centerNorm,
      toScreen: toScreen,
    );
  }

  /// Generates a quadratic Bezier path arched between start and end screen points.
  /// If [invertCurvature] is true, the arc curves in the opposite direction (useful for return legs).
  static Path createFlightArcPath({
    required Offset start,
    required Offset end,
    double curveRatio = 0.22,
    bool invertCurvature = false,
  }) {
    final Path path = Path();
    path.moveTo(start.dx, start.dy);

    final Offset delta = end - start;
    final double distance = delta.distance;

    if (distance < 1.0) {
      path.lineTo(end.dx, end.dy);
      return path;
    }

    final Offset mid = Offset((start.dx + end.dx) / 2.0, (start.dy + end.dy) / 2.0);

    // Normal vector perpendicular to the chord
    Offset normal = Offset(-delta.dy, delta.dx) / distance;

    // Standard upward pointing: negative Y in canvas coordinates
    if (normal.dy > 0 || (normal.dy == 0 && normal.dx > 0)) {
      normal = -normal;
    }

    if (invertCurvature) {
      normal = -normal;
    }

    // Dynamic bow height: clamped to stay visually balanced across all distances
    final double bowHeight = (distance * curveRatio).clamp(18.0, 56.0);
    final Offset verticalShift = invertCurvature ? const Offset(0, 4.0) : const Offset(0, -4.0);
    final Offset controlPoint = mid + normal * bowHeight + verticalShift;

    path.quadraticBezierTo(controlPoint.dx, controlPoint.dy, end.dx, end.dy);
    return path;
  }
}
