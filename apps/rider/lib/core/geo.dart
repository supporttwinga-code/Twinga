import 'dart:math' as math;

double _rad(double degrees) => degrees * math.pi / 180;

/// Straight-line distance in metres between two points (haversine).
int distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const double earthRadius = 6371000;
  final double dLat = _rad(lat2 - lat1);
  final double dLng = _rad(lng2 - lng1);
  final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final double safe = a < 0 ? 0 : (a > 1 ? 1 : a);
  final double c = 2 * math.atan2(math.sqrt(safe), math.sqrt(1 - safe));
  return (earthRadius * c).round();
}
