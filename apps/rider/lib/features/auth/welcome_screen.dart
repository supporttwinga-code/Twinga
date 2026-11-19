import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/brand.dart';

// ---- Settings of this app ----
const String kRole = 'rider';
const String kApp = 'rider';
const String kPanelLabel = 'TWINGA RIDER';
const String kHeadLine1 = 'Deliver Smiles,';
const String kHeadLine2 = 'Earn More!';
const IconData kHeroIcon = Icons.delivery_dining_rounded;
const List<String> kPoints = <String>['Earn on every delivery', 'Be your own boss', 'Withdraw your earnings'];
const String kLoginTitle = 'Delivery Partner';
const String kLoginSub = 'Login to continue';
const String kSignupTitle = 'Join as a Rider';
const String kSignupSub = 'Create your delivery partner account';
const String kNameHint = 'Your Full Name';
const String kFooter = 'Ride. Deliver. Earn.';

/// Mobile number + OTP login (needs the twinga-auth Worker).
const bool kPhone = true;
const String kAuthApi = 'https://twinga-auth.support-twinga.workers.dev';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _otp = TextEditingController();
  bool _signup = false;
  bool _loading = false;
  bool _hidePass = true;
  bool _otpSent = false;
  String? _error;
  String? _info;
  String _challenge = '';
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _otp.dispose();
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

  void _setMode(bool signup) {
    setState(() {
      _signup = signup;
      _error = null;
      _info = null;
    });
  }

  Future<void> _submit() async {
    final String email = _email.text.trim();
    final String password = _password.text;
    final String name = _name.text.trim();
    if (email.isEmpty || password.isEmpty || (_signup && name.isEmpty)) {
      setState(() {
        _error = 'Please fill in all the details.';
        _info = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      if (_signup) {
        final UserCredential cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
        final User? user = cred.user;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set(<String, dynamic>{
            'role': kRole,
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
      if (mounted) {
        setState(() => _error = _friendly(e));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Something went wrong: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _forgot() async {
    final String email = _email.text.trim();
    if (email.isEmpty) {
      setState(() {
        _error = 'Type your email above first, then tap Forgot Password.';
        _info = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        setState(() => _info = 'Password reset link sent to $email.');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _error = _friendly(e));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ---- Mobile number + OTP ----

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final HttpClientRequest req =
          await client.postUrl(Uri.parse('$kAuthApi$path'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
      final HttpClientResponse res =
          await req.close().timeout(const Duration(seconds: 25));
      final String text = await res.transform(utf8.decoder).join();
      final dynamic j = jsonDecode(text);
      if (j is Map<String, dynamic>) {
        return j;
      }
      return <String, dynamic>{'ok': false, 'error': 'Unexpected reply.'};
    } catch (e) {
      return <String, dynamic>{
        'ok': false,
        'error': 'Could not reach the server. Check your internet.',
      };
    } finally {
      client.close();
    }
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_cooldown <= 1) {
        t.cancel();
      }
      setState(() => _cooldown = _cooldown > 0 ? _cooldown - 1 : 0);
    });
  }

  Future<void> _sendOtp() async {
    final String mobile = _phone.text.trim();
    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(mobile)) {
      setState(() {
        _error = 'Enter a valid 10 digit mobile number.';
        _info = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    final Map<String, dynamic> j =
        await _post('/otp/send', <String, dynamic>{'mobile': mobile, 'app': kApp});
    if (!mounted) {
      return;
    }
    if (j['ok'] == true && j['challenge'] is String) {
      _challenge = j['challenge'] as String;
      _otp.clear();
      setState(() {
        _otpSent = true;
        _loading = false;
        _info = 'OTP sent to +91 $mobile.';
      });
      _startCooldown();
    } else {
      setState(() {
        _loading = false;
        _error = (j['error'] ?? 'Could not send OTP.').toString();
      });
    }
  }

  Future<void> _verifyOtp() async {
    final String otp = _otp.text.trim();
    if (otp.length != 6) {
      setState(() {
        _error = 'Enter the 6 digit OTP.';
        _info = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    final Map<String, dynamic> j = await _post('/otp/verify', <String, dynamic>{
      'mobile': _phone.text.trim(),
      'app': kApp,
      'otp': otp,
      'challenge': _challenge,
    });
    if (!mounted) {
      return;
    }
    if (j['ok'] == true && j['token'] is String) {
      try {
        await FirebaseAuth.instance.signInWithCustomToken(j['token'] as String);
        return;
      } on FirebaseAuthException catch (e) {
        if (!mounted) {
          return;
        }
        setState(() {
          _loading = false;
          _error = 'Sign in failed (${e.code}). Please try again.';
        });
        return;
      }
    }
    setState(() {
      _loading = false;
      _error = (j['error'] ?? 'Could not verify the OTP.').toString();
    });
  }

  // ---- UI pieces ----

  Widget _tabs() {
    Widget seg(String label, IconData icon, bool selected, bool toSignup) {
      return Expanded(
        child: GestureDetector(
          onTap: _loading ? null : () => _setMode(toSignup),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 48,
            decoration: BoxDecoration(
              gradient: selected ? Brand.action : null,
              borderRadius: BorderRadius.circular(26),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon,
                  size: 20,
                  color: selected ? Colors.white : Brand.royal,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : Brand.royal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Brand.royal.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: <Widget>[
          seg('Login', Icons.login_rounded, !_signup, false),
          seg('Sign Up', Icons.person_add_alt_1_rounded, _signup, true),
        ],
      ),
    );
  }

  Widget _or() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: <Widget>[
          Expanded(child: Divider(color: Color(0x330A3FB5))),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'OR',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(child: Divider(color: Color(0x330A3FB5))),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
      child: Column(
        children: <Widget>[
          const TwingaLogo(scale: 0.8),
          if (kPanelLabel.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Text(
                kPanelLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      kHeadLine1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    Text(
                      kHeadLine2,
                      style: const TextStyle(
                        color: Brand.gold,
                        fontSize: 28,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final String p in kPoints)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Brand.gold,
                              size: 17,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                p,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const HeroBadge(icon: kHeroIcon, size: 104),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _formChildren() {
    const SizedBox gap = SizedBox(height: 12);
    final List<Widget> f = <Widget>[];
    if (kPhone) {
      f.add(
        BrandField(
          controller: _phone,
          hint: 'Mobile Number',
          icon: Icons.smartphone_rounded,
          keyboard: TextInputType.phone,
          formatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          onSubmitted: _sendOtp,
          trailing: BrandButton(
            label: _cooldown > 0
                ? '${_cooldown}s'
                : (_otpSent ? 'Resend' : 'Send OTP'),
            small: true,
            onPressed: (_loading || _cooldown > 0) ? null : _sendOtp,
          ),
        ),
      );
      if (_otpSent) {
        f.add(gap);
        f.add(
          BrandField(
            controller: _otp,
            hint: '------',
            icon: Icons.sms_rounded,
            keyboard: TextInputType.number,
            center: true,
            formatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onSubmitted: _verifyOtp,
          ),
        );
        f.add(gap);
        f.add(
          SizedBox(
            width: double.infinity,
            child: BrandButton(
              label: 'Verify & Continue',
              icon: Icons.arrow_forward_rounded,
              onPressed: _loading ? null : _verifyOtp,
            ),
          ),
        );
      }
      f.add(_or());
    }
    if (_signup) {
      f.add(
        BrandField(
          controller: _name,
          hint: kNameHint,
          icon: Icons.person_rounded,
          capitalization: TextCapitalization.words,
        ),
      );
      f.add(gap);
    }
    f.add(
      BrandField(
        controller: _email,
        hint: 'Email Address',
        icon: Icons.email_rounded,
        keyboard: TextInputType.emailAddress,
      ),
    );
    f.add(gap);
    f.add(
      BrandField(
        controller: _password,
        hint: 'Password',
        icon: Icons.lock_rounded,
        obscure: _hidePass,
        onSubmitted: _submit,
        trailing: IconButton(
          onPressed: () => setState(() => _hidePass = !_hidePass),
          icon: Icon(
            _hidePass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: Colors.black45,
          ),
        ),
      ),
    );
    if (!_signup) {
      f.add(
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _loading ? null : _forgot,
            child: const Text(
              'Forgot Password?',
              style: TextStyle(
                color: Brand.blue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    } else {
      f.add(const SizedBox(height: 14));
    }
    if (_error != null) {
      f.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            _error!,
            style: const TextStyle(
              color: Brand.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    if (_info != null) {
      f.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            _info!,
            style: const TextStyle(
              color: Brand.ok,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    f.add(
      SizedBox(
        width: double.infinity,
        child: BrandButton(
          label: _signup ? 'Create Account' : 'Login',
          icon: Icons.arrow_forward_rounded,
          loading: _loading,
          onPressed: _loading ? null : _submit,
        ),
      ),
    );
    return f;
  }

  @override
  Widget build(BuildContext context) {
    final double h = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Brand.navy,
      body: Container(
        decoration: const BoxDecoration(gradient: Brand.backdrop),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              children: <Widget>[
                _header(),
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(minHeight: h * 0.6),
                  decoration: const BoxDecoration(
                    color: Brand.mist,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(34)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: <Widget>[
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 64,
                        child: CustomPaint(
                          painter: SkylinePainter(
                            Brand.royal.withValues(alpha: 0.16),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 84),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _signup ? kSignupTitle : kLoginTitle,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Brand.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _signup ? kSignupSub : kLoginSub,
                              style: const TextStyle(
                                fontSize: 14.5,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _tabs(),
                            const SizedBox(height: 16),
                            ..._formChildren(),
                            const SizedBox(height: 16),
                            Center(
                              child: Text(
                                kFooter,
                                style: const TextStyle(
                                  color: Brand.royal,
                                  fontWeight: FontWeight.w800,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
