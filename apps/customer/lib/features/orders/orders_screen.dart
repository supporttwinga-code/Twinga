import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import 'order_status_screen.dart';

const List<String> _liveStatuses = <String>[
  'placed',
  'accepted',
  'preparing',
  'ready',
  'picked',
];

const List<String> _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _when(dynamic t) {
  if (t is! Timestamp) {
    return '';
  }
  final DateTime d = t.toDate();
  final int h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final String m = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${_months[d.month - 1]}, $h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
}

String _chipText(String s) {
  switch (s) {
    case 'placed':
      return 'Placed';
    case 'accepted':
      return 'Accepted';
    case 'preparing':
      return 'Preparing';
    case 'ready':
      return 'Ready';
    case 'picked':
      return 'On the way';
    case 'delivered':
      return 'Delivered';
    case 'rejected':
      return 'Rejected';
    case 'cancelled':
      return 'Cancelled';
    default:
      return s;
  }
}

Color _chipColor(String s) {
  if (s == 'delivered') {
    return TwingaColors.veg;
  }
  if (s == 'cancelled' || s == 'rejected') {
    return TwingaColors.error;
  }
  return TwingaColors.blue;
}

String _itemsLine(dynamic raw) {
  if (raw is! List) {
    return '';
  }
  final List<String> parts = <String>[];
  for (final dynamic it in raw) {
    if (it is Map) {
      parts.add('${it['qty'] ?? 1} x ${it['name'] ?? ''}');
    }
  }
  return parts.join(', ');
}

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: TwingaColors.background,
      appBar: AppBar(title: const Text('My orders')),
      body: user == null
          ? const SizedBox.shrink()
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('customerUid', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text('Could not load orders:\n${snap.error}'),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                    List<QueryDocumentSnapshot<Map<String, dynamic>>>.of(
                        snap.data!.docs);
                if (docs.isEmpty) {
                  return const _Empty();
                }
                int millis(QueryDocumentSnapshot<Map<String, dynamic>> x) {
                  final dynamic t = x.data()['createdAt'];
                  if (t is Timestamp) {
                    return t.millisecondsSinceEpoch;
                  }
                  return 0;
                }

                docs.sort((a, b) => millis(b).compareTo(millis(a)));
                final List<QueryDocumentSnapshot<Map<String, dynamic>>> live =
                    docs
                        .where((x) => _liveStatuses
                            .contains((x.data()['status'] ?? '').toString()))
                        .toList();
                final List<QueryDocumentSnapshot<Map<String, dynamic>>> past =
                    docs
                        .where((x) => !_liveStatuses
                            .contains((x.data()['status'] ?? '').toString()))
                        .toList();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  children: [
                    if (live.isNotEmpty) ...[
                      const _Heading('Ongoing'),
                      for (final QueryDocumentSnapshot<Map<String, dynamic>> d
                          in live)
                        _OrderTile(doc: d, live: true),
                    ],
                    if (past.isNotEmpty) ...[
                      const _Heading('Past orders'),
                      for (final QueryDocumentSnapshot<Map<String, dynamic>> d
                          in past)
                        _OrderTile(doc: d, live: false),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F1FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 44,
                color: TwingaColors.blue,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'You have no orders yet.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: TwingaColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your orders will show up here.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: TwingaColors.ink,
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.doc, required this.live});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> d = doc.data();
    final String status = (d['status'] ?? '').toString();
    final String name = (d['restaurantName'] ?? '').toString();
    final dynamic total = d['totalPaise'];
    final int totalPaise = total is num ? total.round() : 0;
    final Color chip = _chipColor(status);
    final String initial = name.trim().isEmpty ? 'T' : name.trim()[0].toUpperCase();
    final String items = _itemsLine(d['items']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: live ? TwingaColors.blue.withAlpha(90) : const Color(0xFFE3EAF7),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120A2A8F),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => OrderStatusScreen(orderId: doc.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3AA4FF), Color(0xFF0A3FB5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w900,
                              color: TwingaColors.ink,
                            ),
                          ),
                          Text(
                            _when(d['createdAt']),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: chip.withAlpha(28),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _chipText(status),
                        style: TextStyle(
                          color: chip,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    items,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54, height: 1.3),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      rupees(totalPaise),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: TwingaColors.ink,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      live ? 'Track order' : 'View details',
                      style: const TextStyle(
                        color: TwingaColors.blue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: TwingaColors.blue,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
