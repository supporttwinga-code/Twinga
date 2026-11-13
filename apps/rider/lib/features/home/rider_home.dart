import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../delivery/delivery_area.dart';
import '../registration/register_rider_screen.dart';

Widget _message(String text) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

Widget _hello(String name) {
  return Text(
    name.isEmpty ? 'Hello!' : 'Hello, $name',
    style: const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      color: TwingaColors.ink,
    ),
  );
}

class RiderHome extends StatelessWidget {
  const RiderHome({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Twinga Rider'),
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
                if (role != 'rider') {
                  return _message(
                    'This account is not a delivery partner account. '
                    'Please log out and sign up here with a different email.',
                  );
                }
                final String name = (data['name'] ?? '').toString();
                return _RiderStatus(uid: user.uid, name: name);
              },
            ),
    );
  }
}

class _RiderStatus extends StatelessWidget {
  const _RiderStatus({required this.uid, required this.name});

  final String uid;
  final String name;

  @override
  Widget build(BuildContext context) {
    final DocumentReference<Map<String, dynamic>> ref =
        FirebaseFirestore.instance.collection('riders').doc(uid);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _message('Could not load your details:\n${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final DocumentSnapshot<Map<String, dynamic>> doc = snap.data!;
        if (!doc.exists) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _hello(name),
                const SizedBox(height: 20),
                const Text(
                  'Complete your registration',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: TwingaColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Add your phone number and vehicle details. Twinga will approve you after checking them.',
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => RegisterRiderScreen(name: name),
                      ),
                    );
                  },
                  icon: const Icon(Icons.two_wheeler),
                  label: const Text('Register as delivery partner'),
                ),
              ],
            ),
          );
        }
        final Map<String, dynamic> d = doc.data() ?? <String, dynamic>{};
        final String status = (d['status'] ?? '').toString();
        final bool isOnline = d['isOnline'] is bool ? d['isOnline'] as bool : false;
        final String vehicle = (d['vehicleType'] ?? '').toString();
        final String number = (d['vehicleNumber'] ?? '').toString();
        final String phone = (d['phone'] ?? '').toString();
        String title;
        String body;
        if (status == 'approved') {
          title = 'You are approved';
          body = 'Switch to Online when you are ready to take deliveries.';
        } else if (status == 'rejected') {
          title = 'Your registration was not approved';
          body = 'Please contact Twinga support.';
        } else {
          title = 'Your registration is under review';
          body = 'We will approve it after checking your details.';
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _hello(name),
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
                    Text('Phone: $phone'),
                    if (vehicle.isNotEmpty) Text('Vehicle: $vehicle'),
                    if (number.isNotEmpty) Text('Vehicle number: $number'),
                  ],
                ),
              ),
            ),
            if (status == 'approved') ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SwitchListTile(
                  title: Text(
                    isOnline ? 'You are Online' : 'You are Offline',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('You get delivery requests only when you are online.'),
                  value: isOnline,
                  onChanged: (bool v) {
                    ref.update(<String, dynamic>{'isOnline': v});
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (isOnline)
                DeliveryArea(uid: uid, riderName: name, riderPhone: phone)
              else
                const Text('Go online to see delivery requests.'),
            ],
          ],
        );
      },
    );
  }
}
