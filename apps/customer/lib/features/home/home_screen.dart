import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../restaurants/restaurant_list.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Twinga'),
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
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Greeting(uid: user.uid),
                const Expanded(child: RestaurantList()),
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
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final Map<String, dynamic>? data = snapshot.data?.data();
        final String name = (data?['name'] ?? '').toString();
        final String role = (data?['role'] ?? '').toString();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Hello!' : 'Hello, $name',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: TwingaColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text('What would you like to eat today?'),
              if (role == 'admin')
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'You are signed in as admin. The admin panel will be a separate web panel.',
                    style: TextStyle(color: TwingaColors.error),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
