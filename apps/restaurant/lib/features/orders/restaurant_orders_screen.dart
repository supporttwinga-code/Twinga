import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';

String _rupees(int paise) {
  final int whole = paise ~/ 100;
  final int rem = paise % 100;
  if (rem == 0) {
    return '₹$whole';
  }
  return '₹$whole.${rem.toString().padLeft(2, '0')}';
}

int _intOf(dynamic v) {
  if (v is num) {
    return v.round();
  }
  return 0;
}

const List<String> _activeStatuses = <String>[
  'placed',
  'accepted',
  'preparing',
  'ready',
];

String _statusLabel(String s) {
  switch (s) {
    case 'placed':
      return 'New order';
    case 'accepted':
      return 'Accepted';
    case 'preparing':
      return 'Preparing';
    case 'ready':
      return 'Ready for pickup';
    case 'picked':
      return 'Out for delivery';
    case 'delivered':
      return 'Delivered';
    case 'rejected':
      return 'Rejected';
    case 'cancelled':
      return 'Cancelled by customer';
    default:
      return s;
  }
}

Color _statusColor(String s) {
  switch (s) {
    case 'placed':
      return TwingaColors.orange;
    case 'accepted':
    case 'preparing':
    case 'picked':
      return TwingaColors.blue;
    case 'ready':
    case 'delivered':
      return TwingaColors.veg;
    case 'rejected':
    case 'cancelled':
      return TwingaColors.error;
    default:
      return TwingaColors.ink;
  }
}

IconData _statusIcon(String s) {
  switch (s) {
    case 'placed':
      return Icons.notifications_active;
    case 'accepted':
      return Icons.thumb_up_alt_outlined;
    case 'preparing':
      return Icons.soup_kitchen_outlined;
    case 'ready':
      return Icons.check_circle_outline;
    case 'picked':
      return Icons.delivery_dining;
    case 'delivered':
      return Icons.verified_outlined;
    default:
      return Icons.cancel_outlined;
  }
}

String _timeText(dynamic t) {
  if (t is! Timestamp) {
    return '';
  }
  final DateTime d = t.toDate();
  final int h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final String mm = d.minute.toString().padLeft(2, '0');
  final String ampm = d.hour >= 12 ? 'PM' : 'AM';
  return '$h12:$mm $ampm  ·  ${d.day}/${d.month}/${d.year}';
}

/// Button on the partner home screen. Shows how many new orders are waiting.
class OrdersButton extends StatelessWidget {
  const OrdersButton({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('restaurantOwnerUid', isEqualTo: uid)
          .where('status', isEqualTo: 'placed')
          .snapshots(),
      builder: (context, snap) {
        final int n = snap.data?.docs.length ?? 0;
        return FilledButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => RestaurantOrdersScreen(uid: uid),
              ),
            );
          },
          icon: Badge(
            isLabelVisible: n > 0,
            label: Text('$n'),
            child: const Icon(Icons.receipt_long),
          ),
          label: Text(n > 0 ? 'Orders  ·  $n new' : 'Orders'),
        );
      },
    );
  }
}

class RestaurantOrdersScreen extends StatelessWidget {
  const RestaurantOrdersScreen({super.key, required this.uid});

  final String uid;

  PreferredSizeWidget _bar({int active = 0, int history = 0, bool tabs = true}) {
    return AppBar(
      title: const Text('Orders', style: TextStyle(fontWeight: FontWeight.w800)),
      foregroundColor: Colors.white,
      backgroundColor: TwingaColors.blue,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A2A8F), TwingaColors.blue],
          ),
        ),
      ),
      bottom: tabs
          ? TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: TwingaColors.orange,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800),
              tabs: [
                Tab(text: 'Active  ·  $active'),
                Tab(text: 'History  ·  $history'),
              ],
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('restaurantOwnerUid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: _bar(tabs: false),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load orders:\n${snap.error}'),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return Scaffold(
            appBar: _bar(tabs: false),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> all =
            List<QueryDocumentSnapshot<Map<String, dynamic>>>.of(
                snap.data!.docs);
        int millis(QueryDocumentSnapshot<Map<String, dynamic>> x) {
          final dynamic t = x.data()['createdAt'];
          return t is Timestamp ? t.millisecondsSinceEpoch : 0;
        }

        all.sort((a, b) => millis(b).compareTo(millis(a)));
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> active = all
            .where((d) =>
                _activeStatuses.contains((d.data()['status'] ?? '').toString()))
            .toList();
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> history = all
            .where((d) =>
                !_activeStatuses.contains((d.data()['status'] ?? '').toString()))
            .toList();
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: _bar(active: active.length, history: history.length),
            body: TabBarView(
              children: [
                _OrderList(
                  docs: active,
                  icon: Icons.receipt_long,
                  emptyTitle: 'No active orders',
                  emptyText: 'New orders will appear here the moment a customer orders.',
                ),
                _OrderList(
                  docs: history,
                  icon: Icons.history,
                  emptyTitle: 'No past orders yet',
                  emptyText: 'Delivered and cancelled orders will be listed here.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.docs,
    required this.icon,
    required this.emptyTitle,
    required this.emptyText,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final IconData icon;
  final String emptyTitle;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  color: Color(0xFFE3EEFF),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 42, color: TwingaColors.blue),
              ),
              const SizedBox(height: 18),
              Text(
                emptyTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: TwingaColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(emptyText, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, i) => _OrderCard(doc: docs[i]),
    );
  }
}

class _OrderCard extends StatefulWidget {
  const _OrderCard({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _busy = false;

  Future<void> _update(Map<String, dynamic> changes) async {
    setState(() {
      _busy = true;
    });
    try {
      await widget.doc.reference.update(<String, dynamic>{
        ...changes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not update this order. It may have been cancelled by the customer.',
            ),
          ),
        );
      }
    }
    if (mounted) {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _accept(int defaultMin) async {
    int chosen = defaultMin;
    final int? picked = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              title: const Text('Accept order'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How long will it take to prepare?'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final int m in <int>[10, 15, 20, 30, 40, 50])
                        ChoiceChip(
                          label: Text('$m min'),
                          selected: chosen == m,
                          onSelected: (_) {
                            setLocal(() {
                              chosen = m;
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(chosen),
                  child: const Text('Accept'),
                ),
              ],
            );
          },
        );
      },
    );
    if (picked == null) {
      return;
    }
    await _update(<String, dynamic>{
      'status': 'accepted',
      'prepTimeMin': picked,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _reject() async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Reject this order?'),
        content: const Text('The customer will be told you could not accept it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Go back'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (yes != true) {
      return;
    }
    await _update(<String, dynamic>{'status': 'rejected'});
  }

  Widget _bigButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> d = widget.doc.data();
    final String status = (d['status'] ?? '').toString();
    final String customer = (d['customerName'] ?? '').toString();
    final String riderName = (d['riderName'] ?? '').toString();
    final dynamic rawItems = d['items'];
    final List<dynamic> items = rawItems is List ? rawItems : <dynamic>[];
    final int food = _intOf(d['foodSubtotalPaise']);
    final int prep = _intOf(d['prepTimeMin']);
    final String shortId = widget.doc.id.length > 5
        ? widget.doc.id.substring(widget.doc.id.length - 5).toUpperCase()
        : widget.doc.id.toUpperCase();
    final Color sc = _statusColor(status);
    Widget actions = const SizedBox.shrink();
    if (_busy) {
      actions = const Padding(
        padding: EdgeInsets.only(top: 14),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (status == 'placed') {
      actions = Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _reject,
                style: OutlinedButton.styleFrom(
                  foregroundColor: TwingaColors.error,
                  minimumSize: const Size.fromHeight(50),
                  side: const BorderSide(color: TwingaColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Reject',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _bigButton(
                'Accept',
                Icons.check,
                TwingaColors.veg,
                () => _accept(prep > 0 ? prep : 20),
              ),
            ),
          ],
        ),
      );
    } else if (status == 'accepted') {
      actions = Padding(
        padding: const EdgeInsets.only(top: 14),
        child: _bigButton(
          'Start preparing',
          Icons.soup_kitchen_outlined,
          TwingaColors.blue,
          () => _update(<String, dynamic>{'status': 'preparing'}),
        ),
      );
    } else if (status == 'preparing') {
      actions = Padding(
        padding: const EdgeInsets.only(top: 14),
        child: _bigButton(
          'Mark as ready',
          Icons.check_circle_outline,
          TwingaColors.veg,
          () => _update(<String, dynamic>{'status': 'ready'}),
        ),
      );
    } else if (status == 'ready') {
      actions = Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F6EC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.delivery_dining, color: TwingaColors.veg),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Waiting for the delivery partner to pick this up.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: status == 'placed' ? TwingaColors.orange : const Color(0xFFE3EAF7),
          width: status == 'placed' ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140A2A8F),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFE3EEFF),
                  child: Text(
                    customer.isEmpty ? '?' : customer.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: TwingaColors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #$shortId',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: TwingaColors.ink,
                        ),
                      ),
                      Text(
                        customer.isEmpty ? 'Customer' : customer,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: sc.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(status), size: 14, color: sc),
                      const SizedBox(width: 4),
                      Text(
                        _statusLabel(status),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: sc,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 14, color: Colors.black45),
                const SizedBox(width: 4),
                Text(
                  _timeText(d['createdAt']),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (prep > 0 && status != 'placed' && _activeStatuses.contains(status)) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.timer_outlined, size: 14, color: Colors.black45),
                  const SizedBox(width: 4),
                  Text(
                    'Prep $prep min',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ],
            ),
            const Divider(height: 24),
            for (final dynamic it in items)
              if (it is Map)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: it['isVeg'] == false
                                ? const Color(0xFFB71C1C)
                                : TwingaColors.veg,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.circle,
                            size: 8,
                            color: it['isVeg'] == false
                                ? const Color(0xFFB71C1C)
                                : TwingaColors.veg,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3EEFF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${it['qty'] ?? 1}×',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: TwingaColors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${it['name'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        _rupees(_intOf(it['pricePaise']) * (_intOf(it['qty']) == 0 ? 1 : _intOf(it['qty']))),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Food total',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  _rupees(food),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: TwingaColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5FC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.payments_outlined, size: 14),
                      SizedBox(width: 4),
                      Text('Cash on delivery', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                if (riderName.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3EEFF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.two_wheeler,
                          size: 14,
                          color: TwingaColors.blue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Rider: $riderName',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            actions,
          ],
        ),
      ),
    );
  }
}
