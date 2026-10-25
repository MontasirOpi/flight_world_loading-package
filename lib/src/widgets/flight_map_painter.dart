import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/map_precomputed_paths.dart';

/// A high-performance 60fps [CustomPainter] that renders the vector world map,
/// country landmasses, collision-safe airport cards, and tangent-aligned flight trajectory.
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
  });

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
        _safeGoogleFont(
          () => GoogleFonts.plusJakartaSans(
            color: effectiveLabelColor,
            fontSize: 9.0,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
          fallback: TextStyle(
            color: effectiveLabelColor,
            fontSize: 9.0,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
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

    // 4. Flight Arc & Plane Animation Phase calculation:
    // [0.00 .. 0.65]: Draw arc and move plane from origin to destination
    // [0.65 .. 0.85]: Hold arc and plane at destination
    // [0.85 .. 1.00]: Fade out arc and plane
    double arcFraction = 0.0;
    double arcAlpha = 1.0;
    const bool showPlane = true;

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

      // Soft glow shadow behind the arc
      final glowPaint = Paint()
        ..color = brandColor.withValues(alpha: 0.25 * arcAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(drawnArc, glowPaint);
      canvas.drawPath(drawnArc, arcPaint);

      // 5. Airplane Icon Tangent-Aligned
      if (showPlane && arcAlpha > 0.05) {
        final Tangent? tangent = data.arcMetric.getTangentForOffset(currentDistance);
        if (tangent != null) {
          canvas.save();
          canvas.translate(tangent.position.dx, tangent.position.dy);
          // Continuous rotation matching path's exact tangent angle
          canvas.rotate(tangent.vector.direction);
          _drawPlaneIcon(canvas, brandColor.withValues(alpha: arcAlpha));
          canvas.restore();
        }
      }
    }

    // 6. Origin & Destination Pins with Collision-Aware Floating Cards
    _drawAirportPinAndCard(
      canvas: canvas,
      point: data.startPoint,
      iataCode: fromCode,
      cityName: fromCity,
      isOrigin: true,
      brandColor: brandColor,
      isDarkMode: isDarkMode,
      canvasSize: size,
      otherPoint: data.endPoint,
    );

    _drawAirportPinAndCard(
      canvas: canvas,
      point: data.endPoint,
      iataCode: toCode,
      cityName: toCity,
      isOrigin: false,
      brandColor: brandColor,
      isDarkMode: isDarkMode,
      canvasSize: size,
      otherPoint: data.startPoint,
    );
  }

  void _drawPlaneIcon(Canvas canvas, Color color) {
    final path = Path();
    // Facing right (0 radians)
    path.moveTo(8, 0);     // Nose
    path.lineTo(3, -2);
    path.lineTo(-1, -8);   // Top wing tip
    path.lineTo(-3, -8);
    path.lineTo(-2, -2);
    path.lineTo(-6, -2);
    path.lineTo(-8, -5);   // Tail wing top
    path.lineTo(-9, -5);
    path.lineTo(-8.5, 0);  // Tail center
    path.lineTo(-9, 5);
    path.lineTo(-8, 5);    // Tail wing bottom
    path.lineTo(-6, 2);
    path.lineTo(-2, 2);
    path.lineTo(-3, 8);
    path.lineTo(-1, 8);    // Bottom wing tip
    path.lineTo(3, 2);
    path.close();

    // High-contrast background outline
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

  void _drawAirportPinAndCard({
    required Canvas canvas,
    required Offset point,
    required String iataCode,
    required String cityName,
    required bool isOrigin,
    required Color brandColor,
    required bool isDarkMode,
    required Size canvasSize,
    Offset? otherPoint,
  }) {
    // 1. Airport Dot Ring & Pulse
    final ringPaint = Paint()
      ..color = brandColor
      ..style = PaintingStyle.fill;

    final centerPaint = Paint()
      ..color = isDarkMode ? const Color(0xFF131A18) : Colors.white
      ..style = PaintingStyle.fill;

    // Outer glow ring
    canvas.drawCircle(point, 7.0, Paint()..color = brandColor.withValues(alpha: 0.25));
    // Core colored dot
    canvas.drawCircle(point, 4.5, ringPaint);
    // Tiny center dot
    canvas.drawCircle(point, 2.0, centerPaint);

    // 2. Card Dimensions & Text Layout
    final effectiveCodeStyle = codeStyle ??
        _safeGoogleFont(
          () => GoogleFonts.jetBrainsMono(
            color: brandColor,
            fontSize: 12.0,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          fallback: TextStyle(
            color: brandColor,
            fontSize: 12.0,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            letterSpacing: 0.5,
          ),
        );

    final cityColor = isDarkMode ? const Color(0xFFE2ECE9) : const Color(0xFF15201D);
    final effectiveCityStyle = cityStyle ??
        _safeGoogleFont(
          () => GoogleFonts.fraunces(
            color: cityColor,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
          fallback: TextStyle(
            color: cityColor,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        );

    final codePainter = TextPainter(
      text: TextSpan(text: iataCode.toUpperCase(), style: effectiveCodeStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final cityPainter = TextPainter(
      text: TextSpan(text: cityName, style: effectiveCityStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final double cardWidth = math.max(codePainter.width, cityPainter.width) + 18.0;
    final double cardHeight = codePainter.height + cityPainter.height + 11.0;

    // 3. Collision-aware Card Placement:
    // Northern point sits ABOVE; Southern point sits BELOW on North-South hops.
    // Origin sits ABOVE; Destination sits BELOW on East-West routes.
    bool placeAbove;
    if (otherPoint != null && (point.dy - otherPoint.dy).abs() >= 25.0) {
      placeAbove = point.dy < otherPoint.dy;
    } else {
      placeAbove = isOrigin;
    }

    final double rawCardTop = placeAbove ? (point.dy - cardHeight - 12.0) : (point.dy + 12.0);

    // Clamp card horizontally within screen boundaries (10px margin)
    final double cardLeft = (point.dx - cardWidth / 2.0).clamp(10.0, canvasSize.width - cardWidth - 10.0);
    // Clamp card vertically between top floating header and bottom status bar
    final double cardTop = rawCardTop.clamp(68.0, canvasSize.height - cardHeight - 80.0);

    final RRect cardRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardLeft, cardTop, cardWidth, cardHeight),
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

    // Paint Text inside Card (horizontally centered)
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

  static TextStyle _safeGoogleFont(TextStyle Function() builder, {required TextStyle fallback}) {
    try {
      return builder();
    } catch (_) {
      return fallback;
    }
  }

  @override
  bool shouldRepaint(covariant FlightMapPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.precomputed != precomputed ||
        oldDelegate.isDarkMode != isDarkMode ||
        oldDelegate.fromCode != fromCode ||
        oldDelegate.toCode != toCode ||
        oldDelegate.brandColor != brandColor ||
        oldDelegate.waterColor != waterColor ||
        oldDelegate.landColor != landColor ||
        oldDelegate.borderColor != borderColor;
  }
}
