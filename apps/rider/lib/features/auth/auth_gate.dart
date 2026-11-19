import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../home/rider_home.dart';
import 'welcome_screen.dart';
import '../../core/push.dart';
import 'profile_setup_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final User? user = snapshot.data;
        if (user == null) {
          return const WelcomeScreen();
        }
        final String? email = user.email;
        if (email != null && email.isNotEmpty) {
          return const PushStarter(topic: 'all_riders', child: RiderHome());
        }
        return _PhoneUser(uid: user.uid);
      },
    );
  }
}

/// A user who logged in with a mobile number. If they have no profile yet,
/// ask for their name first.
class _PhoneUser extends StatefulWidget {
  const _PhoneUser({required this.uid});

  final String uid;

  @override
  State<_PhoneUser> createState() => _PhoneUserState();
}

class _PhoneUserState extends State<_PhoneUser> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _stream =
      FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Could not load your account:\n${snap.error}'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: const Text('Log out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data!.exists) {
          return const PushStarter(topic: 'all_riders', child: RiderHome());
        }
        return ProfileSetupScreen(
          uid: widget.uid,
          role: 'rider',
          nameHint: 'Your Full Name',
          intro: 'Tell us your full name. You will complete your rider details next.',
        );
      },
    );
  }
}
