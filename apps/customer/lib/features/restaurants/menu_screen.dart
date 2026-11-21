import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../cart/cart.dart';
import '../cart/checkout_screen.dart';
import 'restaurant_models.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key, required this.restaurant});

  final Restaurant restaurant;

  Future<void> _add(BuildContext context, MenuItem item) async {
    if (cart.belongsToOther(restaurant)) {
      final String other = cart.restaurant?.name ?? 'another restaurant';
      final bool? yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start a new cart?'),
          content: Text(
            'Your cart has items from $other. Adding this item will remove them.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Start new cart'),
            ),
          ],
        ),
      );
      if (yes != true) {
        return;
      }
    }
    cart.add(restaurant, item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(restaurant.name)),
      bottomNavigationBar: AnimatedBuilder(
        animation: cart,
        builder: (context, child) {
          final Restaurant? current = cart.restaurant;
          if (cart.isEmpty || current == null || current.id != restaurant.id) {
            return const SizedBox.shrink();
          }
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const CheckoutScreen(),
                    ),
                  );
                },
                child: Text(
                  'View cart  ·  ${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'}  ·  ${rupees(cart.foodPaise)}',
                ),
              ),
            ),
          );
        },
      ),
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
          if (!restaurant.isOpen) {
            children.add(
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  'This restaurant is closed right now.',
                  style: TextStyle(
                    color: TwingaColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }
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
              children.add(
                _MenuTile(
                  item: item,
                  enabled: restaurant.isOpen && item.isAvailable,
                  onAdd: () => _add(context, item),
                ),
              );
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
  const _MenuTile({
    required this.item,
    required this.enabled,
    required this.onAdd,
  });

  final MenuItem item;
  final bool enabled;
  final VoidCallback onAdd;

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
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.imageBytes != null) _ItemPhoto(bytes: item.imageBytes!),
              if (enabled)
            AnimatedBuilder(
              animation: cart,
              builder: (context, child) {
                final int q = cart.qtyOf(item.id);
                if (q == 0) {
                  return OutlinedButton(
                    onPressed: onAdd,
                    child: const Text('ADD'),
                  );
                }
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => cart.decrease(item.id),
                    ),
                    Text(
                      '$q',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: onAdd,
                    ),
                  ],
                );
              },
            ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemPhoto extends StatelessWidget {
  const _ItemPhoto({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.memory(
          bytes,
          width: 92,
          height: 92,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        ),
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
