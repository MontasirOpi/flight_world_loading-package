import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

import '../models/flight_route_stop.dart';
import '../models/flight_trip_type.dart';
import '../models/map_precomputed_paths.dart';

/// A high-performance 60fps [CustomPainter] that renders the vector world map,
/// country landmasses, collision-safe airport cards, and tangent-aligned flight trajectory.
/// Supports one-way, round-trip, and multi-city itineraries.
class FlightMapPainter extends CustomPainter {
  /// Precomputed geometry paths and positions for the current canvas size.
  final MapPrecomputedPaths? precomputed;

  /// Normalized animation progress value from 0.0 to 1.0.
  final double animationProgress;

  /// Origin 3-letter IATA code.
  final String fromCode;

  /// Origin city name.
  final String fromCity;

  /// Destination 3-letter IATA code.
  final String toCode;

  /// Destination city name.
  final String toCity;

  /// All route stops in the itinerary.
  final List<FlightRouteStop> stops;

  /// Trip type mode: one-way, round-trip, or multi-city.
  final FlightTripType tripType;

  /// Primary theme color for the flight path, plane, and airport pins.
  final Color brandColor;

  /// Whether the painter should render in dark mode palette.
  final bool isDarkMode;

  /// Optional water background color override.
  final Color? waterColor;

  /// Optional landmass fill color override.
  final Color? landColor;

  /// Optional landmass border color override.
  final Color? borderColor;

  /// Optional card background color override.
  final Color? cardBackgroundColor;

  /// Optional card border stroke color override.
  final Color? cardBorderColor;

  /// Optional text style for IATA codes.
  final TextStyle? codeStyle;

  /// Optional text style for city names.
  final TextStyle? cityStyle;

  /// Optional text style for country labels.
  final TextStyle? labelStyle;

  FlightMapPainter({
    required this.precomputed,
    required this.animationProgress,
    required this.fromCode,
    required this.fromCity,
    required this.toCode,
    required this.toCity,
    List<FlightRouteStop>? stops,
    this.tripType = FlightTripType.oneWay,
    this.brandColor = const Color(0xFF1F4A3F),
    this.isDarkMode = false,
    this.waterColor,
    this.landColor,
    this.borderColor,
    this.cardBackgroundColor,
    this.cardBorderColor,
    this.codeStyle,
    this.cityStyle,
    this.labelStyle,
  }) : stops = stops ??
            [
              FlightRouteStop(code: fromCode, city: fromCity),
              FlightRouteStop(code: toCode, city: toCity),
            ];

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Water Background
    final effectiveWater = waterColor ??
        (isDarkMode ? const Color(0xFF131A18) : const Color(0xFFE2EBE7));
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = effectiveWater,
    );

    if (precomputed == null) return;
    final data = precomputed!;

    // 2. Countries Fill & Borders
    final effectiveLand = landColor ??
        (isDarkMode ? const Color(0xFF1E2824) : const Color(0xFFFAF7F1));
    final effectiveBorder = borderColor ??
        (isDarkMode ? const Color(0xFF2C3B36) : const Color(0xFFE5DECF));

    canvas.drawPath(
      data.countriesFillPath,
      Paint()
        ..color = effectiveLand
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      data.countriesStrokePath,
      Paint()
        ..color = effectiveBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // 3. Country Name Labels
    final effectiveLabelColor =
        isDarkMode ? const Color(0xFF6B8079) : const Color(0xFF8C9B96);
    final effectiveLabelStyle = labelStyle ??
        TextStyle(
          color: effectiveLabelColor,
          fontSize: 9.0,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        );

    for (final label in data.visibleLabels) {
      final textSpan = TextSpan(text: label.name, style: effectiveLabelStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        label.position - Offset(textPainter.width / 2.0, textPainter.height / 2.0),
      );
    }

    // 4. Flight Trajectories & Airplane Animation
    if (data.legs.isNotEmpty) {
      _paintMultiLegTrajectory(canvas, data);
    } else {
      _paintSingleLegTrajectory(canvas, data);
    }

    // 5. Airport Pins with Collision-Aware Floating Cards
    _paintAllAirportPinsAndCards(canvas, size, data);
  }

  void _paintSingleLegTrajectory(Canvas canvas, MapPrecomputedPaths data) {
    double arcFraction = 0.0;
    double arcAlpha = 1.0;

    if (animationProgress <= 0.65) {
      arcFraction = (animationProgress / 0.65).clamp(0.0, 1.0);
      arcAlpha = 1.0;
    } else if (animationProgress <= 0.85) {
      arcFraction = 1.0;
      arcAlpha = 1.0;
    } else {
      arcFraction = 1.0;
      arcAlpha = (1.0 - ((animationProgress - 0.85) / 0.15)).clamp(0.0, 1.0);
    }

    final totalLength = data.arcMetric.length;
    final currentDistance = totalLength * arcFraction;

    if (currentDistance > 1.0 && arcAlpha > 0.01) {
      final Path drawnArc = data.arcMetric.extractPath(0.0, currentDistance);

      final arcPaint = Paint()
        ..color = brandColor.withValues(alpha: arcAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final glowPaint = Paint()
        ..color = brandColor.withValues(alpha: 0.25 * arcAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(drawnArc, glowPaint);
      canvas.drawPath(drawnArc, arcPaint);

      if (arcAlpha > 0.05) {
        final Tangent? tangent = data.arcMetric.getTangentForOffset(currentDistance);
        if (tangent != null) {
          canvas.save();
          canvas.translate(tangent.position.dx, tangent.position.dy);
          canvas.rotate(tangent.vector.direction);
          _drawPlaneIcon(canvas, brandColor.withValues(alpha: arcAlpha));
          canvas.restore();
        }
      }
    }
  }

  void _paintMultiLegTrajectory(Canvas canvas, MapPrecomputedPaths data) {
    final legs = data.legs;
    if (legs.isEmpty) return;

    if (tripType == FlightTripType.roundTrip && legs.length >= 2) {
      _paintRoundTripAnimation(canvas, legs[0], legs[1]);
    } else if (tripType == FlightTripType.multiCity) {
      _paintMultiCityAnimation(canvas, legs);
    } else {
      _paintSingleLegTrajectory(canvas, data);
    }
  }

  void _paintRoundTripAnimation(
    Canvas canvas,
    FlightLegPath outbound,
    FlightLegPath returnLeg,
  ) {
    // Round trip phases:
    // [0.00 .. 0.44]: Outbound flight (plane moves start ➔ end)
    // [0.44 .. 0.50]: Hold at destination
    // [0.50 .. 0.92]: Return flight (plane moves end ➔ start along return arc)
    // [0.92 .. 1.00]: Hold at origin and smooth fade before repeat
    double globalAlpha = 1.0;
    if (animationProgress > 0.92) {
      globalAlpha = (1.0 - ((animationProgress - 0.92) / 0.08)).clamp(0.0, 1.0);
    }

    if (globalAlpha <= 0.01) return;

    final outboundLen = outbound.arcMetric.length;
    final returnLen = returnLeg.arcMetric.length;

    // Always draw subtle preview dotted/dashed guide for return path
    final returnGuidePaint = Paint()
      ..color = brandColor.withValues(alpha: 0.18 * globalAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawPath(returnLeg.arcPath, returnGuidePaint);

    if (animationProgress <= 0.44) {
      // Outbound animating
      final frac = (animationProgress / 0.44).clamp(0.0, 1.0);
      final dist = outboundLen * frac;
      if (dist > 1.0) {
        final path = outbound.arcMetric.extractPath(0.0, dist);
        _drawArcGlow(canvas, path, brandColor, globalAlpha);
        _drawPlaneAt(canvas, outbound.arcMetric, dist, brandColor, globalAlpha);
      }
    } else if (animationProgress <= 0.50) {
      // Destination pause
      _drawArcGlow(canvas, outbound.arcPath, brandColor, globalAlpha);
      _drawPlaneAt(canvas, outbound.arcMetric, outboundLen, brandColor, globalAlpha);
    } else if (animationProgress <= 0.92) {
      // Return flight animating: outbound remains visible
      _drawArcGlow(canvas, outbound.arcPath, brandColor, 0.45 * globalAlpha);

      final frac = ((animationProgress - 0.50) / 0.42).clamp(0.0, 1.0);
      final dist = returnLen * frac;
      if (dist > 1.0) {
        final returnDrawn = returnLeg.arcMetric.extractPath(0.0, dist);
        _drawArcGlow(canvas, returnDrawn, brandColor, globalAlpha);
        _drawPlaneAt(canvas, returnLeg.arcMetric, dist, brandColor, globalAlpha);
      }
    } else {
      // Final hold & fade
      _drawArcGlow(canvas, outbound.arcPath, brandColor, 0.45 * globalAlpha);
      _drawArcGlow(canvas, returnLeg.arcPath, brandColor, globalAlpha);
      _drawPlaneAt(canvas, returnLeg.arcMetric, returnLen, brandColor, globalAlpha);
    }
  }

  void _paintMultiCityAnimation(Canvas canvas, List<FlightLegPath> legs) {
    const flightEnd = 0.86;
    double globalAlpha = 1.0;
    if (animationProgress > flightEnd) {
      globalAlpha = (1.0 - ((animationProgress - flightEnd) / (1.0 - flightEnd))).clamp(0.0, 1.0);
    }

    if (globalAlpha <= 0.01) return;

    // Total distance of all legs combined
    final totalDistance = legs.fold<double>(0.0, (sum, l) => sum + l.arcMetric.length);
    if (totalDistance <= 0) return;

    // Draw all subsequent legs faintly so the full itinerary is visible
    final guidePaint = Paint()
      ..color = brandColor.withValues(alpha: 0.16 * globalAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    for (final leg in legs) {
      canvas.drawPath(leg.arcPath, guidePaint);
    }

    // Active distance along total itinerary
    final activeTotalDist = (animationProgress / flightEnd).clamp(0.0, 1.0) * totalDistance;

    double accumulated = 0.0;
    for (int i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final legLen = leg.arcMetric.length;
      final legStart = accumulated;
      final legEnd = accumulated + legLen;

      if (activeTotalDist >= legEnd) {
        // Leg fully traversed
        _drawArcGlow(canvas, leg.arcPath, brandColor, 0.65 * globalAlpha);
      } else if (activeTotalDist > legStart) {
        // Leg currently in progress
        final legDist = activeTotalDist - legStart;
        if (legDist > 1.0) {
          final partial = leg.arcMetric.extractPath(0.0, legDist);
          _drawArcGlow(canvas, partial, brandColor, globalAlpha);
          _drawPlaneAt(canvas, leg.arcMetric, legDist, brandColor, globalAlpha);
        }
      }

      accumulated += legLen;
    }

    // When held at end
    if (animationProgress >= flightEnd) {
      final lastLeg = legs.last;
      _drawPlaneAt(canvas, lastLeg.arcMetric, lastLeg.arcMetric.length, brandColor, globalAlpha);
    }
  }

  void _drawArcGlow(Canvas canvas, Path path, Color color, double alpha) {
    final arcPaint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.25 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, arcPaint);
  }

  void _drawPlaneAt(Canvas canvas, PathMetric metric, double distance, Color color, double alpha) {
    if (alpha <= 0.05) return;
    final Tangent? tangent = metric.getTangentForOffset(distance.clamp(0.0, metric.length));
    if (tangent != null) {
      canvas.save();
      canvas.translate(tangent.position.dx, tangent.position.dy);
      canvas.rotate(tangent.vector.direction);
      _drawPlaneIcon(canvas, color.withValues(alpha: alpha));
      canvas.restore();
    }
  }

  void _drawPlaneIcon(Canvas canvas, Color color) {
    final path = Path();
    path.moveTo(8, 0);
    path.lineTo(3, -2);
    path.lineTo(-1, -8);
    path.lineTo(-3, -8);
    path.lineTo(-2, -2);
    path.lineTo(-6, -2);
    path.lineTo(-8, -5);
    path.lineTo(-9, -5);
    path.lineTo(-8.5, 0);
    path.lineTo(-9, 5);
    path.lineTo(-8, 5);
    path.lineTo(-6, 2);
    path.lineTo(-2, 2);
    path.lineTo(-3, 8);
    path.lineTo(-1, 8);
    path.lineTo(3, 2);
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = isDarkMode ? const Color(0xFF131A18) : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  void _paintAllAirportPinsAndCards(Canvas canvas, Size canvasSize, MapPrecomputedPaths data) {
    final effectiveStops = stops;
    final List<Offset> positions = data.stopScreenPositions.isNotEmpty
        ? data.stopScreenPositions
        : [data.startPoint, data.endPoint];

    final List<Rect> occupiedCardRects = [];

    for (int i = 0; i < effectiveStops.length && i < positions.length; i++) {
      final stop = effectiveStops[i];
      final pos = positions[i];

      // Neighboring point for relative placement decision
      Offset? neighbor;
      if (i < positions.length - 1) {
        neighbor = positions[i + 1];
      } else if (i > 0) {
        neighbor = positions[i - 1];
      }

      _drawAirportPinAndCard(
        canvas: canvas,
        point: pos,
        iataCode: stop.code,
        cityName: stop.city,
        isOrigin: i == 0,
        stopIndex: (effectiveStops.length > 2) ? i + 1 : null,
        brandColor: brandColor,
        isDarkMode: isDarkMode,
        canvasSize: canvasSize,
        otherPoint: neighbor,
        occupiedRects: occupiedCardRects,
      );
    }
  }

  void _drawAirportPinAndCard({
    required Canvas canvas,
    required Offset point,
    required String iataCode,
    required String cityName,
    required bool isOrigin,
    required int? stopIndex,
    required Color brandColor,
    required bool isDarkMode,
    required Size canvasSize,
    Offset? otherPoint,
    required List<Rect> occupiedRects,
  }) {
    // 1. Airport Dot Ring & Pulse
    final ringPaint = Paint()
      ..color = brandColor
      ..style = PaintingStyle.fill;

    final centerPaint = Paint()
      ..color = isDarkMode ? const Color(0xFF131A18) : Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(point, 7.0, Paint()..color = brandColor.withValues(alpha: 0.25));
    canvas.drawCircle(point, 4.5, ringPaint);
    canvas.drawCircle(point, 2.0, centerPaint);

    // 2. Card Dimensions & Text Layout
    final effectiveCodeStyle = codeStyle ??
        TextStyle(
          color: brandColor,
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          letterSpacing: 0.5,
        );

    final cityColor = isDarkMode ? const Color(0xFFE2ECE9) : const Color(0xFF15201D);
    final effectiveCityStyle = cityStyle ??
        TextStyle(
          color: cityColor,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          fontFamilyFallback: const ['Georgia', 'serif'],
        );

    final displayText = (stopIndex != null)
        ? '$iataCode ($stopIndex)'.toUpperCase()
        : iataCode.toUpperCase();

    final codePainter = TextPainter(
      text: TextSpan(text: displayText, style: effectiveCodeStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final cityPainter = TextPainter(
      text: TextSpan(text: cityName, style: effectiveCityStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final double cardWidth = math.max(codePainter.width, cityPainter.width) + 18.0;
    final double cardHeight = codePainter.height + cityPainter.height + 11.0;

    // 3. Collision-aware Card Placement:
    bool placeAbove;
    if (otherPoint != null && (point.dy - otherPoint.dy).abs() >= 25.0) {
      placeAbove = point.dy < otherPoint.dy;
    } else {
      placeAbove = isOrigin;
    }

    double rawCardTop = placeAbove ? (point.dy - cardHeight - 12.0) : (point.dy + 12.0);
    double cardLeft = (point.dx - cardWidth / 2.0).clamp(10.0, canvasSize.width - cardWidth - 10.0);
    double cardTop = rawCardTop.clamp(68.0, canvasSize.height - cardHeight - 80.0);

    Rect candidateRect = Rect.fromLTWH(cardLeft, cardTop, cardWidth, cardHeight);

    // If candidate collides with an existing placed card, try flipping vertical direction
    for (final occupied in occupiedRects) {
      if (candidateRect.overlaps(occupied)) {
        placeAbove = !placeAbove;
        rawCardTop = placeAbove ? (point.dy - cardHeight - 12.0) : (point.dy + 12.0);
        cardTop = rawCardTop.clamp(68.0, canvasSize.height - cardHeight - 80.0);
        candidateRect = Rect.fromLTWH(cardLeft, cardTop, cardWidth, cardHeight);
        break;
      }
    }

    occupiedRects.add(candidateRect);

    final RRect cardRRect = RRect.fromRectAndRadius(
      candidateRect,
      const Radius.circular(9.0),
    );

    // Card shadow
    canvas.drawRRect(
      cardRRect.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: isDarkMode ? 0.35 : 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );

    // Card background & border
    final effectiveCardBg = cardBackgroundColor ??
        (isDarkMode ? const Color(0xFF1E2824) : const Color(0xFFFAF7F1));
    final effectiveCardBorder = cardBorderColor ??
        (isDarkMode ? const Color(0xFF2C3B36) : const Color(0xFFE5DECF));

    canvas.drawRRect(cardRRect, Paint()..color = effectiveCardBg);
    canvas.drawRRect(
      cardRRect,
      Paint()
        ..color = effectiveCardBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Connecting stem line from card to dot
    final double stemX = point.dx.clamp(cardLeft + 10.0, cardLeft + cardWidth - 10.0);
    final double stemYStart = placeAbove ? (cardTop + cardHeight) : cardTop;
    final double stemYEnd = placeAbove ? (point.dy - 5.0) : (point.dy + 5.0);

    if ((stemYEnd - stemYStart).abs() > 2.0) {
      canvas.drawLine(
        Offset(stemX, stemYStart),
        Offset(point.dx, stemYEnd),
        Paint()
          ..color = brandColor.withValues(alpha: 0.65)
          ..strokeWidth = 1.5,
      );
    }

    // Paint Text inside Card
    final double contentCenterX = cardLeft + cardWidth / 2.0;
    codePainter.paint(
      canvas,
      Offset(contentCenterX - codePainter.width / 2.0, cardTop + 5.0),
    );
    cityPainter.paint(
      canvas,
      Offset(contentCenterX - cityPainter.width / 2.0, cardTop + 6.5 + codePainter.height),
    );
  }

  @override
  bool shouldRepaint(covariant FlightMapPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.precomputed != precomputed ||
        oldDelegate.isDarkMode != isDarkMode ||
        oldDelegate.fromCode != fromCode ||
        oldDelegate.toCode != toCode ||
        oldDelegate.stops.length != stops.length ||
        oldDelegate.tripType != tripType ||
        oldDelegate.brandColor != brandColor ||
        oldDelegate.waterColor != waterColor ||
        oldDelegate.landColor != landColor ||
        oldDelegate.borderColor != borderColor;
  }
}
