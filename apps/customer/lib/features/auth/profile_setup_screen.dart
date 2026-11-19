import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Shown once, right after a new customer logs in with a mobile number.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, required this.uid});

  final String uid;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _name = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _name.text.trim();
    if (name.length < 2) {
      setState(() {
        _error = 'Please enter your name.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final String uid = widget.uid;
    final String digits = uid.length == 14 && uid.startsWith('ph91')
        ? uid.substring(4)
        : '';
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        <String, dynamic>{
          'role': 'customer',
          'name': name,
          'phone': digits.isEmpty ? '' : '+91$digits',
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = 'Could not save. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwingaColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Welcome to Twinga',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: TwingaColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tell us your name so the restaurant and the delivery partner know who the order is for.',
                style: TextStyle(color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _save(),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: TwingaColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Continue'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : () => FirebaseAuth.instance.signOut(),
                  child: const Text('Log out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
