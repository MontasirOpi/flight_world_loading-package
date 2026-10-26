## 0.0.2

* Removed third-party `google_fonts` runtime dependency: `flight_world_loading` now has **zero third-party dependencies** (depends only on Flutter SDK), preventing version conflicts with any host application packages.
* Replaced direct `GoogleFonts` calls with native `TextStyle` and robust font family fallbacks (monospace for flight numbers/stats, serif/sans-serif for labels).
* Added optional `titleStyle` and `subtitleStyle` parameters to `FlightRouteLoader` and all its factory constructors (`oneWay`, `roundTrip`, `multiCity`, `fromAirports`), allowing host apps to supply custom typography.

## 0.0.1

* Initial release of `flight_world_loading`.
* High-performance, offline vector world map rendering from bundled Natural Earth boundaries.
* Dynamic distance-based camera zoom (close margins for domestic hops, global framing for intercontinental routes).
* Round-trip route support (`FlightRouteLoader.roundTrip`) with bidirectional arcs and return flight animation.
* Multi-city itinerary support (`FlightRouteLoader.multiCity`) with multi-point camera framing and sequential leg traversal.
* Direct `Airport` model integration (`FlightRouteLoader.fromAirports`).
* 60fps flight trajectory animation featuring upward quadratic Bezier arc and continuous tangent-aligned airplane rotation.
* Collision-safe floating airport cards that dynamically place labels above or below route pins to prevent overlap.
* Multi-tier airport coordinate resolution fallback chain supporting 300+ major hubs, country centroids, custom resolvers, and deterministic dispersion for global airports.
* Vanilla Flutter architecture free of third-party framework bloat (no GetX, no ScreenUtil, no easy_localization).
* Responsive dark mode and light mode theming.
