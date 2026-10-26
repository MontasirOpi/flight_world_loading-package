/// A high-performance, offline vector map flight search loading package for Flutter.
///
/// Features:
/// - Offline Natural Earth vector landmasses (zero network requests, zero tile servers).
/// - Adaptive distance-based camera zoom (close margins for domestic hops, global framing for intercontinental routes).
/// - Round-trip and multi-city itinerary support with multi-leg flight trajectories.
/// - Smooth 60fps flight trajectory with tangent-aligned airplane heading.
/// - Collision-free floating airport cards and pins.
/// - Resilient 8-tier airport coordinate resolution for global airports with zero crashes.
library;

export 'src/helpers/airport_coordinates_helper.dart';
export 'src/helpers/map_projection_helper.dart';
export 'src/models/airport.dart';
export 'src/models/country_polygon.dart';
export 'src/models/flight_route_stop.dart';
export 'src/models/flight_trip_type.dart';
export 'src/models/map_precomputed_paths.dart';
export 'src/services/airport_service.dart';
export 'src/services/geo_json_service.dart';
export 'src/widgets/flight_map_painter.dart';
export 'src/widgets/flight_route_loader.dart';
