import 'dart:math' as math;

int _roundDiv(int a, int b) => (2 * a + b) ~/ (2 * b);

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

class PricingConfig {
  const PricingConfig({
    required this.commissionPct,
    required this.deliveryBaseKm,
    required this.deliveryBasePaise,
    required this.deliveryExtraPerKmPaise,
    required this.foodGstPct,
    required this.gstFeesPct,
    required this.platformFeePaise,
    required this.riderBaseKm,
    required this.riderBasePerKmPaise,
    required this.riderExtraPerKmPaise,
    required this.riderMinKm,
  });

  final int commissionPct;
  final int deliveryBaseKm;
  final int deliveryBasePaise;
  final int deliveryExtraPerKmPaise;
  final int foodGstPct;
  final int gstFeesPct;
  final int platformFeePaise;
  final int riderBaseKm;
  final int riderBasePerKmPaise;
  final int riderExtraPerKmPaise;
  final int riderMinKm;

  /// Returns null if any required pricing field is missing or not a number.
  static PricingConfig? fromMap(Map<String, dynamic>? d) {
    if (d == null) {
      return null;
    }
    const List<String> keys = <String>[
      'commissionPct',
      'deliveryBaseKm',
      'deliveryBasePaise',
      'deliveryExtraPerKmPaise',
      'foodGstPct',
      'gstFeesPct',
      'platformFeePaise',
      'riderBaseKm',
      'riderBasePerKmPaise',
      'riderExtraPerKmPaise',
      'riderMinKm',
    ];
    final Map<String, int> v = <String, int>{};
    for (final String k in keys) {
      final dynamic x = d[k];
      if (x is! num) {
        return null;
      }
      v[k] = x.round();
    }
    return PricingConfig(
      commissionPct: v['commissionPct']!,
      deliveryBaseKm: v['deliveryBaseKm']!,
      deliveryBasePaise: v['deliveryBasePaise']!,
      deliveryExtraPerKmPaise: v['deliveryExtraPerKmPaise']!,
      foodGstPct: v['foodGstPct']!,
      gstFeesPct: v['gstFeesPct']!,
      platformFeePaise: v['platformFeePaise']!,
      riderBaseKm: v['riderBaseKm']!,
      riderBasePerKmPaise: v['riderBasePerKmPaise']!,
      riderExtraPerKmPaise: v['riderExtraPerKmPaise']!,
      riderMinKm: v['riderMinKm']!,
    );
  }
}

class Bill {
  const Bill({
    required this.foodPaise,
    required this.packagingPaise,
    required this.foodGstPaise,
    required this.deliveryPaise,
    required this.platformFeePaise,
    required this.gstOnFeesPaise,
    required this.roundOffPaise,
    required this.totalPaise,
    required this.commissionPaise,
    required this.riderPayPaise,
    required this.distanceMeters,
  });

  final int foodPaise;
  final int packagingPaise;
  final int foodGstPaise;
  final int deliveryPaise;
  final int platformFeePaise;
  final int gstOnFeesPaise;
  final int roundOffPaise;
  final int totalPaise;
  final int commissionPaise;
  final int riderPayPaise;
  final int distanceMeters;
}

Bill computeBill(
  PricingConfig c, {
  required int foodPaise,
  required int packagingPaise,
  required int meters,
}) {
  int kmTenths = (meters + 99) ~/ 100;
  if (kmTenths < c.riderMinKm * 10) {
    kmTenths = c.riderMinKm * 10;
  }
  final int baseTenths = c.deliveryBaseKm * 10;
  final int extraTenths = kmTenths > baseTenths ? kmTenths - baseTenths : 0;
  final int delivery =
      c.deliveryBasePaise + _roundDiv(extraTenths * c.deliveryExtraPerKmPaise, 10);

  final int riderBaseTenths = c.riderBaseKm * 10;
  final int riderUsedBase = kmTenths < riderBaseTenths ? kmTenths : riderBaseTenths;
  final int riderExtra = kmTenths > riderBaseTenths ? kmTenths - riderBaseTenths : 0;
  final int riderPay = _roundDiv(riderUsedBase * c.riderBasePerKmPaise, 10) +
      _roundDiv(riderExtra * c.riderExtraPerKmPaise, 10);

  final int commission = _roundDiv(foodPaise * c.commissionPct, 100);
  final int foodGst = _roundDiv((foodPaise + packagingPaise) * c.foodGstPct, 100);
  final int gstOnFees =
      _roundDiv((delivery + c.platformFeePaise) * c.gstFeesPct, 100);
  final int sum = foodPaise +
      packagingPaise +
      foodGst +
      delivery +
      c.platformFeePaise +
      gstOnFees;
  final int total = _roundDiv(sum, 100) * 100;
  return Bill(
    foodPaise: foodPaise,
    packagingPaise: packagingPaise,
    foodGstPaise: foodGst,
    deliveryPaise: delivery,
    platformFeePaise: c.platformFeePaise,
    gstOnFeesPaise: gstOnFees,
    roundOffPaise: total - sum,
    totalPaise: total,
    commissionPaise: commission,
    riderPayPaise: riderPay,
    distanceMeters: meters,
  );
}
