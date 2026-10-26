import 'airport.dart';

/// Represents a single stop or airport along a flight route itinerary.
class FlightRouteStop {
  /// 3-letter IATA code (e.g. 'DAC', 'JFK', 'LHR') or ICAO identifier.
  final String code;

  /// Display city name or airport name (e.g. 'Dhaka', 'New York').
  final String city;

  /// Optional latitude coordinate in decimal degrees.
  /// If null, resolved automatically via [AirportCoordinatesHelper].
  final double? latitude;

  /// Optional longitude coordinate in decimal degrees.
  /// If null, resolved automatically via [AirportCoordinatesHelper].
  final double? longitude;

  /// Optional country name for fallback centroid resolution.
  final String? country;

  /// Optional 2-letter or 3-letter ISO country code.
  final String? countryCode;

  const FlightRouteStop({
    required this.code,
    required this.city,
    this.latitude,
    this.longitude,
    this.country,
    this.countryCode,
  });

  /// Creates a [FlightRouteStop] directly from an [Airport] instance.
  factory FlightRouteStop.fromAirport(Airport airport) {
    return FlightRouteStop(
      code: airport.code,
      city: airport.city.isNotEmpty ? airport.city : airport.name,
      latitude: airport.latitude,
      longitude: airport.longitude,
      country: airport.country.isNotEmpty ? airport.country : null,
      countryCode: airport.countryCode.isNotEmpty ? airport.countryCode : null,
    );
  }

  /// Converts this stop into an [Airport] model.
  Airport toAirport() {
    return Airport(
      code: code,
      name: city,
      city: city,
      country: country ?? '',
      countryCode: countryCode ?? '',
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  String toString() => 'FlightRouteStop($code, $city)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlightRouteStop &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          city == other.city;

  @override
  int get hashCode => Object.hash(code, city);
}

/// Represents a single directed leg between two stops in an itinerary.
class FlightRouteLeg {
  /// Departure stop of this flight leg.
  final FlightRouteStop from;

  /// Arrival stop of this flight leg.
  final FlightRouteStop to;

  /// Optional descriptive label (e.g. "Outbound", "Return", "Leg 2").
  final String? label;

  /// Whether this leg represents a return flight back to the origin.
  final bool isReturn;

  const FlightRouteLeg({
    required this.from,
    required this.to,
    this.label,
    this.isReturn = false,
  });

  @override
  String toString() => 'FlightRouteLeg(${from.code} ➔ ${to.code}, isReturn: $isReturn)';
}
