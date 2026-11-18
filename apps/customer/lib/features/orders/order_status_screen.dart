import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/theme.dart';

import 'live_track_card.dart';
import 'rate_order_card.dart';

String orderStatusText(String status) {
  switch (status) {
    case 'placed':
      return 'Order placed. Waiting for the restaurant to accept.';
    case 'accepted':
      return 'The restaurant accepted your order.';
    case 'preparing':
      return 'Your food is being prepared.';
    case 'ready':
      return 'Your food is ready for pickup.';
    case 'picked':
      return 'Your order is on the way.';
    case 'delivered':
      return 'Delivered. Enjoy your meal!';
    case 'rejected':
      return 'The restaurant could not accept your order.';
    case 'cancelled':
      return 'This order was cancelled.';
    default:
      return 'Status: $status';
  }
}

const List<String> _steps = <String>[
  'placed',
  'accepted',
  'preparing',
  'ready',
  'picked',
  'delivered',
];

const List<String> _stepTitle = <String>[
  'Order placed',
  'Restaurant accepted',
  'Preparing your food',
  'Food is ready',
  'On the way',
  'Delivered',
];

const List<String> _stepSub = <String>[
  'We sent your order to the restaurant',
  'The restaurant confirmed your order',
  'The kitchen is cooking it fresh',
  'Waiting for the delivery partner to pick it up',
  'Your delivery partner is bringing it to you',
  'Enjoy your meal',
];

const Color _deep = Color(0xFF0A3FB5);
const Color _lineColor = Color(0xFFE3EAF7);

int _asInt(dynamic v) => v is num ? v.round() : 0;

DateTime? _time(dynamic v) => v is Timestamp ? v.toDate() : null;

String _clock(DateTime d) {
  final int h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final String m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
}

String _shortId(String id) {
  return id.length > 5
      ? id.substring(id.length - 5).toUpperCase()
      : id.toUpperCase();
}

bool _isLive(String s) => _steps.indexOf(s) >= 0 && s != 'delivered';

BoxDecoration _card() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: _lineColor),
    boxShadow: const [
      BoxShadow(color: Color(0x140A2A8F), blurRadius: 16, offset: Offset(0, 6)),
    ],
  );
}

class OrderStatusScreen extends StatelessWidget {
  const OrderStatusScreen({super.key, required this.orderId});

  final String orderId;

  Future<void> _cancel(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text(
          'The restaurant has not started delivery yet, so you can cancel now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep order'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Cancel order',
              style: TextStyle(color: TwingaColors.error),
            ),
          ),
        ],
      ),
    );
    if (yes != true) {
      return;
    }
    try {
      await ref.update(<String, dynamic>{
        'status': 'cancelled',
        'cancelReason': 'Cancelled by customer',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not cancel the order.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final DocumentReference<Map<String, dynamic>> ref =
        FirebaseFirestore.instance.collection('orders').doc(orderId);
    return Scaffold(
      backgroundColor: TwingaColors.background,
      appBar: AppBar(
        title: Text('Order #${_shortId(orderId)}'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Could not load order:\n${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final Map<String, dynamic>? d = snap.data!.data();
          if (d == null) {
            return const Center(child: Text('Order not found.'));
          }
          final String status = (d['status'] ?? '').toString();
          final bool failed = status == 'cancelled' || status == 'rejected';
          final bool live = _isLive(status);
          final String riderName = (d['riderName'] ?? '').toString();
          final String riderPhone = (d['riderPhone'] ?? '').toString();
          final bool noRider = d['riderUid'] == null;
          final bool canCancel =
              (status == 'placed' || status == 'accepted') && noRider;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _Hero(order: d, status: status),
              const SizedBox(height: 14),
              if (failed)
                _FailedCard(order: d, status: status)
              else
                _TimelineCard(order: d, status: status),
              if (status == 'delivered') ...[
                const SizedBox(height: 14),
                RateOrderCard(orderId: orderId, order: d),
              ],
              if (live && riderName.isNotEmpty) ...[
                const SizedBox(height: 14),
                _RiderCard(name: riderName, phone: riderPhone),
              ],
              if (live && d['riderLat'] is num && d['riderLng'] is num) ...[
                const SizedBox(height: 14),
                LiveTrackCard(orderId: orderId, order: d),
              ],
              if (live) ...[
                const SizedBox(height: 14),
                _OtpCard(ref: ref),
              ],
              const SizedBox(height: 14),
              _AddressCard(ref: ref),
              const SizedBox(height: 14),
              _ItemsCard(order: d),
              const SizedBox(height: 14),
              _BillCard(order: d),
              if (canCancel) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () => _cancel(context, ref),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cancel order'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: TwingaColors.error,
                    side: const BorderSide(color: TwingaColors.error),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.order, required this.status});

  final Map<String, dynamic> order;
  final String status;

  @override
  Widget build(BuildContext context) {
    final bool failed = status == 'cancelled' || status == 'rejected';
    final bool done = status == 'delivered';
    final List<Color> colors = failed
        ? const [Color(0xFFB71C1C), Color(0xFFE53935)]
        : done
            ? const [Color(0xFF1E9E4A), Color(0xFF28C76F)]
            : const [_deep, TwingaColors.blue, Color(0xFF3AA4FF)];
    IconData icon;
    String title;
    switch (status) {
      case 'placed':
        icon = Icons.hourglass_top_rounded;
        title = 'Waiting for the restaurant';
        break;
      case 'accepted':
        icon = Icons.thumb_up_alt_rounded;
        title = 'Order accepted';
        break;
      case 'preparing':
        icon = Icons.soup_kitchen_rounded;
        title = 'Preparing your food';
        break;
      case 'ready':
        icon = Icons.shopping_bag_rounded;
        title = 'Food is ready';
        break;
      case 'picked':
        icon = Icons.delivery_dining_rounded;
        title = 'On the way to you';
        break;
      case 'delivered':
        icon = Icons.check_circle_rounded;
        title = 'Delivered';
        break;
      case 'rejected':
        icon = Icons.storefront_rounded;
        title = 'Order not accepted';
        break;
      default:
        icon = Icons.cancel_rounded;
        title = 'Order cancelled';
    }
    String eta = '';
    final DateTime? created = _time(order['createdAt']);
    if (_isLive(status) && created != null) {
      final int prep = _asInt(order['prepTimeMin']);
      final int meters = _asInt(order['distanceMeters']);
      int travel = (meters / 1000 * 4).ceil();
      if (travel < 5) {
        travel = 5;
      }
      final DateTime at = created.add(Duration(minutes: prep + travel + 5));
      eta = 'Estimated delivery by ${_clock(at)}';
    } else if (status == 'delivered') {
      final DateTime? t = _time(order['updatedAt']);
      if (t != null) {
        eta = 'Delivered at ${_clock(t)}';
      }
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: colors.first.withAlpha(70),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(45),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (order['restaurantName'] ?? '').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withAlpha(225),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (eta.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      eta,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FailedCard extends StatelessWidget {
  const _FailedCard({required this.order, required this.status});

  final Map<String, dynamic> order;
  final String status;

  @override
  Widget build(BuildContext context) {
    final String reason = (order['cancelReason'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status == 'rejected'
                ? 'The restaurant could not accept this order'
                : 'This order was cancelled',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: TwingaColors.ink,
            ),
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(reason),
          ],
          const SizedBox(height: 8),
          const Text(
            'You have not been charged. Nothing is due for this order.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 12 + 14 * _c.value,
                height: 12 + 14 * _c.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TwingaColors.orange
                      .withAlpha((110 * (1 - _c.value)).round()),
                ),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: TwingaColors.orange,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.order, required this.status});

  final Map<String, dynamic> order;
  final String status;

  String _stamp(int i, int current) {
    DateTime? t;
    if (i == 0) {
      t = _time(order['createdAt']);
    } else if (i == 1) {
      t = _time(order['acceptedAt']);
    }
    if (t == null && i == current && i > 0) {
      t = _time(order['updatedAt']);
    }
    return t == null ? '' : _clock(t);
  }

  @override
  Widget build(BuildContext context) {
    final int current = _steps.indexOf(status);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: TwingaColors.ink,
            ),
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < _steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Column(
                      children: [
                        if (i < current || status == 'delivered')
                          Container(
                            width: 22,
                            height: 22,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: TwingaColors.blue,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            ),
                          )
                        else if (i == current)
                          const _PulseDot()
                        else
                          Container(
                            width: 14,
                            height: 14,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFC9D6EE),
                                width: 2,
                              ),
                            ),
                          ),
                        if (i < _steps.length - 1)
                          Expanded(
                            child: Container(
                              width: 3,
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              decoration: BoxDecoration(
                                color: i < current
                                    ? TwingaColors.blue
                                    : const Color(0xFFD5E3FA),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _stepTitle[i],
                                  style: TextStyle(
                                    fontWeight: i <= current
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    fontSize: 14.5,
                                    color: i <= current
                                        ? TwingaColors.ink
                                        : Colors.black38,
                                  ),
                                ),
                                if (i == current)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      _stepSub[i],
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            _stamp(i, current),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RiderCard extends StatelessWidget {
  const _RiderCard({required this.name, required this.phone});

  final String name;
  final String phone;

  @override
  Widget build(BuildContext context) {
    final String initial = name.trim().isEmpty ? 'R' : name.trim()[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFFFC15E), TwingaColors.orange],
              ),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your delivery partner',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: TwingaColors.ink,
                  ),
                ),
                if (phone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: SelectableText(
                      phone,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: TwingaColors.blue,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.two_wheeler_rounded, color: TwingaColors.blue),
        ],
      ),
    );
  }
}

class _OtpCard extends StatelessWidget {
  const _OtpCard({required this.ref});

  final DocumentReference<Map<String, dynamic>> ref;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.collection('secrets').doc('otp').snapshots(),
      builder: (context, snap) {
        final String code = (snap.data?.data()?['code'] ?? '').toString();
        if (code.isEmpty) {
          return const SizedBox.shrink();
        }
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F1FF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFCFE0FB)),
          ),
          child: Column(
            children: [
              const Text(
                'Delivery OTP',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: TwingaColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final String ch in code.split(''))
                    Container(
                      width: 46,
                      height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A0A2A8F),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        ch,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: TwingaColors.blue,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Tell this OTP to the delivery partner only when you receive your order.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.ref});

  final DocumentReference<Map<String, dynamic>> ref;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.collection('secrets').doc('drop').snapshots(),
      builder: (context, snap) {
        final Map<String, dynamic>? x = snap.data?.data();
        if (x == null) {
          return const SizedBox.shrink();
        }
        final String label = (x['label'] ?? '').toString();
        final String line = (x['addressLine'] ?? '').toString();
        final String landmark = (x['landmark'] ?? '').toString();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: _card(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1DC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: TwingaColors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.isEmpty ? 'Delivery address' : 'Deliver to $label',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: TwingaColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(line),
                    if (landmark.isNotEmpty)
                      Text(
                        'Landmark: $landmark',
                        style: const TextStyle(color: Colors.black54),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order});

  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final dynamic raw = order['items'];
    final List<dynamic> items = raw is List ? raw : <dynamic>[];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your items',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: TwingaColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          for (final dynamic it in items)
            if (it is Map)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: it['isVeg'] == false
                              ? const Color(0xFFB71C1C)
                              : TwingaColors.veg,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: it['isVeg'] == false
                                ? const Color(0xFFB71C1C)
                                : TwingaColors.veg,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${it['qty'] ?? 1} x ${it['name'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      rupees(
                        ((it['qty'] is num ? it['qty'] as num : 1) *
                                (it['pricePaise'] is num
                                    ? it['pricePaise'] as num
                                    : 0))
                            .round(),
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.order});

  final Map<String, dynamic> order;

  Widget _row(String label, int paise, {bool bold = false, bool signed = false}) {
    final TextStyle style = TextStyle(
      fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
      fontSize: bold ? 16 : 13.5,
      color: TwingaColors.ink,
    );
    final String value =
        signed && paise < 0 ? '-${rupees(-paise)}' : rupees(paise);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int round = _asInt(order['roundOffPaise']);
    final int pack = _asInt(order['packagingPaise']);
    final int discount = _asInt(order['discountPaise']);
    final String coupon = (order['couponCode'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bill details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: TwingaColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          _row('Item total', _asInt(order['foodSubtotalPaise'])),
          if (pack > 0) _row('Packaging charge', pack),
          _row('Delivery fee', _asInt(order['deliveryPaise'])),
          _row('Platform fee', _asInt(order['platformFeePaise'])),
          _row('GST on food', _asInt(order['foodGstPaise'])),
          _row('GST on fees', _asInt(order['gstOnFeesPaise'])),
          if (round != 0) _row('Round off', round, signed: true),
          if (discount > 0)
            _row(
              coupon.isEmpty ? 'Coupon discount' : 'Coupon ($coupon)',
              -discount,
              signed: true,
            ),
          const Divider(height: 20),
          _row(
            'Total (cash on delivery)',
            _asInt(order['totalPaise']),
            bold: true,
          ),
        ],
      ),
    );
  }
}
