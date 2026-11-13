import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';

int _i(dynamic v) {
  if (v is num) {
    return v.round();
  }
  return 0;
}

String rupeesText(int paise) {
  final int whole = paise ~/ 100;
  final int rem = paise % 100;
  if (rem == 0) {
    return '₹$whole';
  }
  return '₹$whole.${rem.toString().padLeft(2, '0')}';
}

const List<String> _activeStatuses = <String>[
  'placed',
  'accepted',
  'preparing',
  'ready',
];

/// Numbers worked out only from the restaurant's real orders.
/// Earnings of an order = food total minus the Twinga commission.
class PartnerStats {
  PartnerStats._({
    required this.deliveredCount,
    required this.earnedPaise,
    required this.todayOrders,
    required this.todayPaise,
    required this.weekPaise,
    required this.perDay,
    required this.activeCount,
    required this.newCount,
    required this.latestActive,
  });

  final int deliveredCount;
  final int earnedPaise;
  final int todayOrders;
  final int todayPaise;
  final int weekPaise;
  final List<int> perDay;
  final int activeCount;
  final int newCount;
  final QueryDocumentSnapshot<Map<String, dynamic>>? latestActive;

  factory PartnerStats.from(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    int delivered = 0;
    int earned = 0;
    int todayOrders = 0;
    int todayPaise = 0;
    int week = 0;
    int active = 0;
    int fresh = 0;
    final List<int> perDay = List<int>.filled(7, 0);
    QueryDocumentSnapshot<Map<String, dynamic>>? latest;
    DateTime latestTime = DateTime.fromMillisecondsSinceEpoch(0);
    for (final QueryDocumentSnapshot<Map<String, dynamic>> d in docs) {
      final Map<String, dynamic> m = d.data();
      final String status = (m['status'] ?? '').toString();
      final dynamic created = m['createdAt'];
      final DateTime? cDate = created is Timestamp ? created.toDate() : null;
      if (status == 'placed') {
        fresh++;
      }
      if (_activeStatuses.contains(status)) {
        active++;
        final DateTime t = cDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        if (latest == null || t.isAfter(latestTime)) {
          latest = d;
          latestTime = t;
        }
      }
      if (cDate != null && status != 'rejected' && status != 'cancelled') {
        final DateTime day = DateTime(cDate.year, cDate.month, cDate.day);
        if (day == today) {
          todayOrders++;
        }
      }
      if (status == 'delivered') {
        delivered++;
        final int earn = _i(m['foodSubtotalPaise']) - _i(m['commissionPaise']);
        earned += earn;
        final dynamic u = m['updatedAt'] ?? m['createdAt'];
        if (u is Timestamp) {
          final DateTime ud = u.toDate();
          final DateTime day = DateTime(ud.year, ud.month, ud.day);
          final int ago = today.difference(day).inDays;
          if (ago >= 0 && ago < 7) {
            perDay[6 - ago] += earn;
            week += earn;
            if (ago == 0) {
              todayPaise += earn;
            }
          }
        }
      }
    }
    return PartnerStats._(
      deliveredCount: delivered,
      earnedPaise: earned,
      todayOrders: todayOrders,
      todayPaise: todayPaise,
      weekPaise: week,
      perDay: perDay,
      activeCount: active,
      newCount: fresh,
      latestActive: latest,
    );
  }
}

List<String> weekLabels() {
  const List<String> names = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  return <String>[
    for (int i = 6; i >= 0; i--)
      names[today.subtract(Duration(days: i)).weekday - 1],
  ];
}

class WeekBars extends StatelessWidget {
  const WeekBars({super.key, required this.values, required this.labels});

  final List<int> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    int maxV = 0;
    for (final int v in values) {
      if (v > maxV) {
        maxV = v;
      }
    }
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < values.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (values[i] > 0)
                    Text(
                      '₹${values[i] ~/ 100}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  const SizedBox(height: 4),
                  Container(
                    height: maxV == 0 ? 4.0 : 4.0 + 90.0 * values[i] / maxV,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: values[i] > 0
                          ? TwingaColors.blue
                          : const Color(0xFFD5E3FA),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(labels[i], style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key, required this.uid});

  final String uid;

  Widget _tile(String label, String value) {
    return Expanded(
      child: Card(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: TwingaColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
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
                child: Text('Could not load earnings:\n${snap.error}'),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final PartnerStats s = PartnerStats.from(snap.data!.docs);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0A2A8F), TwingaColors.blue],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total earned',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rupeesText(s.earnedPaise),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'From ${s.deliveredCount} delivered orders',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _tile('Today', rupeesText(s.todayPaise)),
                  _tile('Last 7 days', rupeesText(s.weekPaise)),
                ],
              ),
              const SizedBox(height: 4),
              Card(
                color: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Last 7 days',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: TwingaColors.ink,
                        ),
                      ),
                      const SizedBox(height: 12),
                      WeekBars(values: s.perDay, labels: weekLabels()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Earnings of an order = food total minus Twinga commission. '
                'Only delivered orders are counted. Withdrawals will open in the next update.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }
}
