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

String _dateText(dynamic t) {
  if (t is! Timestamp) {
    return '';
  }
  final DateTime d = t.toDate();
  final int h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final String mm = d.minute.toString().padLeft(2, '0');
  final String ampm = d.hour >= 12 ? 'PM' : 'AM';
  return '${d.day}/${d.month}/${d.year}  ·  $h12:$mm $ampm';
}

DateTime? _doneTime(Map<String, dynamic> m) {
  final dynamic u = m['updatedAt'] ?? m['createdAt'];
  return u is Timestamp ? u.toDate() : null;
}

/// Numbers worked out only from the rider's own delivered orders.
class RiderStats {
  RiderStats._({
    required this.deliveredCount,
    required this.earnedPaise,
    required this.todayTrips,
    required this.todayPaise,
    required this.weekPaise,
    required this.perDay,
    required this.cashCollectedPaise,
    required this.delivered,
  });

  final int deliveredCount;
  final int earnedPaise;
  final int todayTrips;
  final int todayPaise;
  final int weekPaise;
  final List<int> perDay;
  final int cashCollectedPaise;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> delivered;

  factory RiderStats.from(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    int earned = 0;
    int cash = 0;
    int todayTrips = 0;
    int todayPaise = 0;
    int week = 0;
    final List<int> perDay = List<int>.filled(7, 0);
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> done =
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> d in docs) {
      final Map<String, dynamic> m = d.data();
      if ((m['status'] ?? '').toString() != 'delivered') {
        continue;
      }
      done.add(d);
      final int earn = _i(m['riderPayPaise']);
      earned += earn;
      cash += _i(m['totalPaise']);
      final DateTime? t = _doneTime(m);
      if (t != null) {
        final DateTime day = DateTime(t.year, t.month, t.day);
        final int ago = today.difference(day).inDays;
        if (ago >= 0 && ago < 7) {
          perDay[6 - ago] += earn;
          week += earn;
          if (ago == 0) {
            todayTrips++;
            todayPaise += earn;
          }
        }
      }
    }
    done.sort((a, b) {
      final DateTime x = _doneTime(a.data()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime y = _doneTime(b.data()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return y.compareTo(x);
    });
    return RiderStats._(
      deliveredCount: done.length,
      earnedPaise: earned,
      todayTrips: todayTrips,
      todayPaise: todayPaise,
      weekPaise: week,
      perDay: perDay,
      cashCollectedPaise: cash,
      delivered: done,
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

Stream<QuerySnapshot<Map<String, dynamic>>> _myOrders(String uid) {
  return FirebaseFirestore.instance
      .collection('orders')
      .where('riderUid', isEqualTo: uid)
      .snapshots();
}

class RiderEarningsScreen extends StatelessWidget {
  const RiderEarningsScreen({super.key, required this.uid});

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
        stream: _myOrders(uid),
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
          final RiderStats s = RiderStats.from(snap.data!.docs);
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
                      'From ${s.deliveredCount} deliveries',
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
              const SizedBox(height: 8),
              Card(
                color: const Color(0xFFFFF4E0),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.payments_outlined, color: TwingaColors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cash collected from customers',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              rupeesText(s.cashCollectedPaise),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: TwingaColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Only delivered orders are counted. Depositing the collected cash and '
                'withdrawing your earnings will open in the next update.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }
}

class DeliveryHistoryScreen extends StatelessWidget {
  const DeliveryHistoryScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery history')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _myOrders(uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load history:\n${snap.error}'),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final RiderStats s = RiderStats.from(snap.data!.docs);
          if (s.delivered.isEmpty) {
            return const Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No deliveries yet. Your completed deliveries will be listed here.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: s.delivered.length,
            itemBuilder: (context, i) {
              final Map<String, dynamic> m = s.delivered[i].data();
              final String id = s.delivered[i].id;
              final String shortId = id.length > 5
                  ? id.substring(id.length - 5).toUpperCase()
                  : id.toUpperCase();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE3EAF7)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFE8F6EC),
                      child: Icon(Icons.check, color: TwingaColors.veg),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (m['restaurantName'] ?? '').toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: TwingaColors.ink,
                            ),
                          ),
                          Text(
                            'Order #$shortId  ·  ${(_i(m['distanceMeters']) / 1000).toStringAsFixed(1)} km',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            _dateText(m['updatedAt'] ?? m['createdAt']),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '+${rupeesText(_i(m['riderPayPaise']))}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: TwingaColors.veg,
                          ),
                        ),
                        Text(
                          'Cash ${rupeesText(_i(m['totalPaise']))}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
