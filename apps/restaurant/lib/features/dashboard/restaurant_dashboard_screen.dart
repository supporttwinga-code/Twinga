
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RestaurantDashboardScreen extends StatefulWidget {
  const RestaurantDashboardScreen({super.key});

  @override
  State<RestaurantDashboardScreen> createState() =>
      _RestaurantDashboardScreenState();
}

class _RestaurantDashboardScreenState
    extends State<RestaurantDashboardScreen> {
  static const Color navy = Color(0xFF061B55);
  static const Color blue = Color(0xFF075CF5);
  static const Color bg = Color(0xFFF3F6FF);

  int selectedTab = 0;
  bool updatingStatus = false;

  final FirebaseFirestore db = FirebaseFirestore.instance;

  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<QuerySnapshot<Map<String, dynamic>>> get restaurantStream {
    return db
        .collection('restaurants')
        .where('ownerUid', isEqualTo: uid)
        .limit(1)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> ordersStream(
      String restaurantId) {
    return db
        .collection('orders')
        .where('restaurantId', isEqualTo: restaurantId)
        .snapshots();
  }

  Future<void> toggleRestaurant(
      String restaurantId, bool currentStatus) async {
    if (updatingStatus) return;

    setState(() => updatingStatus = true);

    try {
      await db.collection('restaurants').doc(restaurantId).update({
        'isOpen': !currentStatus,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !currentStatus
                ? 'Restaurant is now OPEN'
                : 'Restaurant is now CLOSED',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status update failed: $e')),
      );
    } finally {
      if (mounted) setState(() => updatingStatus = false);
    }
  }

  double restaurantEarnings(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> orders) {
    return orders.fold<double>(0, (sum, order) {
      final data = order.data();
      final status = (data['status'] ?? '').toString().toUpperCase();

      if (status != 'DELIVERED') return sum;

      final value = data['restaurantEarning'];
      if (value is num) return sum + value.toDouble();

      return sum;
    });
  }

  int countDelivered(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> orders) {
    return orders.where((order) {
      return (order.data()['status'] ?? '')
              .toString()
              .toUpperCase() ==
          'DELIVERED';
    }).length;
  }

  int countPending(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> orders) {
    return orders.where((order) {
      final status =
          (order.data()['status'] ?? '').toString().toUpperCase();

      return [
        'PLACED',
        'CONFIRMED',
        'PREPARING',
        'READY_FOR_PICKUP',
      ].contains(status);
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Please login first')),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: restaurantStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('Unable to load restaurant details'),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _emptyRestaurant();
            }

            final restaurantDoc = snapshot.data!.docs.first;
            final restaurant = restaurantDoc.data();
            final restaurantId = restaurantDoc.id;

            final name = restaurant['name']?.toString() ??
                restaurant['restaurantName']?.toString() ??
                'Restaurant';

            final isOpen = restaurant['isOpen'] == true;

            return StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: ordersStream(restaurantId),
              builder: (context, orderSnapshot) {
                if (orderSnapshot.hasError) {
                  return const Center(
                    child: Text('Unable to load orders'),
                  );
                }

                final orders = orderSnapshot.data?.docs ?? [];

                final earnings = restaurantEarnings(orders);
                final delivered = countDelivered(orders);
                final pending = countPending(orders);

                final sortedOrders = [...orders]
                  ..sort((a, b) {
                    final aTime = a.data()['createdAt'];
                    final bTime = b.data()['createdAt'];

                    final aMillis = aTime is Timestamp
                        ? aTime.millisecondsSinceEpoch
                        : 0;
                    final bMillis = bTime is Timestamp
                        ? bTime.millisecondsSinceEpoch
                        : 0;

                    return bMillis.compareTo(aMillis);
                  });

                return Column(
                  children: [
                    _header(name, restaurant, isOpen, restaurantId),
                    Expanded(
                      child: IndexedStack(
                        index: selectedTab,
                        children: [
                          _dashboard(
                            earnings,
                            delivered,
                            pending,
                            sortedOrders,
                            orderSnapshot.connectionState ==
                                ConnectionState.waiting,
                          ),
                          _ordersPage(sortedOrders),
                          _menuPage(restaurantId),
                          _profilePage(name, restaurant),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: _bottomNavigation(),
    );
  }

  Widget _header(String name, Map<String, dynamic> restaurant,
      bool isOpen, String restaurantId) {
    final image = restaurant['imageUrl']?.toString() ??
        restaurant['logoUrl']?.toString() ??
        '';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [navy, Color(0xFF075CF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.menu_rounded,
                  color: Colors.white, size: 28),
              const Spacer(),
              const Text(
                'TWINGA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              const Icon(Icons.notifications_none,
                  color: Colors.white, size: 27),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white,
                backgroundImage:
                    image.isNotEmpty ? NetworkImage(image) : null,
                child: image.isEmpty
                    ? const Icon(Icons.store,
                        color: blue, size: 32)
                    : null,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Restaurant Partner',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: updatingStatus
                    ? null
                    : () => toggleRestaurant(
                        restaurantId, isOpen),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
                child: updatingStatus
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isOpen ? 'OPEN' : 'CLOSED'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dashboard(
    double earnings,
    int delivered,
    int pending,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> orders,
    bool loading,
  ) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Business Overview',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: navy,
          ),
        ),
        const SizedBox(height: 15),

        Row(
          children: [
            Expanded(
              child: _statCard(
                'Delivered',
                '$delivered',
                Icons.shopping_bag_outlined,
                const Color(0xFFE5EEFF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                'Pending',
                '$pending',
                Icons.receipt_long,
                const Color(0xFFFFF0D9),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        _earningsCard(earnings),

        const SizedBox(height: 25),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Live Orders',
              style: TextStyle(
                color: navy,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => selectedTab = 1),
              child: const Text('View All'),
            ),
          ],
        ),

        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (orders.isEmpty)
          _emptyOrders()
        else
          ...orders.take(5).map(_orderCard),

        const SizedBox(height: 20),

        const Text(
          'Quick Actions',
          style: TextStyle(
            color: navy,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _quickAction(
                'Manage Menu',
                Icons.restaurant_menu,
                () => setState(() => selectedTab = 2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _quickAction(
                'Business Profile',
                Icons.storefront,
                () => setState(() => selectedTab = 3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: blue.withOpacity(.07),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color,
            child: Icon(icon, color: blue),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: navy,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(title,
              style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _earningsCard(double earnings) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [navy, Color(0xFF075CF5)],
        ),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet,
                  color: Colors.white),
              SizedBox(width: 9),
              Text(
                'Restaurant Earnings',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '₹${earnings.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'From delivered orders with recorded restaurantEarning',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderCard(
      QueryDocumentSnapshot<Map<String, dynamic>> order) {
    final data = order.data();
    final status = data['status']?.toString() ?? 'UNKNOWN';
    final amount = data['totalAmount'] ?? data['total'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFE9F0FF),
            child: Icon(Icons.receipt_long, color: blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${order.id}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: navy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  status.replaceAll('_', ' '),
                  style: const TextStyle(color: blue),
                ),
              ],
            ),
          ),
          Text(
            amount is num ? '₹${amount.toStringAsFixed(0)}' : '—',
            style: const TextStyle(
              color: navy,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ordersPage(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> orders) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'All Orders',
          style: TextStyle(
            fontSize: 23,
            color: navy,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        if (orders.isEmpty)
          _emptyOrders()
        else
          ...orders.map(_orderCard),
      ],
    );
  }

  Widget _menuPage(String restaurantId) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.restaurant_menu,
                color: blue, size: 55),
            const SizedBox(height: 15),
            const Text(
              'Menu Management',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: navy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connect this section to your existing Menu Item screen. '
              'Your current menu records will remain untouched.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Restaurant ID: $restaurantId',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profilePage(String name, Map<String, dynamic> restaurant) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Restaurant Profile',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
            color: navy,
          ),
        ),
        const SizedBox(height: 20),
        _profileTile('Restaurant Name', name),
        _profileTile(
          'Address',
          restaurant['address']?.toString() ?? 'Not provided',
        ),
        _profileTile(
          'Approval Status',
          restaurant['status']?.toString() ?? 'Not available',
        ),
      ],
    );
  }

  Widget _profileTile(String title, String value) {
    return Card(
      color: Colors.white,
      child: ListTile(
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }

  Widget _quickAction(
      String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(icon, color: blue, size: 32),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: navy,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyOrders() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              color: blue, size: 48),
          SizedBox(height: 12),
          Text(
            'No orders yet',
            style: TextStyle(
              color: navy,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'New real orders will appear here.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _emptyRestaurant() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store_mall_directory_outlined,
                size: 65, color: blue),
            SizedBox(height: 15),
            Text(
              'Restaurant not found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: navy,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please login with the registered restaurant partner account.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomNavigation() {
    const labels = ['Home', 'Orders', 'Menu', 'Profile'];
    const icons = [
      Icons.home_rounded,
      Icons.receipt_long_rounded,
      Icons.restaurant_menu_rounded,
      Icons.person_rounded,
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(23),
        ),
      ),
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Row(
        children: List.generate(4, (index) {
          final selected = selectedTab == index;

          return Expanded(
            child: InkWell(
              onTap: () => setState(() => selectedTab = index),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icons[index],
                    color: selected ? blue : Colors.blueGrey,
                    size: 25,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[index],
                    style: TextStyle(
                      color: selected ? blue : Colors.blueGrey,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
