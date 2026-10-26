# flight_world_loading

[![Pub Version](https://img.shields.io/pub/v/flight_world_loading?color=1F4A3F)](https://pub.dev/packages/flight_world_loading)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter Platform](https://img.shields.io/badge/Flutter-All%20Platforms-green.svg)](https://flutter.dev)

A high-performance, offline vector map flight search loading screen for Flutter that draws an animated flight trajectory across a lightweight world map with adaptive camera zoom, collision-safe airport cards, and tangent-aligned airplane motion.

---

## Features

- 🌍 **100% Offline Vector Landmasses**: Bundled with a lightweight Natural Earth low-resolution GeoJSON dataset (`~110m` boundary polygons), requiring **zero network requests, zero map API keys, and zero tile servers**.
- 🔍 **Adaptive Viewport Zoom**:
  - Automatically zooms in close for short domestic hops (e.g. `DAC ⇄ CXB`, `JFK ⇄ BOS`, `LHR ⇄ MAN`) with generous margins so country boundaries fill the screen.
  - Smoothly pulls back for intercontinental flights (e.g. `DAC ⇄ JFK`, `LHR ⇄ HND`, `DXB ⇄ SIN`) to present the full hemisphere or globe.
- ✈️ **60fps Tangent-Aligned Flight Motion**: An upward quadratic Bezier arc connects origin and destination. An airplane icon traverses the curve at 60fps, rotating continuously to match the path's exact tangent angle.
- 🏷️ **Collision-Free Airport Cards**: Floating IATA cards with city names dynamically arrange themselves above/below pins and clamp within screen margins to eliminate text collisions on short-haul domestic hops.
- 🌐 **Global Airport Resolution (8-Tier Fallback)**:
  - Resolves 160+ top international hubs directly from built-in high-precision coordinates.
  - Automatically resolves country centroids (~240 countries/territories) with deterministic dispersion for unknown airports in the same country.
  - Supports registering custom airport databases or dynamic resolver callbacks.
  - Never crashes: unknown or fictitious codes resolve gracefully without overlapping.
- 🎨 **Pure Vanilla Flutter (Zero Third-Party Dependencies)**: Requires **no third-party runtime packages** (no `google_fonts`, no `GetX`, no `ScreenUtil`), preventing any dependency solver or version conflicts with host applications. Fully compatible with Material 3, light/dark themes, and custom typography overrides.

---

## Getting Started

Add `flight_world_loading` to your `pubspec.yaml`:

```yaml
dependencies:
  flight_world_loading: ^0.0.2
```

Import it in your Dart code:

```dart
import 'package:flight_world_loading/flight_world_loading.dart';
```

---

## Quick Start

### 1. Minimal Invocation (Auto-Resolved Coordinates)

You don't need to manually look up latitude and longitude for common airports:

```dart
import 'package:flutter/material.dart';
import 'package:flight_world_loading/flight_world_loading.dart';

class FlightSearchLoadingScreen extends StatelessWidget {
  const FlightSearchLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FlightRouteLoader(
      fromCode: 'DAC',
      fromCity: 'Dhaka',
      toCode: 'JFK',
      toCity: 'New York',
    );
  }
}
```

---

### 2. Round-Trip Itinerary (Outbound & Return Trajectories)

Render dual animated trajectory arcs (outbound and return) with bidirectional header indicators:

```dart
FlightRouteLoader.roundTrip(
  from: const FlightRouteStop(code: 'DAC', city: 'Dhaka'),
  to: const FlightRouteStop(code: 'CXB', city: "Cox's Bazar"),
  brandColor: const Color(0xFF1F4A3F),
  onCancel: () => Navigator.pop(context),
)
```

---

### 3. Multi-City Itinerary (3+ Stops)

Frame all stops on the world map and animate the airplane sequentially across each leg:

```dart
FlightRouteLoader.multiCity(
  stops: const [
    FlightRouteStop(code: 'DAC', city: 'Dhaka'),
    FlightRouteStop(code: 'DXB', city: 'Dubai'),
    FlightRouteStop(code: 'LHR', city: 'London'),
  ],
  brandColor: const Color(0xFF0D5C75),
)
```

---

### 4. Direct Airport Models

Pass your existing `Airport` models directly without manual parameter unpacking:

```dart
final List<Airport> mySelectedAirports = [
  Airport(code: 'JFK', name: 'John F. Kennedy', city: 'New York', country: 'United States'),
  Airport(code: 'LHR', name: 'Heathrow', city: 'London', country: 'United Kingdom'),
];

FlightRouteLoader.fromAirports(
  airports: mySelectedAirports,
  tripType: FlightTripType.roundTrip,
)
```

---

### 5. High-Precision Explicit Coordinates

If your flight search API provides coordinates, pass them directly for exact positioning:

```dart
FlightRouteLoader(
  fromCode: 'DAC',
  fromCity: 'Dhaka',
  fromLat: 23.8433,
  fromLng: 90.3978,
  toCode: 'CXB',
  toCity: "Cox's Bazar",
  toLat: 21.4522,
  toLng: 91.9639,
  brandColor: const Color(0xFF1F4A3F),
  subtitle: 'ROUND TRIP • 1 PASSENGER',
  onCancel: () => Navigator.pop(context),
)
```

---

## Async Search Flow Integration

Show the animated loader while executing your backend API call, guaranteeing a minimum animation duration to prevent screen flash:

```dart
Future<void> runFlightSearch(BuildContext context) async {
  // 1. Open the animated loader screen
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => FlightRouteLoader(
        fromCode: 'LHR',
        fromCity: 'London',
        toCode: 'HND',
        toCity: 'Tokyo',
        onCancel: () => Navigator.pop(context),
      ),
    ),
  );

  try {
    // 2. Fetch fares in parallel with a minimum display duration (e.g. 3.5s)
    final results = await Future.wait([
      fetchFlightFaresApi(),
      Future.delayed(const Duration(milliseconds: 3500)),
    ]);

    // 3. Navigate to results screen
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => FlightResultsScreen(data: results.first),
        ),
      );
    }
  } catch (error) {
    if (context.mounted) Navigator.pop(context);
    showErrorDialog(context, error);
  }
}
```

---

## Worldwide Airport Resolution

`flight_world_loading` handles airports worldwide through a resilient 8-tier resolution system:

1. **Direct Coordinates**: `fromLat`/`fromLng` and `toLat`/`toLng`.
2. **Custom Registered Resolver**: Register your app's existing airport database or dynamic callback:
   ```dart
   // Register individual coordinates
   AirportCoordinatesHelper.registerAirport('MYA', 35.0, 139.0);

   // Or register a dynamic resolver
   AirportCoordinatesHelper.registerCustomResolver((code) {
     final airport = myAppDatabase.findByCode(code);
     if (airport != null) return (airport.lat, airport.lng);
     return null;
   });
   ```
3. **In-Memory AirportService**: Bulk register `Airport` models from JSON or an API response:
   ```dart
   AirportService.registerAirports([
     Airport(
       code: 'SIN',
       name: 'Singapore Changi Airport',
       city: 'Singapore',
       country: 'Singapore',
       countryCode: 'SG',
       latitude: 1.3644,
       longitude: 103.9915,
     ),
   ]);
   ```
4. **Built-in Global Hubs**: 160+ major worldwide airports (North America, Europe, Asia, Middle East, Africa, Oceania, South America) built directly into code for instant $O(1)$ lookups.
5. **Country Centroids with Dispersion**: If only the country is known (or inferred from code), centers on the country (~240 countries/territories) and deterministically disperses coordinates so multiple unknown airports in the same country never overlap.
6. **Dynamic Vector Centroid**: Direct bounding-box centroid calculation from the bundled GeoJSON map.
7. **Global Deterministic Placement**: Hash-based positioning that guarantees two unknown airport codes never collide.

---

## Customization & Properties

| Property | Type | Default | Description |
|---|---|---|---|
| `fromCode` | `String` | *(Required)* | 3-letter IATA origin code (e.g. `'DAC'`, `'JFK'`) |
| `fromCity` | `String` | *(Required)* | Origin city name displayed on card |
| `fromLat` / `fromLng` | `double?` | `null` (auto-resolved) | Optional origin latitude & longitude |
| `fromCountry` / `fromCountryCode` | `String?` | `null` | Optional country info for centroid fallback |
| `toCode` | `String` | *(Required)* | 3-letter IATA destination code (e.g. `'LHR'`) |
| `toCity` | `String` | *(Required)* | Destination city name displayed on card |
| `toLat` / `toLng` | `double?` | `null` (auto-resolved) | Optional destination latitude & longitude |
| `toCountry` / `toCountryCode` | `String?` | `null` | Optional country info for centroid fallback |
| `brandColor` | `Color` | `Color(0xFF1F4A3F)` | Color of route trajectory arc, plane, and pins |
| `stepLabels` | `List<String>?` | 4 flight search steps | Sequential messages in the bottom progress card |
| `currentStep` | `int?` | `null` (auto-timed) | Explicit step index if driven externally |
| `stepDuration` | `Duration` | `1400ms` | Interval between step advances when auto-timed |
| `subtitle` | `String?` | `'Scanning airlines...'` | Top header subtitle text |
| `onCancel` | `VoidCallback?` | `null` | Callback for top cancel button affordance |
| `showTopPill` | `bool` | `true` | Whether to render the floating top route header |
| `showBottomStepBar` | `bool` | `true` | Whether to render the bottom progress bar |
| `animationDuration` | `Duration` | `2500ms` | Duration of each flight trajectory loop |
| `waterColor` | `Color?` | Light/Dark adaptive | Background ocean wash color override |
| `landColor` | `Color?` | Light/Dark adaptive | Landmass fill color override |
| `borderColor` | `Color?` | Light/Dark adaptive | Country boundary stroke color override |
| `cardBackgroundColor` | `Color?` | Light/Dark adaptive | Floating airport card background override |
| `cardBorderColor` | `Color?` | Light/Dark adaptive | Floating airport card border override |
| `codeStyle` | `TextStyle?` | JetBrains Mono bold | Custom typography for IATA codes |
| `cityStyle` | `TextStyle?` | Fraunces serif semi-bold | Custom typography for city names |
| `labelStyle` | `TextStyle?` | Plus Jakarta Sans | Custom typography for country names |

---

## Palette Tokens

| Element | Light Mode | Dark Mode |
|---|---|---|
| **Water Background** | `#E2EBE7` (Soft botanical mist wash) | `#131A18` (Deep forest midnight) |
| **Landmass Fill** | `#FAF7F1` (Warm organic parchment) | `#1E2824` (Muted spruce slate) |
| **Landmass Borders** | `#E5DECF` (Muted contour stroke) | `#2C3B36` (Subtle boundary stroke) |
| **Default Brand** | `#1F4A3F` (Deep botanical moss) | `#1F4A3F` (Deep botanical moss) |

---

## Example App

Check out the [`example/`](example/) directory for an interactive demo showcasing domestic hops, transatlantic routes, and intercontinental long-haul flights with light and dark mode toggles.

To run the example app:

```bash
cd example
flutter run
```

---

## Contributing

Contributions, issues, and feature requests are welcome! Feel free to open an issue or pull request on [GitHub](https://github.com/MontasirOpi/flight_world_loading-package).

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
