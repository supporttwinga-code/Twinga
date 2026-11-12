import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../address/address_model.dart';
import '../cart/pricing.dart';
import 'menu_screen.dart';
import 'restaurant_models.dart';

const String kNoAddressMessage =
    'Add your delivery address to see restaurants that deliver to you.';
const String kNoRestaurantsMessage = 'No restaurants available right now.';

class NearbyItem {
  const NearbyItem(this.restaurant, this.meters);

  final Restaurant restaurant;
  final int meters;
}

class NearbyState {
  const NearbyState({
    this.items = const <NearbyItem>[],
    this.message,
    this.loading = false,
  });

  final List<NearbyItem> items;
  final String? message;
  final bool loading;
}

/// Streams the customer's selected address and the approved restaurants,
/// keeps only the ones that deliver to that address, and hands the result
/// to [builder].
class NearbyBuilder extends StatelessWidget {
  const NearbyBuilder({super.key, required this.uid, required this.builder});

  final String uid;
  final Widget Function(BuildContext context, NearbyState state) builder;

  @override
  Widget build(BuildContext context) {
    final DocumentReference<Map<String, dynamic>> userRef =
        FirebaseFirestore.instance.collection('users').doc(uid);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userRef.snapshots(),
      builder: (context, userSnap) {
        if (userSnap.hasError) {
          return builder(
            context,
            NearbyState(message: 'Could not load your profile:\n${userSnap.error}'),
          );
        }
        if (!userSnap.hasData) {
          return builder(context, const NearbyState(loading: true));
        }
        final dynamic raw = userSnap.data!.data()?['defaultAddressId'];
        if (raw is! String || raw.isEmpty) {
          return builder(context, const NearbyState(message: kNoAddressMessage));
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userRef.collection('addresses').doc(raw).snapshots(),
          builder: (context, addrSnap) {
            if (addrSnap.hasError) {
              return builder(
                context,
                NearbyState(message: 'Could not load your address:\n${addrSnap.error}'),
              );
            }
            if (!addrSnap.hasData) {
              return builder(context, const NearbyState(loading: true));
            }
            final DocumentSnapshot<Map<String, dynamic>> doc = addrSnap.data!;
            if (!doc.exists) {
              return builder(context, const NearbyState(message: kNoAddressMessage));
            }
            final SavedAddress a = SavedAddress.fromDoc(doc);
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('restaurants')
                  .where('status', isEqualTo: 'approved')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return builder(
                    context,
                    NearbyState(message: 'Could not load restaurants:\n${snap.error}'),
                  );
                }
                if (!snap.hasData) {
                  return builder(context, const NearbyState(loading: true));
                }
                final List<NearbyItem> list = <NearbyItem>[];
                for (final QueryDocumentSnapshot<Map<String, dynamic>> d
                    in snap.data!.docs) {
                  final Restaurant r = Restaurant.fromDoc(d);
                  if (!r.hasLocation) {
                    continue;
                  }
                  final int m = distanceMeters(a.lat, a.lng, r.lat, r.lng);
                  if (m <= r.radiusKm * 1000) {
                    list.add(NearbyItem(r, m));
                  }
                }
                list.sort((x, y) {
                  if (x.restaurant.isOpen != y.restaurant.isOpen) {
                    return x.restaurant.isOpen ? -1 : 1;
                  }
                  return x.meters.compareTo(y.meters);
                });
                return builder(
                  context,
                  NearbyState(
                    items: list,
                    message: list.isEmpty ? kNoRestaurantsMessage : null,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class RestaurantCard extends StatelessWidget {
  const RestaurantCard({super.key, required this.item});

  final NearbyItem item;

  @override
  Widget build(BuildContext context) {
    final Restaurant r = item.restaurant;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: Colors.white,
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => MenuScreen(restaurant: r),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 140,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  r.imageUrl.isEmpty
                      ? const _ImagePlaceholder()
                      : Image.network(
                          r.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const _ImagePlaceholder(),
                        ),
                  if (!r.isOpen)
                    Container(
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: const Text(
                        'Closed right now',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${r.prepTimeMin} min',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: TwingaColors.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
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
                        const SizedBox(height: 4),
                        Text(
                          '${(item.meters / 1000).toStringAsFixed(1)} km away',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: r.rating > 0 ? TwingaColors.veg : Colors.black38,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          r.rating > 0 ? r.rating.toStringAsFixed(1) : 'New',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (r.rating > 0)
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
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
      child: const Icon(Icons.storefront, size: 44, color: TwingaColors.blue),
    );
  }
}
