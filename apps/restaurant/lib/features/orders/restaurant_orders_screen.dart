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
      return 'Picked up';
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

String _timeText(dynamic t) {
  if (t is! Timestamp) {
    return '';
  }
  final DateTime d = t.toDate();
  final int h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final String mm = d.minute.toString().padLeft(2, '0');
  final String ampm = d.hour >= 12 ? 'PM' : 'AM';
  return '${d.day}/${d.month}/${d.year}  $h12:$mm $ampm';
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Orders'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('restaurantOwnerUid', isEqualTo: uid)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load orders:\n${snap.error}'),
                ),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final List<QueryDocumentSnapshot<Map<String, dynamic>>> all =
                List<QueryDocumentSnapshot<Map<String, dynamic>>>.of(
                    snap.data!.docs);
            int millis(QueryDocumentSnapshot<Map<String, dynamic>> x) {
              final dynamic t = x.data()['createdAt'];
              return t is Timestamp ? t.millisecondsSinceEpoch : 0;
            }

            all.sort((a, b) => millis(b).compareTo(millis(a)));
            final List<QueryDocumentSnapshot<Map<String, dynamic>>> active =
                all
                    .where((d) =>
                        _activeStatuses.contains((d.data()['status'] ?? '').toString()))
                    .toList();
            final List<QueryDocumentSnapshot<Map<String, dynamic>>> history =
                all
                    .where((d) =>
                        !_activeStatuses.contains((d.data()['status'] ?? '').toString()))
                    .toList();
            return TabBarView(
              children: [
                _OrderList(
                  docs: active,
                  emptyText: 'No active orders right now.',
                ),
                _OrderList(
                  docs: history,
                  emptyText: 'No past orders yet.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({required this.docs, required this.emptyText});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return Center(child: Text(emptyText));
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

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> d = widget.doc.data();
    final String status = (d['status'] ?? '').toString();
    final String customer = (d['customerName'] ?? '').toString();
    final dynamic rawItems = d['items'];
    final List<dynamic> items = rawItems is List ? rawItems : <dynamic>[];
    final int food = _intOf(d['foodSubtotalPaise']);
    final int prep = _intOf(d['prepTimeMin']);
    final String shortId = widget.doc.id.length > 5
        ? widget.doc.id.substring(widget.doc.id.length - 5).toUpperCase()
        : widget.doc.id.toUpperCase();
    Widget actions = const SizedBox.shrink();
    if (_busy) {
      actions = const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (status == 'placed') {
      actions = Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _reject,
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => _accept(prep > 0 ? prep : 20),
                child: const Text('Accept'),
              ),
            ),
          ],
        ),
      );
    } else if (status == 'accepted') {
      actions = Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => _update(<String, dynamic>{'status': 'preparing'}),
            child: const Text('Start preparing'),
          ),
        ),
      );
    } else if (status == 'preparing') {
      actions = Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => _update(<String, dynamic>{'status': 'ready'}),
            child: const Text('Mark as ready'),
          ),
        ),
      );
    } else if (status == 'ready') {
      actions = const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text('Waiting for the delivery partner to pick this up.'),
      );
    }
    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #$shortId',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: TwingaColors.ink,
                    ),
                  ),
                ),
                Text(
                  _statusLabel(status),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: (status == 'rejected' || status == 'cancelled')
                        ? TwingaColors.error
                        : TwingaColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              [
                if (customer.isNotEmpty) customer,
                _timeText(d['createdAt']),
              ].where((s) => s.isNotEmpty).join('  ·  '),
            ),
            const Divider(height: 20),
            for (final dynamic it in items)
              if (it is Map)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: it['isVeg'] == false
                            ? const Color(0xFFB71C1C)
                            : TwingaColors.veg,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${it['qty'] ?? 1} x ${it['name'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Food total'),
                Text(
                  _rupees(food),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const Text(
              'Payment: Cash on delivery',
              style: TextStyle(fontSize: 12),
            ),
            actions,
          ],
        ),
      ),
    );
  }
}
