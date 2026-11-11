import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../address/address_model.dart';
import '../cart/pricing.dart';
import 'menu_screen.dart';
import 'restaurant_models.dart';

Widget _centerText(String text) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

/// Shows restaurants that deliver to the customer's selected address.
class NearbyRestaurants extends StatelessWidget {
  const NearbyRestaurants({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final DocumentReference<Map<String, dynamic>> userRef =
        FirebaseFirestore.instance.collection('users').doc(uid);
    const String noAddress =
        'Add your delivery address above to see restaurants that deliver to you.';
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userRef.snapshots(),
      builder: (context, userSnap) {
        final dynamic raw = userSnap.data?.data()?['defaultAddressId'];
        if (raw is! String || raw.isEmpty) {
          return _centerText(noAddress);
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userRef.collection('addresses').doc(raw).snapshots(),
          builder: (context, addrSnap) {
            final DocumentSnapshot<Map<String, dynamic>>? doc = addrSnap.data;
            if (doc == null || !doc.exists) {
              return _centerText(noAddress);
            }
            final SavedAddress a = SavedAddress.fromDoc(doc);
            return RestaurantList(lat: a.lat, lng: a.lng);
          },
        );
      },
    );
  }
}

class _Nearby {
  const _Nearby(this.restaurant, this.meters);

  final Restaurant restaurant;
  final int meters;
}

class RestaurantList extends StatelessWidget {
  const RestaurantList({super.key, required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('restaurants')
          .where('status', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _centerText('Could not load restaurants:\n${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<_Nearby> list = <_Nearby>[];
        for (final QueryDocumentSnapshot<Map<String, dynamic>> d
            in snapshot.data!.docs) {
          final Restaurant r = Restaurant.fromDoc(d);
          if (!r.hasLocation) {
            continue;
          }
          final int m = distanceMeters(lat, lng, r.lat, r.lng);
          if (m <= r.radiusKm * 1000) {
            list.add(_Nearby(r, m));
          }
        }
        list.sort((a, b) {
          if (a.restaurant.isOpen != b.restaurant.isOpen) {
            return a.restaurant.isOpen ? -1 : 1;
          }
          return a.meters.compareTo(b.meters);
        });
        if (list.isEmpty) {
          return _centerText('No restaurants available right now.');
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: list.length,
          itemBuilder: (context, index) {
            return _RestaurantCard(item: list[index]);
          },
        );
      },
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({required this.item});

  final _Nearby item;

  @override
  Widget build(BuildContext context) {
    final Restaurant r = item.restaurant;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => MenuScreen(restaurant: r),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: r.imageUrl.isEmpty
                      ? const _ImagePlaceholder()
                      : Image.network(
                          r.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const _ImagePlaceholder(),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: TwingaColors.ink,
                      ),
                    ),
                    if (r.cuisines.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          r.cuisines,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 18, color: TwingaColors.veg),
                        const SizedBox(width: 2),
                        Text(
                          r.rating > 0 ? r.rating.toStringAsFixed(1) : 'New',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.schedule, size: 16),
                        const SizedBox(width: 2),
                        Text('${r.prepTimeMin} min'),
                        const SizedBox(width: 10),
                        Text('${(item.meters / 1000).toStringAsFixed(1)} km'),
                        if (!r.isOpen) ...[
                          const SizedBox(width: 10),
                          const Text(
                            'Closed',
                            style: TextStyle(
                              color: TwingaColors.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE3EEFF),
      child: const Icon(Icons.storefront, size: 32, color: TwingaColors.blue),
    );
  }
}
