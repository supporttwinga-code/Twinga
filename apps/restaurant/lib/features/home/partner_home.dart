import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../registration/register_restaurant_screen.dart';

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
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const RegisterRestaurantScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.storefront),
                  label: const Text('Register your restaurant'),
                ),
              ],
            ),
          );
        }
        final Map<String, dynamic> d = snap.data!.docs.first.data();
        final String rname = (d['name'] ?? 'Your restaurant').toString();
        final String status = (d['status'] ?? '').toString();
        String title;
        String body;
        if (status == 'approved') {
          title = '$rname is approved';
          body = 'Your restaurant is approved. Menu management is coming in the next update.';
        } else if (status == 'rejected') {
          title = '$rname was not approved';
          body = 'Please contact Twinga support.';
        } else {
          title = '$rname is under review';
          body = 'We will approve it after checking your details.';
        }
        final String address = (d['addressLine'] ?? '').toString();
        final int radius = _intOf(d['deliveryRadiusKm']);
        final int packagingRupees = _intOf(d['packagingChargePaise']) ~/ 100;
        final int prep = _intOf(d['prepTimeMin']);
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _hello(ownerName),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: TwingaColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(body),
            const SizedBox(height: 20),
            Card(
              color: Colors.white,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rname,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: TwingaColors.ink,
                      ),
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(address),
                    ],
                    const SizedBox(height: 10),
                    Text('Delivery radius: $radius km'),
                    Text('Packaging charge: ₹$packagingRupees per order'),
                    Text('Preparation time: $prep min'),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
