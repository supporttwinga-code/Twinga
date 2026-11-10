import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _isSignup = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _friendly(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email is not valid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is wrong.';
      case 'email-already-in-use':
        return 'This email already has an account. Please log in.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Something went wrong (${e.code}).';
    }
  }

  Future<void> _submit() async {
    final String email = _email.text.trim();
    final String password = _password.text;
    final String name = _name.text.trim();
    if (email.isEmpty || password.isEmpty || (_isSignup && name.isEmpty)) {
      setState(() => _error = 'Please fill in all the details.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isSignup) {
        final UserCredential cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
        final User? user = cred.user;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set(<String, dynamic>{
            'role': 'customer',
            'name': name,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Welcome to Twinga',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: TwingaColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isSignup ? 'Create your account' : 'Log in to continue',
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              if (_isSignup) ...[
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: TwingaColors.error),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isSignup ? 'Create account' : 'Log in'),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                            _isSignup = !_isSignup;
                            _error = null;
                          }),
                  child: Text(
                    _isSignup
                        ? 'Already have an account? Log in'
                        : 'New here? Create an account',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
