import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import 'order_status_screen.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    return Scaffold(
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
                  return const Center(child: Text('You have no orders yet.'));
                }
                int millis(QueryDocumentSnapshot<Map<String, dynamic>> x) {
                  final dynamic t = x.data()['createdAt'];
                  if (t is Timestamp) {
                    return t.millisecondsSinceEpoch;
                  }
                  return 0;
                }

                docs.sort((a, b) => millis(b).compareTo(millis(a)));
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final QueryDocumentSnapshot<Map<String, dynamic>> doc =
                        docs[index];
                    final Map<String, dynamic> d = doc.data();
                    final dynamic total = d['totalPaise'];
                    final int totalPaise = total is num ? total.round() : 0;
                    return Card(
                      color: Colors.white,
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  OrderStatusScreen(orderId: doc.id),
                            ),
                          );
                        },
                        title: Text(
                          (d['restaurantName'] ?? '').toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: TwingaColors.ink,
                          ),
                        ),
                        subtitle: Text(
                          orderStatusText((d['status'] ?? '').toString()),
                        ),
                        trailing: Text(
                          rupees(totalPaise),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
