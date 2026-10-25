/// Represents an airport with its IATA/ICAO code, city, country, and geographic coordinates.
class Airport {
  /// 3-letter IATA code (e.g. 'JFK', 'DAC', 'LHR') or ICAO/local identifier.
  final String code;

  /// Full or common name of the airport.
  final String name;

  /// City served by the airport.
  final String city;

  /// Country where the airport is located.
  final String country;

  /// 2-letter or 3-letter ISO country code (e.g. 'US', 'BD', 'GB').
  final String countryCode;

  /// Latitude coordinate in decimal degrees (-90.0 to 90.0).
  final double? latitude;

  /// Longitude coordinate in decimal degrees (-180.0 to 180.0).
  final double? longitude;

  const Airport({
    required this.code,
    required this.name,
    required this.city,
    required this.country,
    this.countryCode = '',
    this.latitude,
    this.longitude,
  });

  /// Factory constructor to parse airport from flexible JSON structures.
  factory Airport.fromJson(Map<String, dynamic> json) {
    final rawLat = json['latitude'] ?? json['lat'];
    final rawLng = json['longitude'] ?? json['lon'] ?? json['lng'];

    return Airport(
      code: (json['code'] ?? json['iata'] ?? '').toString().trim().toUpperCase(),
      name: (json['name'] ?? json['airport_name'] ?? '').toString().trim(),
      city: (json['city'] ??
              json['airport_city'] ??
              json['city_name'] ??
              json['municipality'] ??
              '')
          .toString()
          .trim(),
      country: (json['country'] ??
              json['airport_country'] ??
              json['country_name'] ??
              '')
          .toString()
          .trim(),
      countryCode: (json['country_code'] ??
              json['airport_country_code'] ??
              json['iso_country'] ??
              '')
          .toString()
          .trim()
          .toUpperCase(),
      latitude: rawLat != null ? double.tryParse(rawLat.toString()) : null,
      longitude: rawLng != null ? double.tryParse(rawLng.toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'city': city,
      'country': country,
      'countryCode': countryCode,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  @override
  String toString() => 'Airport($code, $city, $country, ($latitude, $longitude))';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Airport &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}
