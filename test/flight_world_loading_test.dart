import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flight_world_loading/flight_world_loading.dart';

void main() {
  group('MapProjectionHelper Tests', () {
    test('projectToMercator normalizes coordinates within [0.0..1.0]', () {
      final center = MapProjectionHelper.projectToMercator(0.0, 0.0);
      expect(center.dx, closeTo(0.5, 0.001));
      expect(center.dy, closeTo(0.5, 0.001));

      final dhaka = MapProjectionHelper.projectToMercator(23.8433, 90.3978);
      expect(dhaka.dx, greaterThan(0.5));
      expect(dhaka.dx, lessThan(1.0));
      expect(dhaka.dy, greaterThan(0.0));
      expect(dhaka.dy, lessThan(0.5));

      final clamped = MapProjectionHelper.projectToMercator(90.0, 200.0);
      expect(clamped.dx, inInclusiveRange(0.0, 1.0));
      expect(clamped.dy, inInclusiveRange(0.0, 1.0));
    });

    test('calculateViewport scales appropriately for short and long routes', () {
      const canvasSize = Size(400.0, 800.0);
      final p1 = MapProjectionHelper.projectToMercator(23.8433, 90.3978); // DAC
      final p2 = MapProjectionHelper.projectToMercator(21.4522, 91.9639); // CXB
      final p3 = MapProjectionHelper.projectToMercator(40.6413, -73.7781); // JFK

      final domestic = MapProjectionHelper.calculateViewport(
        canvasSize: canvasSize,
        p1Norm: p1,
        p2Norm: p2,
      );

      final intercontinental = MapProjectionHelper.calculateViewport(
        canvasSize: canvasSize,
        p1Norm: p1,
        p2Norm: p3,
      );

      expect(domestic.scale, greaterThan(intercontinental.scale));

      final s1 = domestic.toScreen(p1);
      final s2 = domestic.toScreen(p2);
      expect(s1.dx.isFinite, isTrue);
      expect(s1.dy.isFinite, isTrue);
      expect(s2.dx.isFinite, isTrue);
      expect(s2.dy.isFinite, isTrue);
    });

    test('createFlightArcPath builds a curved Bezier path upward', () {
      const start = Offset(100.0, 300.0);
      const end = Offset(300.0, 300.0);

      final path = MapProjectionHelper.createFlightArcPath(start: start, end: end);
      final metrics = path.computeMetrics().toList();

      expect(metrics.isNotEmpty, isTrue);
      expect(metrics.first.length, greaterThan(200.0));
    });
  });

  group('AirportCoordinatesHelper Tests', () {
    tearDown(() {
      AirportCoordinatesHelper.clearCustomRegistrations();
    });

    test('resolves explicit coordinates when provided', () {
      final coords = AirportCoordinatesHelper.getCoordinates(
        'UNKNOWN',
        fallbackLat: 12.345,
        fallbackLng: 67.890,
      );
      expect(coords.$1, equals(12.345));
      expect(coords.$2, equals(67.890));
    });

    test('resolves built-in major airport hubs', () {
      final dac = AirportCoordinatesHelper.getCoordinates('DAC');
      expect(dac.$1, closeTo(23.8433, 0.01));
      expect(dac.$2, closeTo(90.3978, 0.01));

      final jfk = AirportCoordinatesHelper.getCoordinates('JFK');
      expect(jfk.$1, closeTo(40.6413, 0.01));
      expect(jfk.$2, closeTo(-73.7781, 0.01));

      final lhr = AirportCoordinatesHelper.getCoordinates('LHR');
      expect(lhr.$1, closeTo(51.4700, 0.01));
      expect(lhr.$2, closeTo(-0.4543, 0.01));
    });

    test('resolves custom registered airports and resolvers', () {
      AirportCoordinatesHelper.registerAirport('MYA', 35.0, 139.0);
      final mya = AirportCoordinatesHelper.getCoordinates('MYA');
      expect(mya.$1, equals(35.0));
      expect(mya.$2, equals(139.0));

      AirportCoordinatesHelper.registerCustomResolver((code) {
        if (code == 'DYN') return (10.0, 20.0);
        return null;
      });

      final dyn = AirportCoordinatesHelper.getCoordinates('DYN');
      expect(dyn.$1, equals(10.0));
      expect(dyn.$2, equals(20.0));
    });

    test('resolves country centroid with dispersion for unknown airport codes', () {
      final coords1 = AirportCoordinatesHelper.getCoordinates(
        'XYZ',
        countryCode: 'US',
      );
      final coords2 = AirportCoordinatesHelper.getCoordinates(
        'ABC',
        countryCode: 'US',
      );

      // Both should be in US approximate region
      expect(coords1.$1, closeTo(39.8, 3.0));
      expect(coords1.$2, closeTo(-98.5, 4.0));

      // Different codes should disperse and not collide
      expect(coords1.$1, isNot(equals(coords2.$1)));
      expect(coords1.$2, isNot(equals(coords2.$2)));
    });

    test('resolves deterministic fallback for unknown codes without crashing', () {
      final coords = AirportCoordinatesHelper.getCoordinates('FOO');
      expect(coords.$1.isFinite, isTrue);
      expect(coords.$2.isFinite, isTrue);
    });
  });

  group('Airport and AirportService Tests', () {
    tearDown(() {
      AirportService.clear();
    });

    test('Airport model serializes and deserializes cleanly', () {
      const airport = Airport(
        code: 'DXB',
        name: 'Dubai International Airport',
        city: 'Dubai',
        country: 'United Arab Emirates',
        countryCode: 'AE',
        latitude: 25.2532,
        longitude: 55.3657,
      );

      final json = airport.toJson();
      final fromJson = Airport.fromJson(json);

      expect(fromJson.code, equals('DXB'));
      expect(fromJson.city, equals('Dubai'));
      expect(fromJson.latitude, closeTo(25.2532, 0.001));
      expect(fromJson.longitude, closeTo(55.3657, 0.001));
    });

    test('AirportService registers and searches airports', () {
      const airport = Airport(
        code: 'SIN',
        name: 'Singapore Changi Airport',
        city: 'Singapore',
        country: 'Singapore',
        countryCode: 'SG',
        latitude: 1.3644,
        longitude: 103.9915,
      );

      AirportService.registerAirport(airport);
      expect(AirportService.getAirportByCode('SIN')?.city, equals('Singapore'));

      final searchResults = AirportService.search('changi');
      expect(searchResults.length, equals(1));
      expect(searchResults.first.code, equals('SIN'));
    });
  });

  group('FlightRouteLoader Widget Tests', () {
    testWidgets('renders flight route loader with top pill and step bar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FlightRouteLoader(
            fromCode: 'DAC',
            fromCity: 'Dhaka',
            fromLat: 23.8433,
            fromLng: 90.3978,
            toCode: 'CXB',
            toCity: "Cox's Bazar",
            toLat: 21.4522,
            toLng: 91.9639,
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Dhaka'), findsWidgets);
      expect(find.text("Cox's Bazar"), findsWidgets);
      expect(find.text('Live fares'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('supports cancel callback and manual step control', (tester) async {
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: FlightRouteLoader(
            fromCode: 'LHR',
            fromCity: 'London',
            toCode: 'JFK',
            toCity: 'New York',
            currentStep: 2,
            stepLabels: const ['A', 'B', 'C', 'D'],
            onCancel: () => cancelled = true,
          ),
        ),
      );

      await tester.pump();

      expect(find.text('C'), findsOneWidget);
      expect(find.text('Step 3 / 4'), findsOneWidget);

      final closeBtn = find.byTooltip('Cancel Search');
      expect(closeBtn, findsOneWidget);

      await tester.tap(closeBtn);
      expect(cancelled, isTrue);
    });

    testWidgets('renders roundTrip route with bidirectional indicators and stops', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FlightRouteLoader.roundTrip(
            from: const FlightRouteStop(code: 'DAC', city: 'Dhaka', latitude: 23.8433, longitude: 90.3978),
            to: const FlightRouteStop(code: 'CXB', city: "Cox's Bazar", latitude: 21.4522, longitude: 91.9639),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Dhaka'), findsWidgets);
      expect(find.text("Cox's Bazar"), findsWidgets);
      expect(find.byIcon(Icons.sync_alt_rounded), findsOneWidget);
      expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
      expect(find.textContaining('ROUND TRIP'), findsOneWidget);
    });

    testWidgets('renders multiCity route with 3 stops and route indicators', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FlightRouteLoader.multiCity(
            stops: const [
              FlightRouteStop(code: 'DAC', city: 'Dhaka', latitude: 23.8433, longitude: 90.3978),
              FlightRouteStop(code: 'DXB', city: 'Dubai', latitude: 25.2532, longitude: 55.3657),
              FlightRouteStop(code: 'LHR', city: 'London', latitude: 51.4700, longitude: -0.4543),
            ],
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Dhaka'), findsWidgets);
      expect(find.text('Dubai'), findsWidgets);
      expect(find.text('London'), findsWidgets);
      expect(find.byIcon(Icons.alt_route_rounded), findsOneWidget);
      expect(find.textContaining('MULTI-CITY'), findsOneWidget);
    });

    testWidgets('renders FlightRouteLoader.fromAirports directly from Airport models', (tester) async {
      const jfk = Airport(
        code: 'JFK',
        name: 'John F. Kennedy',
        city: 'New York',
        country: 'United States',
        latitude: 40.6413,
        longitude: -73.7781,
      );
      const lhr = Airport(
        code: 'LHR',
        name: 'Heathrow',
        city: 'London',
        country: 'United Kingdom',
        latitude: 51.4700,
        longitude: -0.4543,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FlightRouteLoader.fromAirports(
            airports: const [jfk, lhr],
            tripType: FlightTripType.roundTrip,
          ),
        ),
      );

      await tester.pump();

      expect(find.text('New York'), findsWidgets);
      expect(find.text('London'), findsWidgets);
      expect(find.byIcon(Icons.sync_alt_rounded), findsOneWidget);
    });

    testWidgets('renders FlightRouteLoader with custom text styles and without GoogleFonts dependency', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FlightRouteLoader(
            fromCode: 'DAC',
            fromCity: 'Dhaka',
            toCode: 'JFK',
            toCity: 'New York',
            subtitle: 'Searching 200+ flights...',
            titleStyle: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w800, color: Colors.amber),
            subtitleStyle: const TextStyle(fontSize: 12.0, color: Colors.blueGrey),
            codeStyle: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
            cityStyle: const TextStyle(fontSize: 11.0, fontStyle: FontStyle.italic),
            labelStyle: const TextStyle(fontSize: 8.0, letterSpacing: 1.0),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Dhaka'), findsWidgets);
      expect(find.text('New York'), findsWidgets);
      expect(find.text('Searching 200+ flights...'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('Multi-point Viewport & RouteStop Model Tests', () {
    test('calculateViewportForPoints encloses 3 or more points safely', () {
      const canvasSize = Size(400.0, 800.0);
      final p1 = MapProjectionHelper.projectToMercator(23.8433, 90.3978); // DAC
      final p2 = MapProjectionHelper.projectToMercator(25.2532, 55.3657); // DXB
      final p3 = MapProjectionHelper.projectToMercator(51.4700, -0.4543); // LHR

      final viewport = MapProjectionHelper.calculateViewportForPoints(
        canvasSize: canvasSize,
        pointsNorm: [p1, p2, p3],
      );

      expect(viewport.scale.isFinite, isTrue);
      expect(viewport.scale, greaterThan(0.0));

      final s1 = viewport.toScreen(p1);
      final s2 = viewport.toScreen(p2);
      final s3 = viewport.toScreen(p3);

      expect(s1.dx.isFinite, isTrue);
      expect(s2.dx.isFinite, isTrue);
      expect(s3.dx.isFinite, isTrue);
    });

    test('createFlightArcPath with invertCurvature creates inverted path', () {
      const start = Offset(100.0, 300.0);
      const end = Offset(300.0, 300.0);

      final normalArc = MapProjectionHelper.createFlightArcPath(start: start, end: end, invertCurvature: false);
      final invertedArc = MapProjectionHelper.createFlightArcPath(start: start, end: end, invertCurvature: true);

      final boundsNormal = normalArc.getBounds();
      final boundsInverted = invertedArc.getBounds();

      expect(boundsNormal.top, lessThan(boundsInverted.top));
    });

    test('FlightRouteStop converts cleanly to and from Airport', () {
      const airport = Airport(
        code: 'SIN',
        name: 'Changi',
        city: 'Singapore',
        country: 'Singapore',
        countryCode: 'SG',
        latitude: 1.3644,
        longitude: 103.9915,
      );

      final stop = FlightRouteStop.fromAirport(airport);
      expect(stop.code, equals('SIN'));
      expect(stop.city, equals('Singapore'));
      expect(stop.latitude, equals(1.3644));
      expect(stop.longitude, equals(103.9915));

      final convertedBack = stop.toAirport();
      expect(convertedBack.code, equals('SIN'));
      expect(convertedBack.city, equals('Singapore'));
    });
  });
}
