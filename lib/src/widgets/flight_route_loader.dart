import 'dart:async';
import 'package:flutter/material.dart';

import '../helpers/airport_coordinates_helper.dart';
import '../helpers/map_projection_helper.dart';
import '../models/airport.dart';
import '../models/country_polygon.dart';
import '../models/flight_route_stop.dart';
import '../models/flight_trip_type.dart';
import '../models/map_precomputed_paths.dart';
import '../services/geo_json_service.dart';
import 'flight_map_painter.dart';

/// A full-screen or embedded flight route loading widget featuring an animated,
/// offline vector world map, collision-free airport cards, tangent-rotated airplane,
/// and step progress indicators.
///
/// Supports [FlightTripType.oneWay], [FlightTripType.roundTrip], and [FlightTripType.multiCity] itineraries.
class FlightRouteLoader extends StatefulWidget {
  /// Itinerary type mode: one-way, round-trip, or multi-city.
  final FlightTripType tripType;

  /// Explicit list of route stops. If provided, overrides [fromCode]/[toCode].
  final List<FlightRouteStop>? stops;

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

  /// Custom text style for the route header pill title.
  final TextStyle? titleStyle;

  /// Custom text style for the route header pill subtitle.
  final TextStyle? subtitleStyle;

  /// Standard constructor supporting one-way routes, round-trips, or multi-city trips.
  const FlightRouteLoader({
    super.key,
    this.tripType = FlightTripType.oneWay,
    this.stops,
    this.fromCode = '',
    this.fromCity = '',
    this.fromLat,
    this.fromLng,
    this.fromCountry,
    this.fromCountryCode,
    this.toCode = '',
    this.toCity = '',
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
    this.titleStyle,
    this.subtitleStyle,
  });

  /// Factory constructor for a one-way flight between two [FlightRouteStop] stops.
  factory FlightRouteLoader.oneWay({
    Key? key,
    required FlightRouteStop from,
    required FlightRouteStop to,
    Color brandColor = const Color(0xFF1F4A3F),
    List<String>? stepLabels,
    int? currentStep,
    Duration stepDuration = const Duration(milliseconds: 1400),
    String? subtitle,
    VoidCallback? onCancel,
    bool showTopPill = true,
    bool showBottomStepBar = true,
    Duration animationDuration = const Duration(milliseconds: 2500),
    Color? waterColor,
    Color? landColor,
    Color? borderColor,
    Color? cardBackgroundColor,
    Color? cardBorderColor,
    TextStyle? codeStyle,
    TextStyle? cityStyle,
    TextStyle? labelStyle,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
  }) {
    return FlightRouteLoader(
      key: key,
      tripType: FlightTripType.oneWay,
      stops: [from, to],
      fromCode: from.code,
      fromCity: from.city,
      fromLat: from.latitude,
      fromLng: from.longitude,
      fromCountry: from.country,
      fromCountryCode: from.countryCode,
      toCode: to.code,
      toCity: to.city,
      toLat: to.latitude,
      toLng: to.longitude,
      toCountry: to.country,
      toCountryCode: to.countryCode,
      brandColor: brandColor,
      stepLabels: stepLabels,
      currentStep: currentStep,
      stepDuration: stepDuration,
      subtitle: subtitle,
      onCancel: onCancel,
      showTopPill: showTopPill,
      showBottomStepBar: showBottomStepBar,
      animationDuration: animationDuration,
      waterColor: waterColor,
      landColor: landColor,
      borderColor: borderColor,
      cardBackgroundColor: cardBackgroundColor,
      cardBorderColor: cardBorderColor,
      codeStyle: codeStyle,
      cityStyle: cityStyle,
      labelStyle: labelStyle,
      titleStyle: titleStyle,
      subtitleStyle: subtitleStyle,
    );
  }

  /// Factory constructor for a round-trip flight between two [FlightRouteStop] stops.
  factory FlightRouteLoader.roundTrip({
    Key? key,
    required FlightRouteStop from,
    required FlightRouteStop to,
    Color brandColor = const Color(0xFF1F4A3F),
    List<String>? stepLabels,
    int? currentStep,
    Duration stepDuration = const Duration(milliseconds: 1400),
    String? subtitle,
    VoidCallback? onCancel,
    bool showTopPill = true,
    bool showBottomStepBar = true,
    Duration animationDuration = const Duration(milliseconds: 3200),
    Color? waterColor,
    Color? landColor,
    Color? borderColor,
    Color? cardBackgroundColor,
    Color? cardBorderColor,
    TextStyle? codeStyle,
    TextStyle? cityStyle,
    TextStyle? labelStyle,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
  }) {
    return FlightRouteLoader(
      key: key,
      tripType: FlightTripType.roundTrip,
      stops: [from, to],
      fromCode: from.code,
      fromCity: from.city,
      fromLat: from.latitude,
      fromLng: from.longitude,
      fromCountry: from.country,
      fromCountryCode: from.countryCode,
      toCode: to.code,
      toCity: to.city,
      toLat: to.latitude,
      toLng: to.longitude,
      toCountry: to.country,
      toCountryCode: to.countryCode,
      brandColor: brandColor,
      stepLabels: stepLabels,
      currentStep: currentStep,
      stepDuration: stepDuration,
      subtitle: subtitle,
      onCancel: onCancel,
      showTopPill: showTopPill,
      showBottomStepBar: showBottomStepBar,
      animationDuration: animationDuration,
      waterColor: waterColor,
      landColor: landColor,
      borderColor: borderColor,
      cardBackgroundColor: cardBackgroundColor,
      cardBorderColor: cardBorderColor,
      codeStyle: codeStyle,
      cityStyle: cityStyle,
      labelStyle: labelStyle,
      titleStyle: titleStyle,
      subtitleStyle: subtitleStyle,
    );
  }

  /// Factory constructor for a multi-city flight consisting of 2 or more sequential stops.
  factory FlightRouteLoader.multiCity({
    Key? key,
    required List<FlightRouteStop> stops,
    Color brandColor = const Color(0xFF1F4A3F),
    List<String>? stepLabels,
    int? currentStep,
    Duration stepDuration = const Duration(milliseconds: 1400),
    String? subtitle,
    VoidCallback? onCancel,
    bool showTopPill = true,
    bool showBottomStepBar = true,
    Duration animationDuration = const Duration(milliseconds: 4000),
    Color? waterColor,
    Color? landColor,
    Color? borderColor,
    Color? cardBackgroundColor,
    Color? cardBorderColor,
    TextStyle? codeStyle,
    TextStyle? cityStyle,
    TextStyle? labelStyle,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
  }) {
    assert(stops.length >= 2, 'Multi-city flights must have at least 2 stops.');
    final first = stops.first;
    final last = stops.last;
    return FlightRouteLoader(
      key: key,
      tripType: FlightTripType.multiCity,
      stops: stops,
      fromCode: first.code,
      fromCity: first.city,
      fromLat: first.latitude,
      fromLng: first.longitude,
      fromCountry: first.country,
      fromCountryCode: first.countryCode,
      toCode: last.code,
      toCity: last.city,
      toLat: last.latitude,
      toLng: last.longitude,
      toCountry: last.country,
      toCountryCode: last.countryCode,
      brandColor: brandColor,
      stepLabels: stepLabels,
      currentStep: currentStep,
      stepDuration: stepDuration,
      subtitle: subtitle,
      onCancel: onCancel,
      showTopPill: showTopPill,
      showBottomStepBar: showBottomStepBar,
      animationDuration: animationDuration,
      waterColor: waterColor,
      landColor: landColor,
      borderColor: borderColor,
      cardBackgroundColor: cardBackgroundColor,
      cardBorderColor: cardBorderColor,
      codeStyle: codeStyle,
      cityStyle: cityStyle,
      labelStyle: labelStyle,
      titleStyle: titleStyle,
      subtitleStyle: subtitleStyle,
    );
  }

  /// Convenience constructor to build directly from a list of [Airport] models.
  factory FlightRouteLoader.fromAirports({
    Key? key,
    required List<Airport> airports,
    FlightTripType tripType = FlightTripType.oneWay,
    Color brandColor = const Color(0xFF1F4A3F),
    List<String>? stepLabels,
    int? currentStep,
    Duration stepDuration = const Duration(milliseconds: 1400),
    String? subtitle,
    VoidCallback? onCancel,
    bool showTopPill = true,
    bool showBottomStepBar = true,
    Duration? animationDuration,
    Color? waterColor,
    Color? landColor,
    Color? borderColor,
    Color? cardBackgroundColor,
    Color? cardBorderColor,
    TextStyle? codeStyle,
    TextStyle? cityStyle,
    TextStyle? labelStyle,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
  }) {
    assert(airports.length >= 2, 'Itinerary must contain at least 2 airports.');
    final stops = airports.map(FlightRouteStop.fromAirport).toList();
    final effectiveDuration = animationDuration ??
        (tripType == FlightTripType.multiCity
            ? const Duration(milliseconds: 4000)
            : (tripType == FlightTripType.roundTrip
                ? const Duration(milliseconds: 3200)
                : const Duration(milliseconds: 2500)));

    final first = stops.first;
    final last = stops.last;

    return FlightRouteLoader(
      key: key,
      tripType: tripType,
      stops: stops,
      fromCode: first.code,
      fromCity: first.city,
      fromLat: first.latitude,
      fromLng: first.longitude,
      fromCountry: first.country,
      fromCountryCode: first.countryCode,
      toCode: last.code,
      toCity: last.city,
      toLat: last.latitude,
      toLng: last.longitude,
      toCountry: last.country,
      toCountryCode: last.countryCode,
      brandColor: brandColor,
      stepLabels: stepLabels,
      currentStep: currentStep,
      stepDuration: stepDuration,
      subtitle: subtitle,
      onCancel: onCancel,
      showTopPill: showTopPill,
      showBottomStepBar: showBottomStepBar,
      animationDuration: effectiveDuration,
      waterColor: waterColor,
      landColor: landColor,
      borderColor: borderColor,
      cardBackgroundColor: cardBackgroundColor,
      cardBorderColor: cardBorderColor,
      codeStyle: codeStyle,
      cityStyle: cityStyle,
      labelStyle: labelStyle,
      titleStyle: titleStyle,
      subtitleStyle: subtitleStyle,
    );
  }

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

  late List<FlightRouteStop> _effectiveStops;
  late List<(double lat, double lng)> _resolvedCoords;

  static const List<String> _defaultSteps = [
    'Live fares',
    'Routes & layovers',
    'Best prices',
    'Ranking options',
  ];

  @override
  void initState() {
    super.initState();

    _normalizeStops();
    _resolveCoordinates();

    _animController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..repeat();

    _initStepTimer();
    _loadGeoData();
  }

  void _normalizeStops() {
    if (widget.stops != null && widget.stops!.isNotEmpty) {
      _effectiveStops = List<FlightRouteStop>.from(widget.stops!);
    } else {
      _effectiveStops = [
        FlightRouteStop(
          code: widget.fromCode,
          city: widget.fromCity,
          latitude: widget.fromLat,
          longitude: widget.fromLng,
          country: widget.fromCountry,
          countryCode: widget.fromCountryCode,
        ),
        FlightRouteStop(
          code: widget.toCode,
          city: widget.toCity,
          latitude: widget.toLat,
          longitude: widget.toLng,
          country: widget.toCountry,
          countryCode: widget.toCountryCode,
        ),
      ];
    }
  }

  void _resolveCoordinates() {
    _resolvedCoords = [];
    for (final stop in _effectiveStops) {
      final coords = AirportCoordinatesHelper.getCoordinates(
        stop.code,
        fallbackLat: stop.latitude,
        fallbackLng: stop.longitude,
        country: stop.country,
        countryCode: stop.countryCode,
      );
      _resolvedCoords.add((coords.$1, coords.$2));
    }
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
        oldWidget.stops != widget.stops ||
        oldWidget.tripType != widget.tripType ||
        oldWidget.fromLat != widget.fromLat ||
        oldWidget.fromLng != widget.fromLng ||
        oldWidget.toLat != widget.toLat ||
        oldWidget.toLng != widget.toLng) {
      _normalizeStops();
      _resolveCoordinates();
      _recomputePaths();
    }

    if (oldWidget.animationDuration != widget.animationDuration) {
      _animController.duration = widget.animationDuration;
    }
  }

  void _recomputePaths() {
    if (_countries == null || _lastSize == null || _lastSize!.width <= 0) return;
    if (_resolvedCoords.isEmpty) return;

    final Size size = _lastSize!;
    final List<Offset> pointsNorm = _resolvedCoords
        .map((c) => MapProjectionHelper.projectToMercator(c.$1, c.$2))
        .toList();

    final viewport = MapProjectionHelper.calculateViewportForPoints(
      canvasSize: size,
      pointsNorm: pointsNorm,
      paddingRatio: 0.35,
    );

    final List<Offset> stopScreenPositions =
        pointsNorm.map((p) => viewport.toScreen(p)).toList();

    final Offset startPoint = stopScreenPositions.first;
    final Offset endPoint = stopScreenPositions.last;

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

      if (country.name.isNotEmpty &&
          countryScreenBox.width > 60.0 &&
          countryScreenBox.height > 35.0 &&
          screenRect.contains(countryScreenBox.center)) {
        bool tooCloseToStop = false;
        for (final pos in stopScreenPositions) {
          if ((countryScreenBox.center - pos).distance <= 45.0) {
            tooCloseToStop = true;
            break;
          }
        }
        if (!tooCloseToStop) {
          visibleLabels.add((name: country.name, position: countryScreenBox.center));
        }
      }
    }

    // Build Flight Leg Paths
    final List<FlightLegPath> legs = [];

    if (widget.tripType == FlightTripType.roundTrip && stopScreenPositions.length >= 2) {
      final p0 = stopScreenPositions.first;
      final p1 = stopScreenPositions[1];

      // Leg 0: Outbound (arched upward)
      final outboundPath = MapProjectionHelper.createFlightArcPath(
        start: p0,
        end: p1,
        curveRatio: 0.22,
        invertCurvature: false,
      );
      final outboundMetrics = outboundPath.computeMetrics().toList();
      if (outboundMetrics.isNotEmpty) {
        legs.add(
          FlightLegPath(
            startPoint: p0,
            endPoint: p1,
            arcPath: outboundPath,
            arcMetric: outboundMetrics.first,
            isReturn: false,
            legIndex: 0,
          ),
        );
      }

      // Leg 1: Return (arched downward)
      final returnPath = MapProjectionHelper.createFlightArcPath(
        start: p1,
        end: p0,
        curveRatio: 0.22,
        invertCurvature: true,
      );
      final returnMetrics = returnPath.computeMetrics().toList();
      if (returnMetrics.isNotEmpty) {
        legs.add(
          FlightLegPath(
            startPoint: p1,
            endPoint: p0,
            arcPath: returnPath,
            arcMetric: returnMetrics.first,
            isReturn: true,
            legIndex: 1,
          ),
        );
      }
    } else if (widget.tripType == FlightTripType.multiCity && stopScreenPositions.length >= 2) {
      for (int i = 0; i < stopScreenPositions.length - 1; i++) {
        final pi = stopScreenPositions[i];
        final pNext = stopScreenPositions[i + 1];
        final legPath = MapProjectionHelper.createFlightArcPath(
          start: pi,
          end: pNext,
          curveRatio: 0.20,
        );
        final metrics = legPath.computeMetrics().toList();
        if (metrics.isNotEmpty) {
          legs.add(
            FlightLegPath(
              startPoint: pi,
              endPoint: pNext,
              arcPath: legPath,
              arcMetric: metrics.first,
              isReturn: false,
              legIndex: i,
            ),
          );
        }
      }
    } else {
      // One-way or fallback
      final flightArc = MapProjectionHelper.createFlightArcPath(
        start: startPoint,
        end: endPoint,
        curveRatio: 0.22,
      );
      final metrics = flightArc.computeMetrics().toList();
      if (metrics.isNotEmpty) {
        legs.add(
          FlightLegPath(
            startPoint: startPoint,
            endPoint: endPoint,
            arcPath: flightArc,
            arcMetric: metrics.first,
            isReturn: false,
            legIndex: 0,
          ),
        );
      }
    }

    if (legs.isEmpty) return;

    final primaryLeg = legs.first;

    _precomputed = MapPrecomputedPaths(
      size: size,
      countriesFillPath: fillPath,
      countriesStrokePath: strokePath,
      flightArcPath: primaryLeg.arcPath,
      arcMetric: primaryLeg.arcMetric,
      startPoint: startPoint,
      endPoint: endPoint,
      visibleLabels: visibleLabels,
      legs: legs,
      stopScreenPositions: stopScreenPositions,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final steps = widget.stepLabels ?? _defaultSteps;
    final activeStep = widget.currentStep ?? _internalStep;

    final String effectiveFromCity = _effectiveStops.first.city.isNotEmpty
        ? _effectiveStops.first.city
        : (_effectiveStops.first.code.isNotEmpty ? _effectiveStops.first.code : widget.fromCity);
    final String effectiveToCity = _effectiveStops.last.city.isNotEmpty
        ? _effectiveStops.last.city
        : (_effectiveStops.last.code.isNotEmpty ? _effectiveStops.last.code : widget.toCity);

    return Scaffold(
      body: Stack(
        children: [
          // ── 1. Vector Map Canvas ──
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final currentSize = constraints.biggest;
                if (_lastSize != currentSize) {
                  _lastSize = currentSize;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _recomputePaths());
                  });
                }

                return AnimatedBuilder(
                  animation: _animController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: FlightMapPainter(
                        precomputed: _precomputed,
                        animationProgress: _animController.value,
                        fromCode: _effectiveStops.first.code,
                        fromCity: effectiveFromCity,
                        toCode: _effectiveStops.last.code,
                        toCity: effectiveToCity,
                        stops: _effectiveStops,
                        tripType: widget.tripType,
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
                      size: Size.infinite,
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
                  child: _buildTopPill(isDark, effectiveFromCity, effectiveToCity),
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

  Widget _buildTopPill(bool isDark, String fromCity, String toCity) {
    IconData badgeIcon;
    Widget routeTitleWidget;
    String subtitleText;

    final titleStyle = widget.titleStyle ??
        TextStyle(
          fontSize: 14.0,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFFF4EFE6) : const Color(0xFF15201D),
          fontFamilyFallback: const ['Georgia', 'serif'],
        );

    if (widget.tripType == FlightTripType.roundTrip) {
      badgeIcon = Icons.sync_alt_rounded;
      subtitleText = widget.subtitle ?? 'ROUND TRIP • Outbound & return flight fares';
      routeTitleWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              fromCity,
              style: titleStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Icon(
              Icons.swap_horiz_rounded,
              size: 16.0,
              color: widget.brandColor,
            ),
          ),
          Flexible(
            child: Text(
              toCity,
              style: titleStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else if (widget.tripType == FlightTripType.multiCity && _effectiveStops.length > 2) {
      badgeIcon = Icons.alt_route_rounded;
      subtitleText = widget.subtitle ??
          'MULTI-CITY • Scanning ${_effectiveStops.length - 1} flight routes';

      if (_effectiveStops.length == 3) {
        routeTitleWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(_effectiveStops[0].city, style: titleStyle, overflow: TextOverflow.ellipsis)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Icon(Icons.arrow_forward_rounded, size: 12.0, color: widget.brandColor),
            ),
            Flexible(child: Text(_effectiveStops[1].city, style: titleStyle, overflow: TextOverflow.ellipsis)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Icon(Icons.arrow_forward_rounded, size: 12.0, color: widget.brandColor),
            ),
            Flexible(child: Text(_effectiveStops[2].city, style: titleStyle, overflow: TextOverflow.ellipsis)),
          ],
        );
      } else {
        routeTitleWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(_effectiveStops.first.city, style: titleStyle, overflow: TextOverflow.ellipsis)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Icon(Icons.arrow_forward_rounded, size: 12.0, color: widget.brandColor),
            ),
            Flexible(child: Text(_effectiveStops[1].city, style: titleStyle, overflow: TextOverflow.ellipsis)),
            Padding(
              padding: const EdgeInsets.only(left: 6.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.5),
                decoration: BoxDecoration(
                  color: widget.brandColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Text(
                  '+${_effectiveStops.length - 2} stops',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: widget.brandColor,
                  ),
                ),
              ),
            ),
          ],
        );
      }
    } else {
      badgeIcon = Icons.flight_takeoff_rounded;
      subtitleText = widget.subtitle ?? 'Scanning airlines for live fares...';
      routeTitleWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              fromCity,
              style: titleStyle,
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
              toCity,
              style: titleStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

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
          // Circular Badge
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
              badgeIcon,
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
                routeTitleWidget,
                const SizedBox(height: 1.5),
                Text(
                  subtitleText,
                  style: widget.subtitleStyle ??
                      TextStyle(
                        fontSize: 11.0,
                        color: isDark
                            ? const Color(0xFF909090)
                            : const Color(0xFF7B8884),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.0,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                );
              } else {
                circleBg = isDark ? const Color(0xFF282828) : const Color(0xFFEDE6D7);
                circleContent = Text(
                  '${stepIdx + 1}',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF909090)
                        : const Color(0xFF7B8884),
                    fontSize: 11.0,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
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
                  style: TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFF4EFE6)
                        : const Color(0xFF15201D),
                  ),
                ),
              ),
              Text(
                'Step ${clampedStep + 1} / ${steps.length}',
                style: TextStyle(
                  fontSize: 11.0,
                  color: widget.brandColor,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
