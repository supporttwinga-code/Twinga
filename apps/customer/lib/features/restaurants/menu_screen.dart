import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import 'restaurant_models.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(restaurant.name)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('restaurants')
            .doc(restaurant.id)
            .collection('menu')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load menu:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<MenuItem> items =
              snapshot.data!.docs.map((d) => MenuItem.fromDoc(d)).toList();
          if (items.isEmpty) {
            return const Center(child: Text('Menu is empty.'));
          }
          final Map<String, List<MenuItem>> byCategory =
              <String, List<MenuItem>>{};
          for (final MenuItem item in items) {
            byCategory.putIfAbsent(item.category, () => <MenuItem>[]).add(item);
          }
          final List<String> categories = byCategory.keys.toList()..sort();
          final List<Widget> children = <Widget>[];
          if (restaurant.packagingChargePaise > 0) {
            children.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  'Packaging charge: ${rupees(restaurant.packagingChargePaise)} per order',
                ),
              ),
            );
          }
          for (final String category in categories) {
            children.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  category,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: TwingaColors.ink,
                  ),
                ),
              ),
            );
            for (final MenuItem item in byCategory[category]!) {
              children.add(_MenuTile(item: item));
            }
          }
          children.add(const SizedBox(height: 24));
          return ListView(children: children);
        },
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VegMark(isVeg: item.isVeg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: TwingaColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rupees(item.pricePaise),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (item.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(item.description),
                  ),
                if (!item.isAvailable)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'Currently unavailable',
                      style: TextStyle(
                        color: TwingaColors.error,
                        fontWeight: FontWeight.w600,
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

class _VegMark extends StatelessWidget {
  const _VegMark({required this.isVeg});

  final bool isVeg;

  @override
  Widget build(BuildContext context) {
    final Color c = isVeg ? TwingaColors.veg : const Color(0xFFB71C1C);
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.only(top: 3),
      decoration: BoxDecoration(
        border: Border.all(color: c, width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
