/// Represents the trip itinerary type: one-way, round-trip, or multi-city.
enum FlightTripType {
  /// Single flight segment from origin to destination (A ➔ B).
  oneWay,

  /// Round-trip flight consisting of outbound and return segments (A ➔ B ➔ A).
  roundTrip,

  /// Multi-city flight consisting of two or more sequential flight segments (A ➔ B ➔ C ...).
  multiCity,
}
