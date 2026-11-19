import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/money.dart';
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

const ColorFilter _greyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

class RestaurantCard extends StatelessWidget {
  const RestaurantCard({super.key, required this.item});

  final NearbyItem item;

  Widget _photo(Restaurant r) {
    final Widget placeholder = _ImagePlaceholder(name: r.name);
    final Uint8List? bytes = r.imageBytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stack) => placeholder,
      );
    }
    if (r.imageUrl.isEmpty) {
      return placeholder;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        placeholder,
        Image.network(
          r.imageUrl,
          fit: BoxFit.cover,
          frameBuilder: (context, child, frame, sync) {
            return AnimatedOpacity(
              opacity: frame == null && !sync ? 0 : 1,
              duration: const Duration(milliseconds: 350),
              child: child,
            );
          },
          errorBuilder: (context, error, stack) => placeholder,
        ),
      ],
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: TwingaColors.blue),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: TwingaColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Restaurant r = item.restaurant;
    final Widget photo = _photo(r);
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2A8F).withValues(alpha: 0.09),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
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
                height: 172,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    r.isOpen
                        ? photo
                        : ColorFiltered(colorFilter: _greyscale, child: photo),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.55),
                          ],
                          begin: Alignment.center,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    if (!r.isOpen)
                      Container(
                        color: Colors.black.withValues(alpha: 0.35),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.nightlight_round,
                              color: Colors.white,
                              size: 26,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Closed right now',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: r.isOpen
                                    ? TwingaColors.veg
                                    : Colors.black38,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              r.isOpen ? 'Open' : 'Closed',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: TwingaColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      bottom: 12,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.place_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${(item.meters / 1000).toStringAsFixed(1)} km away',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: TwingaColors.orange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${r.prepTimeMin} min',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.2,
                                  color: TwingaColors.ink,
                                ),
                              ),
                              if (r.cuisines.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    r.cuisines,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: r.rating > 0
                                ? TwingaColors.veg
                                : TwingaColors.orange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                r.rating > 0
                                    ? r.rating.toStringAsFixed(1)
                                    : 'New',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                              if (r.rating > 0)
                                const Padding(
                                  padding: EdgeInsets.only(left: 2),
                                  child: Icon(
                                    Icons.star_rounded,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _pill(Icons.timer_outlined, '${r.prepTimeMin} min prep'),
                        _pill(
                          Icons.delivery_dining_rounded,
                          '${(item.meters / 1000).toStringAsFixed(1)} km',
                        ),
                        if (r.packagingChargePaise > 0)
                          _pill(
                            Icons.shopping_bag_outlined,
                            'Packaging ${rupees(r.packagingChargePaise)}',
                          ),
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
  const _ImagePlaceholder({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final String letter = name.trim().isEmpty ? 'T' : name.trim().substring(0, 1).toUpperCase();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3AA4FF), Color(0xFF0A3FB5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Center(
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft pulsing placeholder shown while restaurants load.
class RestaurantSkeleton extends StatefulWidget {
  const RestaurantSkeleton({super.key});

  @override
  State<RestaurantSkeleton> createState() => _RestaurantSkeletonState();
}

class _RestaurantSkeletonState extends State<RestaurantSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _box(double w, double h, {double r = 8}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFFE3EAF6),
        borderRadius: BorderRadius.circular(r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              child: Container(height: 172, color: const Color(0xFFE3EAF6)),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(180, 18),
                  const SizedBox(height: 10),
                  _box(120, 13),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _box(90, 26, r: 10),
                      const SizedBox(width: 8),
                      _box(70, 26, r: 10),
                    ],
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
