import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'menu_item_screen.dart';

String _rupees(int paise) {
  final int whole = paise ~/ 100;
  final int rem = paise % 100;
  if (rem == 0) {
    return '₹$whole';
  }
  return '₹$whole.${rem.toString().padLeft(2, '0')}';
}

class MenuManagerScreen extends StatelessWidget {
  const MenuManagerScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  final String restaurantId;
  final String restaurantName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage menu')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => MenuItemScreen(restaurantId: restaurantId),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('restaurants')
            .doc(restaurantId)
            .collection('menu')
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load menu:\n${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
              List<QueryDocumentSnapshot<Map<String, dynamic>>>.of(
                  snap.data!.docs);
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No items yet. Tap "Add item" to build your menu.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          docs.sort((a, b) {
            final String ca = (a.data()['category'] ?? '').toString().toLowerCase();
            final String cb = (b.data()['category'] ?? '').toString().toLowerCase();
            final int c = ca.compareTo(cb);
            if (c != 0) {
              return c;
            }
            final String na = (a.data()['name'] ?? '').toString().toLowerCase();
            final String nb = (b.data()['name'] ?? '').toString().toLowerCase();
            return na.compareTo(nb);
          });
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final QueryDocumentSnapshot<Map<String, dynamic>> doc = docs[index];
              final Map<String, dynamic> d = doc.data();
              final String name = (d['name'] ?? 'Item').toString();
              final String category = (d['category'] ?? '').toString();
              final dynamic p = d['pricePaise'];
              final int paise = p is num ? p.round() : 0;
              final bool isVeg = d['isVeg'] is bool ? d['isVeg'] as bool : true;
              final bool available =
                  d['isAvailable'] is bool ? d['isAvailable'] as bool : false;
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
                        builder: (context) => MenuItemScreen(
                          restaurantId: restaurantId,
                          existing: doc,
                        ),
                      ),
                    );
                  },
                  leading: Icon(
                    Icons.circle,
                    size: 14,
                    color: isVeg ? TwingaColors.veg : const Color(0xFFB71C1C),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: TwingaColors.ink,
                    ),
                  ),
                  subtitle: Text(
                    category.isEmpty
                        ? _rupees(paise)
                        : '${_rupees(paise)} · $category',
                  ),
                  trailing: Switch(
                    value: available,
                    onChanged: (bool v) {
                      doc.reference.update(<String, dynamic>{
                        'isAvailable': v,
                      });
                    },
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
