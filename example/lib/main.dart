import 'package:flutter/material.dart';
import 'package:flight_world_loading/flight_world_loading.dart';

void main() {
  runApp(const FlightLoaderExampleApp());
}

class FlightLoaderExampleApp extends StatefulWidget {
  const FlightLoaderExampleApp({super.key});

  @override
  State<FlightLoaderExampleApp> createState() => _FlightLoaderExampleAppState();
}

class _FlightLoaderExampleAppState extends State<FlightLoaderExampleApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flight World Loading Demo',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F4A3F),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F4A3F),
          brightness: Brightness.dark,
        ),
      ),
      home: DemoHomeScreen(
        onToggleTheme: _toggleTheme,
        isDark: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class DemoRouteItem {
  final String title;
  final String subtitle;
  final FlightTripType tripType;
  final List<FlightRouteStop>? stops;
  final List<Airport>? airports;
  final String fromCode;
  final String fromCity;
  final String toCode;
  final String toCity;
  final double? fromLat;
  final double? fromLng;
  final double? toLat;
  final double? toLng;
  final Color brandColor;

  const DemoRouteItem({
    required this.title,
    required this.subtitle,
    this.tripType = FlightTripType.oneWay,
    this.stops,
    this.airports,
    this.fromCode = '',
    this.fromCity = '',
    this.toCode = '',
    this.toCity = '',
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
    this.brandColor = const Color(0xFF1F4A3F),
  });
}

class DemoHomeScreen extends StatelessWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const DemoHomeScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  static const List<DemoRouteItem> demoRoutes = [
    DemoRouteItem(
      title: 'Round-Trip Flight (Outbound & Return)',
      subtitle: 'Dhaka (DAC) ⇄ Cox\'s Bazar (CXB)',
      tripType: FlightTripType.roundTrip,
      fromCode: 'DAC',
      fromCity: 'Dhaka',
      fromLat: 23.8433,
      fromLng: 90.3978,
      toCode: 'CXB',
      toCity: "Cox's Bazar",
      toLat: 21.4522,
      toLng: 91.9639,
      brandColor: Color(0xFF1F4A3F),
    ),
    DemoRouteItem(
      title: 'Multi-City Flight (3 Itinerary Legs)',
      subtitle: 'Dhaka (DAC) ➔ Dubai (DXB) ➔ London (LHR)',
      tripType: FlightTripType.multiCity,
      stops: [
        FlightRouteStop(
          code: 'DAC',
          city: 'Dhaka',
          latitude: 23.8433,
          longitude: 90.3978,
        ),
        FlightRouteStop(
          code: 'DXB',
          city: 'Dubai',
          latitude: 25.2532,
          longitude: 55.3657,
        ),
        FlightRouteStop(
          code: 'LHR',
          city: 'London',
          latitude: 51.4700,
          longitude: -0.4543,
        ),
      ],
      brandColor: Color(0xFF0D5C75),
    ),
    DemoRouteItem(
      title: 'Multi-City Global Tour (4 Stops)',
      subtitle: 'London (LHR) ➔ Dubai (DXB) ➔ Singapore (SIN) ➔ Tokyo (HND)',
      tripType: FlightTripType.multiCity,
      stops: [
        FlightRouteStop(code: 'LHR', city: 'London'),
        FlightRouteStop(code: 'DXB', city: 'Dubai'),
        FlightRouteStop(code: 'SIN', city: 'Singapore'),
        FlightRouteStop(code: 'HND', city: 'Tokyo'),
      ],
      brandColor: Color(0xFF7A2021),
    ),
    DemoRouteItem(
      title: 'Airport Model Direct Input',
      subtitle: 'Direct Airport instances without unpacking properties',
      tripType: FlightTripType.roundTrip,
      airports: [
        Airport(
          code: 'JFK',
          name: 'John F. Kennedy International Airport',
          city: 'New York',
          country: 'United States',
          latitude: 40.6413,
          longitude: -73.7781,
        ),
        Airport(
          code: 'LHR',
          name: 'London Heathrow Airport',
          city: 'London',
          country: 'United Kingdom',
          latitude: 51.4700,
          longitude: -0.4543,
        ),
      ],
      brandColor: Color(0xFF2E4057),
    ),
    DemoRouteItem(
      title: 'One-Way Domestic Hop',
      subtitle: 'Dhaka (DAC) ➔ Cox\'s Bazar (CXB)',
      tripType: FlightTripType.oneWay,
      fromCode: 'DAC',
      fromCity: 'Dhaka',
      fromLat: 23.8433,
      fromLng: 90.3978,
      toCode: 'CXB',
      toCity: "Cox's Bazar",
      toLat: 21.4522,
      toLng: 91.9639,
      brandColor: Color(0xFF1F4A3F),
    ),
    DemoRouteItem(
      title: 'One-Way Asia-Pacific Route',
      subtitle: 'Dubai (DXB) ➔ Singapore (SIN)',
      tripType: FlightTripType.oneWay,
      fromCode: 'DXB',
      fromCity: 'Dubai',
      toCode: 'SIN',
      toCity: 'Singapore',
      brandColor: Color(0xFF5A3E1B),
    ),
  ];

  void _openLoader(BuildContext context, DemoRouteItem route) {
    Widget loaderWidget;

    if (route.airports != null && route.airports!.isNotEmpty) {
      loaderWidget = FlightRouteLoader.fromAirports(
        airports: route.airports!,
        tripType: route.tripType,
        brandColor: route.brandColor,
        onCancel: () => Navigator.pop(context),
      );
    } else if (route.stops != null && route.stops!.isNotEmpty) {
      if (route.tripType == FlightTripType.multiCity) {
        loaderWidget = FlightRouteLoader.multiCity(
          stops: route.stops!,
          brandColor: route.brandColor,
          onCancel: () => Navigator.pop(context),
        );
      } else if (route.tripType == FlightTripType.roundTrip) {
        loaderWidget = FlightRouteLoader.roundTrip(
          from: route.stops!.first,
          to: route.stops!.last,
          brandColor: route.brandColor,
          onCancel: () => Navigator.pop(context),
        );
      } else {
        loaderWidget = FlightRouteLoader.oneWay(
          from: route.stops!.first,
          to: route.stops!.last,
          brandColor: route.brandColor,
          onCancel: () => Navigator.pop(context),
        );
      }
    } else {
      loaderWidget = FlightRouteLoader(
        tripType: route.tripType,
        fromCode: route.fromCode,
        fromCity: route.fromCity,
        fromLat: route.fromLat,
        fromLng: route.fromLng,
        toCode: route.toCode,
        toCity: route.toCity,
        toLat: route.toLat,
        toLng: route.toLng,
        brandColor: route.brandColor,
        onCancel: () => Navigator.pop(context),
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => loaderWidget),
    );
  }

  IconData _iconForTripType(FlightTripType tripType) {
    switch (tripType) {
      case FlightTripType.roundTrip:
        return Icons.sync_alt_rounded;
      case FlightTripType.multiCity:
        return Icons.alt_route_rounded;
      case FlightTripType.oneWay:
        return Icons.flight_takeoff_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flight World Loading'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            tooltip: 'Toggle Theme',
            onPressed: onToggleTheme,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        children: [
          Text(
            'Interactive Route Demos',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6.0),
          Text(
            'Preview offline vector map loading screens with adaptive zoom for One-Way, Round-Trip, and Multi-City routes.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20.0),
          ...demoRoutes.map(
            (route) => Card(
              margin: const EdgeInsets.only(bottom: 14.0),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16.0),
                onTap: () => _openLoader(context, route),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 44.0,
                        height: 44.0,
                        decoration: BoxDecoration(
                          color: route.brandColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _iconForTripType(route.tripType),
                          color: route.brandColor,
                          size: 22.0,
                        ),
                      ),
                      const SizedBox(width: 14.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              route.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2.0),
                            Text(
                              route.subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
