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
    required this.fromCode,
    required this.fromCity,
    required this.toCode,
    required this.toCity,
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
      title: 'Domestic Hop (Adaptive Close Zoom)',
      subtitle: 'Dhaka (DAC) ➔ Cox\'s Bazar (CXB)',
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
      title: 'Transatlantic Flight',
      subtitle: 'New York (JFK) ➔ London (LHR)',
      fromCode: 'JFK',
      fromCity: 'New York',
      toCode: 'LHR',
      toCity: 'London',
      brandColor: Color(0xFF0D5C75),
    ),
    DemoRouteItem(
      title: 'Global Long-Haul (Full Hemisphere)',
      subtitle: 'London (LHR) ➔ Tokyo (HND)',
      fromCode: 'LHR',
      fromCity: 'London',
      toCode: 'HND',
      toCity: 'Tokyo',
      brandColor: Color(0xFF7A2021),
    ),
    DemoRouteItem(
      title: 'Asia-Pacific Regional Route',
      subtitle: 'Dubai (DXB) ➔ Singapore (SIN)',
      fromCode: 'DXB',
      fromCity: 'Dubai',
      toCode: 'SIN',
      toCity: 'Singapore',
      brandColor: Color(0xFF5A3E1B),
    ),
    DemoRouteItem(
      title: 'Auto Coordinate Fallback Resolution',
      subtitle: 'Unknown Airport Codes with Country Centroid',
      fromCode: 'DAC',
      fromCity: 'Dhaka',
      toCode: 'BNE',
      toCity: 'Brisbane',
      brandColor: Color(0xFF2E4057),
    ),
  ];

  void _openLoader(BuildContext context, DemoRouteItem route) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FlightRouteLoader(
          fromCode: route.fromCode,
          fromCity: route.fromCity,
          fromLat: route.fromLat,
          fromLng: route.fromLng,
          toCode: route.toCode,
          toCity: route.toCity,
          toLat: route.toLat,
          toLng: route.toLng,
          brandColor: route.brandColor,
          subtitle: 'ROUND TRIP • 1 PASSENGER',
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
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
            'Tap any route below to preview offline vector map flight animations with adaptive zoom scaling.',
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
                          Icons.flight_takeoff_rounded,
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
