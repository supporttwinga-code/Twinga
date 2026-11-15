import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../earnings/earnings_screen.dart';
import '../menu/menu_manager_screen.dart';
import '../orders/restaurant_orders_screen.dart';
import '../registration/register_restaurant_screen.dart';
import '../store/store_profile_screen.dart';
import '../support/support_screen.dart';
import '../withdraw/withdraw_screen.dart';

Widget _message(String text) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

int _intOf(dynamic v) {
  if (v is num) {
    return v.round();
  }
  return 0;
}

String _statusLabel(String s) {
  switch (s) {
    case 'placed':
      return 'New order';
    case 'accepted':
      return 'Accepted';
    case 'preparing':
      return 'Preparing';
    case 'ready':
      return 'Ready for pickup';
    default:
      return s;
  }
}

Widget _hello(String ownerName) {
  return Text(
    ownerName.isEmpty ? 'Hello!' : 'Hello, $ownerName',
    style: const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      color: TwingaColors.ink,
    ),
  );
}

void _open(BuildContext context, Widget screen) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => screen));
}

class PartnerHome extends StatelessWidget {
  const PartnerHome({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Twinga Partner'),
        actions: [
          IconButton(
            tooltip: 'Support',
            icon: const Icon(Icons.support_agent),
            onPressed: () => _open(context, const SupportScreen()),
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: user == null
          ? const SizedBox.shrink()
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _message('Could not load your account:\n${snap.error}');
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final Map<String, dynamic>? data = snap.data!.data();
                if (data == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final String role = (data['role'] ?? '').toString();
                if (role != 'restaurant') {
                  return _message(
                    'This account is not a restaurant partner account. '
                    'Please log out and sign up here with a different email.',
                  );
                }
                final String name = (data['name'] ?? '').toString();
                return _RestaurantStatus(uid: user.uid, ownerName: name);
              },
            ),
    );
  }
}

class _RestaurantStatus extends StatelessWidget {
  const _RestaurantStatus({required this.uid, required this.ownerName});

  final String uid;
  final String ownerName;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('restaurants')
          .where('ownerUid', isEqualTo: uid)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _message('Could not load your restaurant:\n${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _hello(ownerName),
                const SizedBox(height: 20),
                const Text(
                  'Your restaurant is not registered yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: TwingaColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Register your restaurant to start receiving orders on Twinga.',
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () =>
                      _open(context, const RegisterRestaurantScreen()),
                  icon: const Icon(Icons.storefront),
                  label: const Text('Register your restaurant'),
                ),
              ],
            ),
          );
        }
        final QueryDocumentSnapshot<Map<String, dynamic>> doc =
            snap.data!.docs.first;
        final Map<String, dynamic> d = doc.data();
        final String rname = (d['name'] ?? 'Your restaurant').toString();
        final String status = (d['status'] ?? '').toString();
        if (status == 'approved') {
          return _ApprovedHome(
            uid: uid,
            ownerName: ownerName,
            restaurantId: doc.id,
            rname: rname,
            d: d,
          );
        }
        final bool rejected = status == 'rejected';
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _hello(ownerName),
            const SizedBox(height: 20),
            Text(
              rejected ? '$rname was not approved' : '$rname is under review',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: TwingaColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              rejected
                  ? 'Please contact Twinga support.'
                  : 'We will approve it after checking your details.',
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _open(context, const SupportScreen()),
              icon: const Icon(Icons.support_agent),
              label: const Text('Contact support'),
            ),
          ],
        );
      },
    );
  }
}

class _ApprovedHome extends StatelessWidget {
  const _ApprovedHome({
    required this.uid,
    required this.ownerName,
    required this.restaurantId,
    required this.rname,
    required this.d,
  });

  final String uid;
  final String ownerName;
  final String restaurantId;
  final String rname;
  final Map<String, dynamic> d;

  Widget _stat(IconData icon, String label, String value) {
    return Expanded(
      child: Card(
        color: Colors.white,
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: TwingaColors.blue),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: TwingaColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    int badge = 0,
  }) {
    return Card(
      color: Colors.white,
      elevation: 1,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Badge(
                isLabelVisible: badge > 0,
                label: Text('$badge'),
                child: Icon(icon, color: TwingaColors.blue, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: TwingaColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String address = (d['addressLine'] ?? '').toString();
    final int radius = _intOf(d['deliveryRadiusKm']);
    final int packagingRupees = _intOf(d['packagingChargePaise']) ~/ 100;
    final int prep = _intOf(d['prepTimeMin']);
    final bool isOpen = d['isOpen'] is bool ? d['isOpen'] as bool : false;
    final double rating = d['rating'] is num ? (d['rating'] as num).toDouble() : 0;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('restaurantOwnerUid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        final PartnerStats s = PartnerStats.from(
          snap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[],
        );
        final QueryDocumentSnapshot<Map<String, dynamic>>? live = s.latestActive;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0A2A8F), TwingaColors.blue],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ownerName.isEmpty ? 'Welcome back' : 'Hello, $ownerName',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          rname,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Icon(Icons.verified, color: Colors.white, size: 22),
                    ],
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.only(left: 14, right: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: isOpen
                              ? const Color(0xFF4CE07F)
                              : const Color(0xFFFF8A80),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isOpen ? 'Open for orders' : 'Closed right now',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Switch(
                          value: isOpen,
                          onChanged: (bool v) {
                            FirebaseFirestore.instance
                                .collection('restaurants')
                                .doc(restaurantId)
                                .update(<String, dynamic>{'isOpen': v});
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _stat(Icons.shopping_bag_outlined, 'Orders today', '${s.todayOrders}'),
                _stat(Icons.currency_rupee, 'Earned today', rupeesText(s.todayPaise)),
                _stat(
                  Icons.star_rounded,
                  'Rating',
                  rating > 0 ? rating.toStringAsFixed(1) : 'New',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.white,
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bolt, color: TwingaColors.orange),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s.activeCount > 0
                                ? 'Live orders  ·  ${s.activeCount}'
                                : 'Live orders',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: TwingaColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (live == null)
                      const Text('No live orders right now.')
                    else
                      Builder(
                        builder: (context) {
                          final Map<String, dynamic> m = live.data();
                          final String id = live.id;
                          final String shortId = id.length > 5
                              ? id.substring(id.length - 5).toUpperCase()
                              : id.toUpperCase();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order #$shortId  ·  ${_statusLabel((m['status'] ?? '').toString())}',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text('${(m['customerName'] ?? '').toString()}'),
                            ],
                          );
                        },
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => _open(
                          context,
                          RestaurantOrdersScreen(uid: uid),
                        ),
                        child: Text(
                          s.newCount > 0
                              ? 'View orders  ·  ${s.newCount} new'
                              : 'View orders',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.6,
              children: [
                _action(
                  context,
                  Icons.receipt_long,
                  'Orders',
                  () => _open(context, RestaurantOrdersScreen(uid: uid)),
                  badge: s.newCount,
                ),
                _action(
                  context,
                  Icons.restaurant_menu,
                  'Manage menu',
                  () => _open(
                    context,
                    MenuManagerScreen(
                      restaurantId: restaurantId,
                      restaurantName: rname,
                    ),
                  ),
                ),
                _action(
                  context,
                  Icons.add_photo_alternate_outlined,
                  'Store photos',
                  () => _open(
                    context,
                    StoreProfileScreen(restaurantId: restaurantId),
                  ),
                ),
                _action(
                  context,
                  Icons.account_balance_wallet_outlined,
                  'Earnings',
                  () => _open(context, EarningsScreen(uid: uid)),
                ),
                _action(
                  context,
                  Icons.savings_outlined,
                  'Withdraw',
                  () => _open(context, WithdrawScreen(uid: uid, role: 'restaurant')),
                ),
                _action(
                  context,
                  Icons.account_balance_outlined,
                  'Payout account',
                  () => _open(context, PayoutDetailsScreen(uid: uid, role: 'restaurant')),
                ),
                _action(
                  context,
                  Icons.support_agent,
                  'Support',
                  () => _open(context, const SupportScreen()),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.white,
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Earnings, last 7 days',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: TwingaColors.ink,
                            ),
                          ),
                        ),
                        Text(
                          rupeesText(s.weekPaise),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: TwingaColors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    WeekBars(values: s.perDay, labels: weekLabels()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.white,
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delivery radius: $radius km'),
                    Text('Packaging charge: ₹$packagingRupees per order'),
                    Text('Preparation time: $prep min'),
                    Text('Delivered orders so far: ${s.deliveredCount}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}
