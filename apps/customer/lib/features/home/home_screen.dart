import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../account/account_screen.dart';
import '../address/address_model.dart';
import '../address/address_screen.dart';
import '../cart/cart.dart';
import '../cart/checkout_screen.dart';
import '../orders/orders_screen.dart';
import '../restaurants/restaurant_list.dart';
import 'banner_carousel.dart';

const String kSupportEmail = 'support.twinga@gmail.com';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          _HomeTab(
            uid: user.uid,
            onSearch: () {
              setState(() {
                _index = 1;
              });
            },
          ),
          _SearchTab(uid: user.uid),
          const OrdersScreen(),
          const AccountScreen(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_index <= 1) const _CartBar(),
            Theme(
              data: Theme.of(context).copyWith(
                navigationBarTheme: NavigationBarThemeData(
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  indicatorColor: const Color(0xFFE3EEFF),
                  height: 66,
                  labelTextStyle: WidgetStateProperty.resolveWith((states) {
                    final bool on = states.contains(WidgetState.selected);
                    return TextStyle(
                      fontSize: 12,
                      fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                      color: on ? TwingaColors.blue : Colors.black54,
                    );
                  }),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (i) {
                  setState(() {
                    _index = i;
                  });
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded, color: TwingaColors.blue),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.search_rounded),
                    selectedIcon: Icon(Icons.search_rounded, color: TwingaColors.blue),
                    label: 'Search',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long_rounded, color: TwingaColors.blue),
                    label: 'Orders',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded, color: TwingaColors.blue),
                    label: 'Profile',
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

/// Floating "View cart" bar, only visible when the cart has items.
class _CartBar extends StatelessWidget {
  const _CartBar();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: cart,
      builder: (context, child) {
        if (cart.isEmpty) {
          return const SizedBox.shrink();
        }
        final String from = cart.restaurant?.name ?? '';
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const CheckoutScreen(),
                  ),
                );
              },
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB347), Color(0xFFFF8A00)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8A00).withValues(alpha: 0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shopping_bag_rounded, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'}  ·  ${rupees(cart.foodPaise)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          if (from.isNotEmpty)
                            Text(
                              'from $from',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Text(
                      'View cart',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Builds [b] with the customer's selected delivery address (or null).
Widget _withAddress(
  String uid,
  Widget Function(BuildContext context, SavedAddress? address) b,
) {
  final DocumentReference<Map<String, dynamic>> userRef =
      FirebaseFirestore.instance.collection('users').doc(uid);
  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: userRef.snapshots(),
    builder: (context, userSnap) {
      final dynamic raw = userSnap.data?.data()?['defaultAddressId'];
      if (raw is! String || raw.isEmpty) {
        return b(context, null);
      }
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userRef.collection('addresses').doc(raw).snapshots(),
        builder: (context, addrSnap) {
          final DocumentSnapshot<Map<String, dynamic>>? doc = addrSnap.data;
          final SavedAddress? a =
              (doc == null || !doc.exists) ? null : SavedAddress.fromDoc(doc);
          return b(context, a);
        },
      );
    },
  );
}

class _Cat {
  const _Cat(this.label, this.emoji, this.keyword);

  final String label;
  final String emoji;
  final String keyword;
}

const List<_Cat> _cats = <_Cat>[
  _Cat('All', '🍽️', ''),
  _Cat('Burgers', '🍔', 'burger'),
  _Cat('Pizza', '🍕', 'pizza'),
  _Cat('Indian', '🍛', 'indian'),
  _Cat('Chinese', '🥡', 'chinese'),
  _Cat('South Indian', '🥘', 'south'),
  _Cat('Desserts', '🍰', 'dessert'),
  _Cat('Beverages', '🥤', 'beverage'),
  _Cat('Snacks', '🍟', 'snack'),
  _Cat('Healthy', '🥗', 'health'),
];

const Map<String, String> _sorts = <String, String>{
  'near': 'Nearest first',
  'rating': 'Top rated',
  'fast': 'Fastest preparation',
};

class _HomeTab extends StatefulWidget {
  const _HomeTab({required this.uid, required this.onSearch});

  final String uid;
  final VoidCallback onSearch;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  String _category = '';
  bool _openOnly = false;
  bool _topRated = false;
  bool _fast = false;
  String _sort = 'near';
  final GlobalKey _listKey = GlobalKey();

  void _scrollToList() {
    final BuildContext? ctx = _listKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _pickSort() async {
    final String? v = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Sort restaurants',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              for (final MapEntry<String, String> e in _sorts.entries)
                ListTile(
                  title: Text(
                    e.value,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: _sort == e.key
                      ? const Icon(Icons.check_circle_rounded, color: TwingaColors.blue)
                      : const Icon(Icons.circle_outlined, color: Colors.black26),
                  onTap: () => Navigator.of(sheetContext).pop(e.key),
                ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
    if (v != null && mounted) {
      setState(() {
        _sort = v;
      });
    }
  }

  Widget _header() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A3FB5), Color(0xFF0077F7), Color(0xFF3AA4FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 20),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _LocationLine(uid: widget.uid)),
                const _CartButton(),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _Greeting(uid: widget.uid),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: widget.onSearch,
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search_rounded, color: TwingaColors.orange),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Search restaurants or cuisine',
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(Icons.tune_rounded, color: Colors.black38, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categories() {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        itemCount: _cats.length,
        separatorBuilder: (context, i) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final _Cat c = _cats[i];
          final bool on = _category == c.keyword;
          return GestureDetector(
            onTap: () {
              setState(() {
                _category = c.keyword;
              });
            },
            child: SizedBox(
              width: 64,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 58,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: on
                          ? const LinearGradient(
                              colors: [Color(0xFF3AA4FF), Color(0xFF0077F7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: on ? null : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: (on ? TwingaColors.blue : Colors.black)
                              .withValues(alpha: on ? 0.35 : 0.08),
                          blurRadius: on ? 14 : 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(c.emoji, style: const TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    c.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: on ? FontWeight.w900 : FontWeight.w600,
                      color: on ? TwingaColors.blue : TwingaColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _filters() {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterChip(
            icon: Icons.swap_vert_rounded,
            label: _sorts[_sort] ?? 'Sort',
            selected: _sort != 'near',
            onTap: _pickSort,
          ),
          _FilterChip(
            icon: Icons.storefront_rounded,
            label: 'Open now',
            selected: _openOnly,
            onTap: () => setState(() => _openOnly = !_openOnly),
          ),
          _FilterChip(
            icon: Icons.star_rounded,
            label: 'Rating 4.0+',
            selected: _topRated,
            onTap: () => setState(() => _topRated = !_topRated),
          ),
          _FilterChip(
            icon: Icons.bolt_rounded,
            label: 'Under 25 min',
            selected: _fast,
            onTap: () => setState(() => _fast = !_fast),
          ),
        ],
      ),
    );
  }

  List<NearbyItem> _apply(List<NearbyItem> all) {
    List<NearbyItem> items = all;
    if (_category.isNotEmpty) {
      items = items
          .where((i) => i.restaurant.cuisines.toLowerCase().contains(_category))
          .toList();
    }
    if (_openOnly) {
      items = items.where((i) => i.restaurant.isOpen).toList();
    }
    if (_topRated) {
      items = items.where((i) => i.restaurant.rating >= 4.0).toList();
    }
    if (_fast) {
      items = items.where((i) => i.restaurant.prepTimeMin <= 25).toList();
    }
    items = List<NearbyItem>.of(items);
    if (_sort == 'rating') {
      items.sort((a, b) {
        if (a.restaurant.isOpen != b.restaurant.isOpen) {
          return a.restaurant.isOpen ? -1 : 1;
        }
        return b.restaurant.rating.compareTo(a.restaurant.rating);
      });
    } else if (_sort == 'fast') {
      items.sort((a, b) {
        if (a.restaurant.isOpen != b.restaurant.isOpen) {
          return a.restaurant.isOpen ? -1 : 1;
        }
        return a.restaurant.prepTimeMin.compareTo(b.restaurant.prepTimeMin);
      });
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return NearbyBuilder(
      uid: widget.uid,
      builder: (context, state) {
        final List<NearbyItem> items = _apply(state.items);
        final List<Widget> list = <Widget>[];
        if (state.loading) {
          list.addAll(const [
            RestaurantSkeleton(),
            RestaurantSkeleton(),
          ]);
        } else if (state.message != null) {
          list.add(_StateMessage(
            icon: state.message == kNoAddressMessage
                ? Icons.location_off_rounded
                : Icons.storefront_rounded,
            text: state.message!,
            actionLabel: state.message == kNoAddressMessage ? 'Add address' : null,
            onAction: state.message == kNoAddressMessage
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const AddressScreen(),
                      ),
                    );
                  }
                : null,
          ));
        } else if (items.isEmpty) {
          list.add(const _StateMessage(
            icon: Icons.filter_alt_off_rounded,
            text: 'No restaurants match these filters right now.',
          ));
        } else {
          for (final NearbyItem i in items) {
            list.add(RestaurantCard(item: i));
          }
        }
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _header(),
            BannerCarousel(onTap: _scrollToList),
            _categories(),
            const SizedBox(height: 12),
            _filters(),
            Padding(
              key: _listKey,
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Restaurants near you',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: TwingaColors.ink,
                      ),
                    ),
                  ),
                  if (!state.loading && state.message == null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3EEFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${items.length}',
                        style: const TextStyle(
                          color: TwingaColors.blue,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: list),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? TwingaColors.blue : Colors.white,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(
              color: selected ? TwingaColors.blue : const Color(0xFFD9E4F6),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: TwingaColors.blue.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : TwingaColors.blue,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: selected ? Colors.white : TwingaColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3EAF6)),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE3EEFF),
            ),
            child: Icon(icon, size: 36, color: TwingaColors.blue),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: TwingaColors.ink,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: TwingaColors.blue,
                minimumSize: const Size(0, 46),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final String full = (snap.data?.data()?['name'] ?? '').toString().trim();
        final String first = full.isEmpty ? '' : full.split(' ').first;
        return Text(
          first.isEmpty ? 'What are you craving today?' : 'Hi $first, what are you craving?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            height: 1.15,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        );
      },
    );
  }
}

class _LocationLine extends StatelessWidget {
  const _LocationLine({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return _withAddress(uid, (context, a) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => const AddressScreen(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Deliver to',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      a == null ? 'Add delivery address' : '${a.label} · ${a.addressLine}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
            ],
          ),
        ),
      );
    });
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: cart,
      builder: (context, child) {
        return IconButton(
          tooltip: 'Cart',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const CheckoutScreen(),
              ),
            );
          },
          icon: Badge(
            isLabelVisible: cart.itemCount > 0,
            backgroundColor: TwingaColors.orange,
            label: Text('${cart.itemCount}'),
            child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 26),
          ),
        );
      },
    );
  }
}

class _SearchTab extends StatefulWidget {
  const _SearchTab({required this.uid});

  final String uid;

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  final TextEditingController _controller = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A3FB5), Color(0xFF0077F7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12, top: 4),
                  child: Text(
                    'Search',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextField(
                  controller: _controller,
                  onChanged: (v) {
                    setState(() {
                      _q = v.trim().toLowerCase();
                    });
                  },
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Search restaurants or cuisine',
                    prefixIcon: const Icon(Icons.search_rounded, color: TwingaColors.orange),
                    suffixIcon: _q.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _controller.clear();
                              setState(() {
                                _q = '';
                              });
                            },
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: NearbyBuilder(
            uid: widget.uid,
            builder: (context, state) {
              if (state.loading) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [RestaurantSkeleton(), RestaurantSkeleton()],
                );
              }
              if (state.message != null) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _StateMessage(icon: Icons.storefront_rounded, text: state.message!),
                  ],
                );
              }
              final List<NearbyItem> items = state.items.where((i) {
                if (_q.isEmpty) {
                  return true;
                }
                return i.restaurant.name.toLowerCase().contains(_q) ||
                    i.restaurant.cuisines.toLowerCase().contains(_q);
              }).toList();
              if (items.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [
                    _StateMessage(
                      icon: Icons.search_off_rounded,
                      text: 'No matching restaurants.',
                    ),
                  ],
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                children: [for (final NearbyItem i in items) RestaurantCard(item: i)],
              );
            },
          ),
        ),
      ],
    );
  }
}

