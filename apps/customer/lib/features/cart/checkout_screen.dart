import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../address/address_model.dart';
import '../address/address_screen.dart';
import '../orders/order_success_screen.dart';
import '../restaurants/restaurant_models.dart';
import 'cart.dart';
import 'coupon.dart';
import 'pricing.dart';

String _signed(int paise) {
  if (paise < 0) {
    return '-${rupees(-paise)}';
  }
  return rupees(paise);
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _placing = false;
  String? _error;
  Coupon? _coupon;

  Future<void> _placeOrder({
    required User user,
    required String userName,
    required Restaurant shown,
    required PricingConfig cfg,
    required SavedAddress addr,
    required Coupon? coupon,
  }) async {
    setState(() {
      _placing = true;
      _error = null;
    });
    DocumentReference<Map<String, dynamic>>? orderRef;
    String? placedId;
    try {
      final FirebaseFirestore db = FirebaseFirestore.instance;
      final DocumentSnapshot<Map<String, dynamic>> rs =
          await db.collection('restaurants').doc(shown.id).get();
      final Map<String, dynamic>? rd = rs.data();
      if (rd == null || rd['status'] != 'approved' || rd['isOpen'] != true) {
        throw 'This restaurant is not accepting orders right now.';
      }
      final Restaurant fresh = Restaurant.fromDoc(rs);
      if (!fresh.hasLocation) {
        throw 'This restaurant cannot deliver to you right now.';
      }
      final int meters = distanceMeters(addr.lat, addr.lng, fresh.lat, fresh.lng);
      if (meters > fresh.radiusKm * 1000) {
        throw 'This restaurant does not deliver to your address.';
      }
      final List<CartLine> lines = cart.lines;
      if (lines.isEmpty) {
        throw 'Your cart is empty.';
      }
      for (final CartLine l in lines) {
        final DocumentSnapshot<Map<String, dynamic>> m = await db
            .collection('restaurants')
            .doc(shown.id)
            .collection('menu')
            .doc(l.itemId)
            .get();
        final Map<String, dynamic>? md = m.data();
        final dynamic p = md == null ? null : md['pricePaise'];
        if (md == null ||
            md['isAvailable'] != true ||
            p is! num ||
            p.round() != l.pricePaise) {
          throw '${l.name} has changed or is unavailable. Please go back and check the menu.';
        }
      }
      final Bill bill = computeBill(
        cfg,
        foodPaise: cart.foodPaise,
        packagingPaise: fresh.packagingChargePaise,
        meters: meters,
      );
      int discount = 0;
      String couponCode = '';
      final Coupon? chosen = coupon;
      if (chosen != null) {
        final Coupon? live = await findCoupon(chosen.code);
        if (live == null) {
          throw 'This coupon is no longer available.';
        }
        final String? problem = live.problemFor(bill.foodPaise);
        if (problem != null) {
          throw problem;
        }
        if (await usedByCustomer(user.uid, live.code)) {
          throw 'You have already used this coupon.';
        }
        discount = live.discountFor(bill.foodPaise);
        couponCode = live.code;
      }
      final String otp = (1000 + math.Random.secure().nextInt(9000)).toString();
      orderRef = db.collection('orders').doc();
      await orderRef.set(<String, dynamic>{
        'customerUid': user.uid,
        'customerName': userName,
        'restaurantId': fresh.id,
        'restaurantOwnerUid': fresh.ownerUid,
        'restaurantName': fresh.name,
        'items': <Map<String, dynamic>>[
          for (final CartLine l in lines)
            <String, dynamic>{
              'itemId': l.itemId,
              'name': l.name,
              'pricePaise': l.pricePaise,
              'qty': l.qty,
              'isVeg': l.isVeg,
            },
        ],
        'foodSubtotalPaise': bill.foodPaise,
        'packagingPaise': bill.packagingPaise,
        'foodGstPaise': bill.foodGstPaise,
        'deliveryPaise': bill.deliveryPaise,
        'platformFeePaise': bill.platformFeePaise,
        'gstOnFeesPaise': bill.gstOnFeesPaise,
        'roundOffPaise': bill.roundOffPaise,
        'totalPaise': bill.totalPaise - discount,
        if (discount > 0) 'couponCode': couponCode,
        if (discount > 0) 'discountPaise': discount,
        'commissionPaise': bill.commissionPaise,
        'riderPayPaise': bill.riderPayPaise,
        'distanceMeters': bill.distanceMeters,
        'prepTimeMin': fresh.prepTimeMin,
        'status': 'placed',
        'riderUid': null,
        'paymentMethod': 'cod',
        'paymentStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await orderRef.collection('secrets').doc('otp').set(<String, dynamic>{
        'code': otp,
      });
      await orderRef.collection('secrets').doc('drop').set(<String, dynamic>{
        'label': addr.label,
        'addressLine': addr.addressLine,
        'landmark': addr.landmark,
        'lat': addr.lat,
        'lng': addr.lng,
        'customerName': userName,
      });
      placedId = orderRef.id;
    } catch (e) {
      final DocumentReference<Map<String, dynamic>>? created = orderRef;
      if (created != null) {
        try {
          await created.update(<String, dynamic>{
            'status': 'cancelled',
            'cancelReason': 'Order could not be completed',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _placing = false;
        _error = e is String ? e : 'Could not place the order. Please try again.';
      });
      return;
    }
    cart.clear();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => OrderSuccessScreen(orderId: placedId!),
      ),
    );
  }

  Future<void> _confirm({
    required User user,
    required String userName,
    required Restaurant shown,
    required PricingConfig cfg,
    required SavedAddress addr,
    required Bill bill,
    required int discount,
    required Coupon? coupon,
  }) async {
    final bool? ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Confirm your order',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: TwingaColors.ink,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, color: TwingaColors.orange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deliver to ${addr.label}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(addr.addressLine),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              const Row(
                children: [
                  Icon(Icons.payments_outlined, color: TwingaColors.veg),
                  SizedBox(width: 10),
                  Text(
                    'Cash on delivery',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const Divider(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'To pay',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    rupees(bill.totalPaise - discount),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: const Text('Confirm and place order'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  child: const Text('Go back'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    await _placeOrder(
      user: user,
      userName: userName,
      shown: shown,
      cfg: cfg,
      addr: addr,
      coupon: coupon,
    );
  }

  Widget _paymentCard() {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment method',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: TwingaColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.check_circle, color: TwingaColors.veg),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cash on delivery',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text('Pay in cash when your order arrives'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Opacity(
              opacity: 0.5,
              child: Row(
                children: [
                  const Icon(Icons.radio_button_unchecked),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'UPI',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Coming soon',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Your cart')),
      body: user == null
          ? const SizedBox.shrink()
          : AnimatedBuilder(
              animation: cart,
              builder: (context, child) {
                final Restaurant? r = cart.restaurant;
                if (r == null || cart.isEmpty) {
                  return const Center(child: Text('Your cart is empty.'));
                }
                return _content(context, user, r);
              },
            ),
    );
  }

  Widget _content(BuildContext context, User user, Restaurant r) {
    final DocumentReference<Map<String, dynamic>> userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('config')
          .doc('pricing')
          .snapshots(),
      builder: (context, priceSnap) {
        if (priceSnap.hasError) {
          return Center(child: Text('Could not load pricing:\n${priceSnap.error}'));
        }
        if (!priceSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final PricingConfig? cfg = PricingConfig.fromMap(priceSnap.data!.data());
        if (cfg == null) {
          return const Center(
            child: Text('Pricing is not available right now. Please try later.'),
          );
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userRef.snapshots(),
          builder: (context, userSnap) {
            final Map<String, dynamic>? ud = userSnap.data?.data();
            final String userName = (ud?['name'] ?? '').toString();
            final dynamic raw = ud?['defaultAddressId'];
            if (raw is! String || raw.isEmpty) {
              return _body(context, user, userName, r, cfg, null);
            }
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: userRef.collection('addresses').doc(raw).snapshots(),
              builder: (context, addrSnap) {
                final DocumentSnapshot<Map<String, dynamic>>? doc = addrSnap.data;
                final SavedAddress? addr =
                    (doc == null || !doc.exists) ? null : SavedAddress.fromDoc(doc);
                return _body(context, user, userName, r, cfg, addr);
              },
            );
          },
        );
      },
    );
  }

  Future<void> _pickCoupon(User user, int foodPaise) async {
    final Coupon? c = await showModalBottomSheet<Coupon>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _CouponSheet(uid: user.uid, foodPaise: foodPaise),
    );
    if (c != null && mounted) {
      setState(() {
        _coupon = c;
      });
    }
  }

  Widget _couponCard(User user, Bill b, Coupon? cp, int discount) {
    if (cp != null && discount > 0) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F8EE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBFE8CD)),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_offer_rounded, color: TwingaColors.veg),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${cp.code} applied',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: TwingaColors.ink,
                    ),
                  ),
                  Text(
                    'You save ${rupees(discount)} on this order',
                    style: const TextStyle(
                      color: TwingaColors.veg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _coupon = null;
                });
              },
              child: const Text('Remove'),
            ),
          ],
        ),
      );
    }
    return Material(
      color: Colors.white,
      elevation: 1,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _pickCoupon(user, b.foodPaise),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.local_offer_outlined, color: TwingaColors.orange),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Apply coupon',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: TwingaColors.ink,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: TwingaColors.blue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _billRow(String label, String value, {bool bold = false}) {
    final TextStyle style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 16 : 14,
      color: TwingaColors.ink,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    User user,
    String userName,
    Restaurant r,
    PricingConfig cfg,
    SavedAddress? addr,
  ) {
    Bill? bill;
    String? zoneProblem;
    if (addr != null) {
      if (!r.hasLocation) {
        zoneProblem = 'This restaurant cannot deliver to you right now.';
      } else {
        final int meters = distanceMeters(addr.lat, addr.lng, r.lat, r.lng);
        if (meters > r.radiusKm * 1000) {
          zoneProblem = 'This restaurant does not deliver to your address.';
        } else {
          bill = computeBill(
            cfg,
            foodPaise: cart.foodPaise,
            packagingPaise: r.packagingChargePaise,
            meters: meters,
          );
        }
      }
    }
    final Bill? b = bill;
    final Coupon? cp = _coupon;
    String? couponProblem;
    int discount = 0;
    if (b != null && cp != null) {
      couponProblem = cp.problemFor(b.foodPaise);
      if (couponProblem == null) {
        discount = cp.discountFor(b.foodPaise);
      }
    }
    final int toPay = b == null ? 0 : b.totalPaise - discount;
    final bool canPlace = !_placing && addr != null && b != null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          r.name,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: TwingaColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        for (final CartLine l in cart.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: l.isVeg ? TwingaColors.veg : const Color(0xFFB71C1C),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => cart.decrease(l.itemId),
                ),
                Text('${l.qty}', style: const TextStyle(fontWeight: FontWeight.w800)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => cart.increase(l.itemId),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    rupees(l.qty * l.pricePaise),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Card(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: TwingaColors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: addr == null
                      ? const Text('Add a delivery address to continue')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Deliver to ${addr.label}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            Text(addr.addressLine),
                          ],
                        ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const AddressScreen(),
                      ),
                    );
                  },
                  child: Text(addr == null ? 'Add' : 'Change'),
                ),
              ],
            ),
          ),
        ),
        if (zoneProblem != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              zoneProblem,
              style: const TextStyle(
                color: TwingaColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (b != null) ...[
          const SizedBox(height: 12),
          _couponCard(user, b, cp, discount),
          if (couponProblem != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                couponProblem,
                style: const TextStyle(
                  color: TwingaColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Card(
            color: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _billRow('Item total', rupees(b.foodPaise)),
                  if (b.packagingPaise > 0)
                    _billRow('Packaging charge', rupees(b.packagingPaise)),
                  _billRow(
                    'Delivery fee (${(b.distanceMeters / 1000).toStringAsFixed(1)} km)',
                    rupees(b.deliveryPaise),
                  ),
                  _billRow('Platform fee', rupees(b.platformFeePaise)),
                  _billRow('GST on food', rupees(b.foodGstPaise)),
                  _billRow('GST on fees', rupees(b.gstOnFeesPaise)),
                  if (b.roundOffPaise != 0)
                    _billRow('Round off', _signed(b.roundOffPaise)),
                  if (discount > 0)
                    _billRow('Coupon discount', '-${rupees(discount)}'),
                  const Divider(),
                  _billRow('To pay', rupees(toPay), bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _paymentCard(),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _error!,
              style: const TextStyle(color: TwingaColors.error),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: canPlace
              ? () => _confirm(
                    user: user,
                    userName: userName,
                    shown: r,
                    cfg: cfg,
                    addr: addr!,
                    bill: b!,
                    discount: discount,
                    coupon: discount > 0 ? cp : null,
                  )
              : null,
          child: _placing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  b == null
                      ? 'Place order'
                      : 'Place order  ·  ${rupees(toPay)}',
                ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _CouponSheet extends StatefulWidget {
  const _CouponSheet({required this.uid, required this.foodPaise});

  final String uid;
  final int foodPaise;

  @override
  State<_CouponSheet> createState() => _CouponSheetState();
}

class _CouponSheetState extends State<_CouponSheet> {
  final TextEditingController _ctl = TextEditingController();
  bool _busy = false;
  String? _msg;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _use(Coupon c) async {
    final String? p = c.problemFor(widget.foodPaise);
    if (p != null) {
      setState(() {
        _msg = p;
      });
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final bool used = await usedByCustomer(widget.uid, c.code);
      if (!mounted) {
        return;
      }
      if (used) {
        setState(() {
          _busy = false;
          _msg = 'You have already used this coupon.';
        });
        return;
      }
      Navigator.of(context).pop(c);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _msg = 'Could not check this coupon. Please try again.';
      });
    }
  }

  Future<void> _typed() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final Coupon? c = await findCoupon(_ctl.text);
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
      if (c == null) {
        setState(() {
          _msg = 'This coupon code is not valid.';
        });
        return;
      }
      await _use(c);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _msg = 'Could not check this coupon. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              const Text(
                'Apply coupon',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: TwingaColors.ink,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'Enter coupon code',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _busy ? null : _typed,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Apply'),
                  ),
                ],
              ),
              if (_msg != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _msg!,
                    style: const TextStyle(
                      color: TwingaColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              const Text(
                'Available coupons',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: TwingaColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                    FirebaseFirestore.instance.collection('coupons').snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return const Text('Could not load coupons.');
                  }
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final List<Coupon> list = <Coupon>[
                    for (final QueryDocumentSnapshot<Map<String, dynamic>> d
                        in snap.data!.docs)
                      Coupon.fromDoc(d),
                  ].where((c) => c.active && !c.expired && c.code.isNotEmpty).toList();
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No coupons available right now.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final Coupon c in list) _tile(c),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(Coupon c) {
    final String? problem = c.problemFor(widget.foodPaise);
    final bool ok = problem == null;
    return Opacity(
      opacity: ok ? 1 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD5E3FA)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _busy ? null : () => _use(c),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1DC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    c.code,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: TwingaColors.orange,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.offerText,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: TwingaColors.ink,
                        ),
                      ),
                      if (c.description.isNotEmpty)
                        Text(
                          c.description,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.black54,
                          ),
                        ),
                      if (c.minOrderPaise > 0)
                        Text(
                          'Minimum order ${rupees(c.minOrderPaise)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  ok ? 'Apply' : 'Not eligible',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: ok ? TwingaColors.blue : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
