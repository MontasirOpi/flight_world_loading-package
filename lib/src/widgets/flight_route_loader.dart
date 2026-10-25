import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/airport_coordinates_helper.dart';
import '../helpers/map_projection_helper.dart';
import '../models/country_polygon.dart';
import '../models/map_precomputed_paths.dart';
import '../services/geo_json_service.dart';
import 'flight_map_painter.dart';

/// A full-screen or embedded flight route loading widget featuring an animated,
/// offline vector world map, collision-free airport cards, tangent-rotated airplane,
/// and step progress indicators.
class FlightRouteLoader extends StatefulWidget {
  /// Origin 3-letter IATA code (e.g. 'DAC', 'JFK').
  final String fromCode;

  /// Origin city name displayed on the route card.
  final String fromCity;

  /// Optional origin latitude. If null, resolved automatically via [AirportCoordinatesHelper].
  final double? fromLat;

  /// Optional origin longitude. If null, resolved automatically via [AirportCoordinatesHelper].
  final double? fromLng;

  /// Optional origin country name for fallback centroid resolution.
  final String? fromCountry;

  /// Optional origin ISO country code (e.g. 'US', 'BD').
  final String? fromCountryCode;

  /// Destination 3-letter IATA code (e.g. 'CXB', 'LHR').
  final String toCode;

  /// Destination city name displayed on the route card.
  final String toCity;

  /// Optional destination latitude. If null, resolved automatically via [AirportCoordinatesHelper].
  final double? toLat;

  /// Optional destination longitude. If null, resolved automatically via [AirportCoordinatesHelper].
  final double? toLng;

  /// Optional destination country name for fallback centroid resolution.
  final String? toCountry;

  /// Optional destination ISO country code (e.g. 'US', 'BD').
  final String? toCountryCode;

  /// Primary theme color used for the flight arc, airplane, pins, and step indicators.
  final Color brandColor;

  /// Sequential step messages displayed in the bottom progress bar.
  final List<String>? stepLabels;

  /// Active step index (0-based). If provided, step progression is driven externally.
  /// If null, steps advance automatically using [stepDuration].
  final int? currentStep;

  /// Interval between automatic step advances when [currentStep] is not provided.
  final Duration stepDuration;

  /// Header subtitle text (e.g. "Scanning airlines for live fares...").
  final String? subtitle;

  /// Optional callback invoked when the user taps the cancel button.
  final VoidCallback? onCancel;

  /// Whether to display the top floating route header pill.
  final bool showTopPill;

  /// Whether to display the bottom step progress card.
  final bool showBottomStepBar;

  /// Duration of a single flight trajectory loop animation.
  final Duration animationDuration;

  /// Water canvas background color override.
  final Color? waterColor;

  /// Landmass fill color override.
  final Color? landColor;

  /// Landmass border stroke color override.
  final Color? borderColor;

  /// Airport card background color override.
  final Color? cardBackgroundColor;

  /// Airport card border stroke color override.
  final Color? cardBorderColor;

  /// Custom text style for IATA codes.
  final TextStyle? codeStyle;

  /// Custom text style for city names.
  final TextStyle? cityStyle;

  /// Custom text style for country names.
  final TextStyle? labelStyle;

  const FlightRouteLoader({
    super.key,
    required this.fromCode,
    required this.fromCity,
    this.fromLat,
    this.fromLng,
    this.fromCountry,
    this.fromCountryCode,
    required this.toCode,
    required this.toCity,
    this.toLat,
    this.toLng,
    this.toCountry,
    this.toCountryCode,
    this.brandColor = const Color(0xFF1F4A3F),
    this.stepLabels,
    this.currentStep,
    this.stepDuration = const Duration(milliseconds: 1400),
    this.subtitle,
    this.onCancel,
    this.showTopPill = true,
    this.showBottomStepBar = true,
    this.animationDuration = const Duration(milliseconds: 2500),
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
  State<FlightRouteLoader> createState() => _FlightRouteLoaderState();
}

class _FlightRouteLoaderState extends State<FlightRouteLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  Timer? _stepTimer;
  int _internalStep = 0;

  List<CountryPolygon>? _countries;
  MapPrecomputedPaths? _precomputed;
  Size? _lastSize;

  late double _resolvedFromLat;
  late double _resolvedFromLng;
  late double _resolvedToLat;
  late double _resolvedToLng;

  static const List<String> _defaultSteps = [
    'Live fares',
    'Routes & layovers',
    'Best prices',
    'Ranking options',
  ];

  @override
  void initState() {
    super.initState();

    _resolveCoordinates();

    _animController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..repeat();

    _initStepTimer();
    _loadGeoData();
  }

  void _resolveCoordinates() {
    final fromCoords = AirportCoordinatesHelper.getCoordinates(
      widget.fromCode,
      fallbackLat: widget.fromLat,
      fallbackLng: widget.fromLng,
      country: widget.fromCountry,
      countryCode: widget.fromCountryCode,
    );
    _resolvedFromLat = fromCoords.$1;
    _resolvedFromLng = fromCoords.$2;

    final toCoords = AirportCoordinatesHelper.getCoordinates(
      widget.toCode,
      fallbackLat: widget.toLat,
      fallbackLng: widget.toLng,
      country: widget.toCountry,
      countryCode: widget.toCountryCode,
    );
    _resolvedToLat = toCoords.$1;
    _resolvedToLng = toCoords.$2;
  }

  void _initStepTimer() {
    if (widget.currentStep != null) return;
    final totalSteps = (widget.stepLabels ?? _defaultSteps).length;
    _stepTimer?.cancel();
    _stepTimer = Timer.periodic(widget.stepDuration, (timer) {
      if (!mounted) return;
      if (_internalStep < totalSteps - 1) {
        setState(() => _internalStep++);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _loadGeoData() async {
    final list = await GeoJsonService.loadCountries();
    if (mounted) {
      setState(() {
        _countries = list;
        _recomputePaths();
      });
    }
  }

  @override
  void didUpdateWidget(covariant FlightRouteLoader oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.fromCode != widget.fromCode ||
        oldWidget.toCode != widget.toCode ||
        oldWidget.fromLat != widget.fromLat ||
        oldWidget.fromLng != widget.fromLng ||
        oldWidget.toLat != widget.toLat ||
        oldWidget.toLng != widget.toLng) {
      _resolveCoordinates();
      _recomputePaths();
    }

    if (oldWidget.animationDuration != widget.animationDuration) {
      _animController.duration = widget.animationDuration;
    }
  }

  void _recomputePaths() {
    if (_countries == null || _lastSize == null || _lastSize!.width <= 0) return;

    final Size size = _lastSize!;
    final Offset p1Norm = MapProjectionHelper.projectToMercator(
      _resolvedFromLat,
      _resolvedFromLng,
    );
    final Offset p2Norm = MapProjectionHelper.projectToMercator(
      _resolvedToLat,
      _resolvedToLng,
    );

    final viewport = MapProjectionHelper.calculateViewport(
      canvasSize: size,
      p1Norm: p1Norm,
      p2Norm: p2Norm,
      paddingRatio: 0.35,
    );

    final Offset startPoint = viewport.toScreen(p1Norm);
    final Offset endPoint = viewport.toScreen(p2Norm);

    final Path fillPath = Path();
    final Path strokePath = Path();
    final List<({String name, Offset position})> visibleLabels = [];

    final Rect screenRect = Offset.zero & size;

    for (final country in _countries!) {
      final Offset cMin = MapProjectionHelper.projectToMercator(
        country.maxLat,
        country.minLng,
      );
      final Offset cMax = MapProjectionHelper.projectToMercator(
        country.minLat,
        country.maxLng,
      );

      final Offset sMin = viewport.toScreen(cMin);
      final Offset sMax = viewport.toScreen(cMax);
      final Rect countryScreenBox = Rect.fromPoints(sMin, sMax);

      // Skip country if completely outside screen viewport
      if (!screenRect.overlaps(countryScreenBox)) continue;

      for (final ring in country.rings) {
        if (ring.isEmpty) continue;
        final Path ringPath = Path();
        final firstScreen = viewport.toScreen(
          MapProjectionHelper.projectToMercator(ring.first.dy, ring.first.dx),
        );
        ringPath.moveTo(firstScreen.dx, firstScreen.dy);

        for (int i = 1; i < ring.length; i++) {
          final ptScreen = viewport.toScreen(
            MapProjectionHelper.projectToMercator(ring[i].dy, ring[i].dx),
          );
          ringPath.lineTo(ptScreen.dx, ptScreen.dy);
        }
        ringPath.close();

        fillPath.addPath(ringPath, Offset.zero);
        strokePath.addPath(ringPath, Offset.zero);
      }

      // Display country name labels uncluttered
      if (country.name.isNotEmpty &&
          countryScreenBox.width > 60.0 &&
          countryScreenBox.height > 35.0 &&
          screenRect.contains(countryScreenBox.center)) {
        final double distToStart = (countryScreenBox.center - startPoint).distance;
        final double distToEnd = (countryScreenBox.center - endPoint).distance;
        if (distToStart > 45.0 && distToEnd > 45.0) {
          visibleLabels.add((name: country.name, position: countryScreenBox.center));
        }
      }
    }

    final Path flightArc = MapProjectionHelper.createFlightArcPath(
      start: startPoint,
      end: endPoint,
      curveRatio: 0.22,
    );

    final metrics = flightArc.computeMetrics().toList();
    if (metrics.isEmpty) return;

    _precomputed = MapPrecomputedPaths(
      size: size,
      countriesFillPath: fillPath,
      countriesStrokePath: strokePath,
      flightArcPath: flightArc,
      arcMetric: metrics.first,
      startPoint: startPoint,
      endPoint: endPoint,
      visibleLabels: visibleLabels,
    );
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<String> steps = widget.stepLabels ?? _defaultSteps;
    final int activeStep = widget.currentStep ?? _internalStep;

    final effectiveWater = widget.waterColor ??
        (isDark ? const Color(0xFF131A18) : const Color(0xFFE2EBE7));

    return Scaffold(
      backgroundColor: effectiveWater,
      body: Stack(
        children: [
          // ── 1. Vector Map Canvas ──
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final newSize = Size(constraints.maxWidth, constraints.maxHeight);
                if (_lastSize != newSize) {
                  _lastSize = newSize;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _recomputePaths());
                  });
                }

                return AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return RepaintBoundary(
                      child: CustomPaint(
                        size: newSize,
                        painter: FlightMapPainter(
                          precomputed: _precomputed,
                          animationProgress: _animController.value,
                          fromCode: widget.fromCode,
                          fromCity: widget.fromCity,
                          toCode: widget.toCode,
                          toCity: widget.toCity,
                          brandColor: widget.brandColor,
                          isDarkMode: isDark,
                          waterColor: widget.waterColor,
                          landColor: widget.landColor,
                          borderColor: widget.borderColor,
                          cardBackgroundColor: widget.cardBackgroundColor,
                          cardBorderColor: widget.cardBorderColor,
                          codeStyle: widget.codeStyle,
                          cityStyle: widget.cityStyle,
                          labelStyle: widget.labelStyle,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ── 2. Top Floating Header Pill ──
          if (widget.showTopPill)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: _buildTopPill(isDark),
                ),
              ),
            ),

          // ── 3. Bottom Progress Bar Card ──
          if (widget.showBottomStepBar)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: _buildBottomStepBar(steps, activeStep, isDark),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopPill(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2824) : const Color(0xFFFAF7F1),
        borderRadius: BorderRadius.circular(99.0),
        border: Border.all(
          color: isDark ? const Color(0xFF2C3B36) : const Color(0xFFE5DECF),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 14.0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular Plane Badge
          Container(
            width: 36.0,
            height: 36.0,
            decoration: BoxDecoration(
              color: widget.brandColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.brandColor.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(
              Icons.flight_takeoff_rounded,
              color: widget.brandColor,
              size: 19.0,
            ),
          ),
          const SizedBox(width: 10.0),

          // Route Details
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.fromCity,
                        style: _safeGoogleFont(
                          () => GoogleFonts.fraunces(
                            fontSize: 14.0,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? const Color(0xFFF4EFE6)
                                : const Color(0xFF15201D),
                          ),
                          fallback: TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? const Color(0xFFF4EFE6)
                                : const Color(0xFF15201D),
                          ),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 13.0,
                        color: widget.brandColor,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        widget.toCity,
                        style: _safeGoogleFont(
                          () => GoogleFonts.fraunces(
                            fontSize: 14.0,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? const Color(0xFFF4EFE6)
                                : const Color(0xFF15201D),
                          ),
                          fallback: TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? const Color(0xFFF4EFE6)
                                : const Color(0xFF15201D),
                          ),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1.5),
                Text(
                  widget.subtitle ?? 'Scanning airlines for live fares...',
                  style: _safeGoogleFont(
                    () => GoogleFonts.plusJakartaSans(
                      fontSize: 11.0,
                      color: isDark
                          ? const Color(0xFF909090)
                          : const Color(0xFF7B8884),
                    ),
                    fallback: TextStyle(
                      fontSize: 11.0,
                      color: isDark
                          ? const Color(0xFF909090)
                          : const Color(0xFF7B8884),
                    ),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Cancel button affordance
          if (widget.onCancel != null) ...[
            const SizedBox(width: 8.0),
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 18.0,
                color: isDark
                    ? const Color(0xFF909090)
                    : const Color(0xFF7B8884),
              ),
              tooltip: 'Cancel Search',
              onPressed: widget.onCancel,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32.0, minHeight: 32.0),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomStepBar(List<String> steps, int activeStep, bool isDark) {
    final clampedStep = activeStep.clamp(0, steps.length - 1);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2824) : const Color(0xFFFAF7F1),
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(
          color: isDark ? const Color(0xFF2C3B36) : const Color(0xFFE5DECF),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 16.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: List.generate(steps.length * 2 - 1, (index) {
              if (index.isOdd) {
                final int stepBefore = index ~/ 2;
                final bool isPassed = clampedStep > stepBefore;
                return Expanded(
                  child: Container(
                    height: 2.5,
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    decoration: BoxDecoration(
                      color: isPassed
                          ? widget.brandColor
                          : (isDark
                              ? const Color(0xFF2D2D2D)
                              : const Color(0xFFEDE6D7)),
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                );
              }

              final int stepIdx = index ~/ 2;
              final bool isDone = clampedStep > stepIdx;
              final bool isCurrent = clampedStep == stepIdx;

              Color circleBg;
              Widget circleContent;

              if (isDone) {
                circleBg = widget.brandColor;
                circleContent = const Icon(Icons.check, size: 13.0, color: Colors.white);
              } else if (isCurrent) {
                circleBg = widget.brandColor;
                circleContent = Text(
                  '${stepIdx + 1}',
                  style: _safeGoogleFont(
                    () => GoogleFonts.jetBrainsMono(
                      color: Colors.white,
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                    ),
                    fallback: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              } else {
                circleBg = isDark ? const Color(0xFF282828) : const Color(0xFFEDE6D7);
                circleContent = Text(
                  '${stepIdx + 1}',
                  style: _safeGoogleFont(
                    () => GoogleFonts.jetBrainsMono(
                      color: isDark
                          ? const Color(0xFF909090)
                          : const Color(0xFF7B8884),
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                    ),
                    fallback: TextStyle(
                      color: isDark
                          ? const Color(0xFF909090)
                          : const Color(0xFF7B8884),
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              }

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 26.0,
                height: 26.0,
                decoration: BoxDecoration(
                  color: circleBg,
                  shape: BoxShape.circle,
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: widget.brandColor.withValues(alpha: 0.35),
                            blurRadius: 8.0,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: circleContent,
              );
            }),
          ),
          const SizedBox(height: 11.0),

          // Active Step Message
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  steps[clampedStep],
                  style: _safeGoogleFont(
                    () => GoogleFonts.plusJakartaSans(
                      fontSize: 13.0,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? const Color(0xFFF4EFE6)
                          : const Color(0xFF15201D),
                    ),
                    fallback: TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? const Color(0xFFF4EFE6)
                          : const Color(0xFF15201D),
                    ),
                  ),
                ),
              ),
              Text(
                'Step ${clampedStep + 1} / ${steps.length}',
                style: _safeGoogleFont(
                  () => GoogleFonts.jetBrainsMono(
                    fontSize: 11.0,
                    color: widget.brandColor,
                    fontWeight: FontWeight.w700,
                  ),
                  fallback: TextStyle(
                    fontSize: 11.0,
                    color: widget.brandColor,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static TextStyle _safeGoogleFont(TextStyle Function() builder, {required TextStyle fallback}) {
    try {
      return builder();
    } catch (_) {
      return fallback;
    }
  }
}
