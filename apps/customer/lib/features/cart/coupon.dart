import 'package:cloud_firestore/cloud_firestore.dart';

int _int(dynamic v) => v is num ? v.round() : 0;

/// One coupon made by the admin (collection: coupons).
class Coupon {
  const Coupon({
    required this.id,
    required this.code,
    required this.description,
    required this.isPercent,
    required this.value,
    required this.minOrderPaise,
    required this.maxDiscountPaise,
    required this.active,
    required this.expiresAt,
  });

  final String id;
  final String code;
  final String description;
  final bool isPercent;
  final int value;
  final int minOrderPaise;
  final int maxDiscountPaise;
  final bool active;
  final DateTime? expiresAt;

  static Coupon fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> d = doc.data() ?? <String, dynamic>{};
    final dynamic exp = d['expiresAt'];
    return Coupon(
      id: doc.id,
      code: (d['code'] ?? '').toString().toUpperCase(),
      description: (d['description'] ?? '').toString(),
      isPercent: (d['type'] ?? 'percent') != 'flat',
      value: _int(d['value']),
      minOrderPaise: _int(d['minOrderPaise']),
      maxDiscountPaise: _int(d['maxDiscountPaise']),
      active: d['active'] == true,
      expiresAt: exp is Timestamp ? exp.toDate() : null,
    );
  }

  bool get expired {
    final DateTime? e = expiresAt;
    return e != null && e.isBefore(DateTime.now());
  }

  /// Short offer text for the list, for example "20% off" or "Rs 50 off".
  String get offerText {
    if (isPercent) {
      return '$value% off';
    }
    return 'Rs $value off';
  }

  /// Why this coupon cannot be used on [foodPaise], or null if it can.
  String? problemFor(int foodPaise) {
    if (!active) {
      return 'This coupon is not active.';
    }
    if (expired) {
      return 'This coupon has expired.';
    }
    if (value <= 0) {
      return 'This coupon is not valid.';
    }
    if (foodPaise < minOrderPaise) {
      final int rs = (minOrderPaise / 100).ceil();
      return 'Add items worth Rs $rs or more to use this coupon.';
    }
    return null;
  }

  /// Discount in paise on the item total. Always a whole number of rupees
  /// and never more than the item total.
  int discountFor(int foodPaise) {
    int d;
    if (isPercent) {
      d = foodPaise * value ~/ 100;
    } else {
      d = value * 100;
    }
    if (maxDiscountPaise > 0 && d > maxDiscountPaise) {
      d = maxDiscountPaise;
    }
    if (d > foodPaise) {
      d = foodPaise;
    }
    return d ~/ 100 * 100;
  }
}

/// Finds a coupon by the code the customer typed. Returns null if none.
Future<Coupon?> findCoupon(String typed) async {
  final String code = typed.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  if (code.isEmpty) {
    return null;
  }
  final QuerySnapshot<Map<String, dynamic>> q = await FirebaseFirestore.instance
      .collection('coupons')
      .where('code', isEqualTo: code)
      .limit(1)
      .get();
  if (q.docs.isEmpty) {
    return null;
  }
  return Coupon.fromDoc(q.docs.first);
}

/// True if this customer already used [code] on an order that was not
/// cancelled or rejected. One use per customer.
Future<bool> usedByCustomer(String uid, String code) async {
  final QuerySnapshot<Map<String, dynamic>> q = await FirebaseFirestore.instance
      .collection('orders')
      .where('customerUid', isEqualTo: uid)
      .where('couponCode', isEqualTo: code)
      .get();
  for (final QueryDocumentSnapshot<Map<String, dynamic>> d in q.docs) {
    final String s = (d.data()['status'] ?? '').toString();
    if (s != 'cancelled' && s != 'rejected') {
      return true;
    }
  }
  return false;
}
