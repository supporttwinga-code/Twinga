import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../address/address_model.dart';
import '../address/address_screen.dart';
import '../cart/cart.dart';
import '../cart/checkout_screen.dart';
import '../orders/orders_screen.dart';
import '../restaurants/restaurant_list.dart';

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
          _ProfileTab(uid: user.uid),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() {
            _index = i;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
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
  _Cat('Burgers', '🍔', 'burger'),
  _Cat('Pizza', '🍕', 'pizza'),
  _Cat('Indian', '🍛', 'indian'),
  _Cat('Chinese', '🥡', 'chinese'),
  _Cat('South Indian', '🥘', 'south'),
  _Cat('Desserts', '🍰', 'dessert'),
  _Cat('Beverages', '🥤', 'beverage'),
  _Cat('Snacks', '🍟', 'snack'),
  _Cat('Healthy', '🥗', 'health'),
  _Cat('All', '🍽️', ''),
];

class _HomeTab extends StatefulWidget {
  const _HomeTab({required this.uid, required this.onSearch});

  final String uid;
  final VoidCallback onSearch;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  String _category = '';
  final GlobalKey _listKey = GlobalKey();

  void _scrollToList() {
    final BuildContext? ctx = _listKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _header() {
    return Container(
      color: TwingaColors.blue,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
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
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: widget.onSearch,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search, color: Colors.black45),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Search restaurants or cuisine',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
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

  Widget _banner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8A00), Color(0xFFE65100)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delicious food,\ndelivered to your doorstep',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'From restaurants near you',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _scrollToList,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFE65100),
                    minimumSize: const Size(0, 40),
                  ),
                  child: const Text('Order now'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text('🍲', style: TextStyle(fontSize: 64)),
        ],
      ),
    );
  }

  Widget _categories() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      child: GridView.count(
        crossAxisCount: 5,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.72,
        children: [
          for (final _Cat c in _cats)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _category = c.keyword;
                });
              },
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _category == c.keyword
                          ? const Color(0xFFE3EEFF)
                          : Colors.white,
                      border: Border.all(
                        color: _category == c.keyword
                            ? TwingaColors.blue
                            : Colors.black12,
                        width: 2,
                      ),
                    ),
                    child: Text(c.emoji, style: const TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c.label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _centerText(String text) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(child: Text(text, textAlign: TextAlign.center)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NearbyBuilder(
      uid: widget.uid,
      builder: (context, state) {
        List<NearbyItem> items = state.items;
        if (_category.isNotEmpty) {
          items = items
              .where((i) => i.restaurant.cuisines.toLowerCase().contains(_category))
              .toList();
        }
        final List<Widget> list = <Widget>[];
        if (state.loading) {
          list.add(const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ));
        } else if (state.message != null) {
          list.add(_centerText(state.message!));
        } else if (items.isEmpty) {
          list.add(_centerText('No restaurants match this category right now.'));
        } else {
          for (final NearbyItem i in items) {
            list.add(Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RestaurantCard(item: i),
            ));
          }
        }
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _header(),
            _banner(),
            _categories(),
            Padding(
              key: _listKey,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: const Text(
                'Restaurants near you',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: TwingaColors.ink,
                ),
              ),
            ),
            ...list,
            const SizedBox(height: 12),
          ],
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
              const Icon(Icons.location_on, color: Colors.white),
              const SizedBox(width: 6),
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
              const Icon(Icons.arrow_drop_down, color: Colors.white),
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
            label: Text('${cart.itemCount}'),
            child: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
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
          color: TwingaColors.blue,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SafeArea(
            bottom: false,
            child: TextField(
              controller: _controller,
              onChanged: (v) {
                setState(() {
                  _q = v.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search restaurants or cuisine',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: NearbyBuilder(
            uid: widget.uid,
            builder: (context, state) {
              if (state.loading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.message != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(state.message!, textAlign: TextAlign.center),
                  ),
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
                return const Center(child: Text('No matching restaurants.'));
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [for (final NearbyItem i in items) RestaurantCard(item: i)],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final String email = FirebaseAuth.instance.currentUser?.email ?? '';
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final Map<String, dynamic>? data = snapshot.data?.data();
        final String name = (data?['name'] ?? '').toString();
        final String role = (data?['role'] ?? '').toString();
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: TwingaColors.blue,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: Text(
                        name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: TwingaColors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'Hello!' : name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              style: const TextStyle(color: Colors.white70),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (role == 'admin')
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  'You are signed in as admin. The admin panel will be a separate web panel.',
                  style: TextStyle(color: TwingaColors.error),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('My addresses'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const AddressScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log out'),
              onTap: () => FirebaseAuth.instance.signOut(),
            ),
          ],
        );
      },
    );
  }
}
