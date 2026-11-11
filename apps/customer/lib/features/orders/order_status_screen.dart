import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/theme.dart';

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

class OrderStatusScreen extends StatelessWidget {
  const OrderStatusScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final DocumentReference<Map<String, dynamic>> ref =
        FirebaseFirestore.instance.collection('orders').doc(orderId);
    return Scaffold(
      appBar: AppBar(title: const Text('Your order')),
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
          final String rname = (d['restaurantName'] ?? '').toString();
          final dynamic total = d['totalPaise'];
          final int totalPaise = total is num ? total.round() : 0;
          final dynamic rawItems = d['items'];
          final List<dynamic> items = rawItems is List ? rawItems : <dynamic>[];
          final String riderName = (d['riderName'] ?? '').toString();
          final bool showOtp = status == 'placed' ||
              status == 'accepted' ||
              status == 'preparing' ||
              status == 'ready' ||
              status == 'picked';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                rname,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: TwingaColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                orderStatusText(status),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              if (riderName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Delivery partner: $riderName'),
              ],
              const SizedBox(height: 16),
              if (showOtp) _OtpCard(ref: ref),
              const SizedBox(height: 16),
              for (final dynamic it in items)
                if (it is Map)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('${it['qty'] ?? 1} x ${it['name'] ?? ''}')),
                        Text(
                          rupees(
                            ((it['qty'] is num ? it['qty'] as num : 1) *
                                    (it['pricePaise'] is num
                                        ? it['pricePaise'] as num
                                        : 0))
                                .round(),
                          ),
                        ),
                      ],
                    ),
                  ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total (cash on delivery)',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    rupees(totalPaise),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              if (status == 'placed') ...[
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () async {
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
                        const SnackBar(
                          content: Text('Could not cancel the order.'),
                        ),
                      );
                    }
                  },
                  child: const Text('Cancel order'),
                ),
              ],
            ],
          );
        },
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
        return Card(
          color: const Color(0xFFE3EEFF),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Delivery OTP'),
                const SizedBox(height: 4),
                Text(
                  code,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: TwingaColors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tell this OTP to the delivery partner only when you receive your order.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
