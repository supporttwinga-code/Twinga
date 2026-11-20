import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


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
              gradient: selected ? _Brand.action : null,
              borderRadius: BorderRadius.circular(26),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon,
                  size: 20,
                  color: selected ? Colors.white : _Brand.royal,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : _Brand.royal,
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
        color: _Brand.royal.withValues(alpha: 0.07),
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
          const _TwingaLogo(scale: 0.8),
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
                        color: _Brand.gold,
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
                              color: _Brand.gold,
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
              const _HeroBadge(icon: kHeroIcon, size: 104),
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
        _BrandField(
          controller: _phone,
          hint: 'Mobile Number',
          icon: Icons.smartphone_rounded,
          keyboard: TextInputType.phone,
          formatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          onSubmitted: _sendOtp,
          trailing: _BrandButton(
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
          _BrandField(
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
            child: _BrandButton(
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
        _BrandField(
          controller: _name,
          hint: kNameHint,
          icon: Icons.person_rounded,
          capitalization: TextCapitalization.words,
        ),
      );
      f.add(gap);
    }
    f.add(
      _BrandField(
        controller: _email,
        hint: 'Email Address',
        icon: Icons.email_rounded,
        keyboard: TextInputType.emailAddress,
      ),
    );
    f.add(gap);
    f.add(
      _BrandField(
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
                color: _Brand.blue,
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
              color: _Brand.error,
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
              color: _Brand.ok,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    f.add(
      SizedBox(
        width: double.infinity,
        child: _BrandButton(
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
      backgroundColor: _Brand.navy,
      body: Container(
        decoration: const BoxDecoration(gradient: _Brand.backdrop),
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
                    color: _Brand.mist,
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
                          painter: _SkylinePainter(
                            _Brand.royal.withValues(alpha: 0.16),
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
                                color: _Brand.ink,
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
                                  color: _Brand.royal,
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

// ---- Twinga look (built into this file) ----
/// Twinga brand colours and small reusable widgets.
class _Brand {
  _Brand._();

  static const Color navy = Color(0xFF061A66);
  static const Color royal = Color(0xFF0A3FB5);
  static const Color blue = Color(0xFF0B57E0);
  static const Color sky = Color(0xFF3AA4FF);
  static const Color gold = Color(0xFFFFB400);
  static const Color goldDeep = Color(0xFFF08A00);
  static const Color ink = Color(0xFF14213D);
  static const Color mist = Color(0xFFF3F7FF);
  static const Color error = Color(0xFFD93025);
  static const Color ok = Color(0xFF1E9E4A);

  static const LinearGradient backdrop = LinearGradient(
    colors: <Color>[navy, royal, Color(0xFF1B6FE8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient action = LinearGradient(
    colors: <Color>[royal, blue],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

class _ClochePainter extends CustomPainter {
  const _ClochePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Paint gold = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[Color(0xFFFFD25A), Color(0xFFF08A00)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    final Path dome = Path()
      ..moveTo(0, h * 0.9)
      ..arcTo(Rect.fromLTRB(0, h * 0.2, w, h * 1.6), math.pi, math.pi, false)
      ..close();
    canvas.drawPath(dome, gold);
    canvas.drawCircle(Offset(w / 2, h * 0.12), h * 0.1, gold);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.04, h * 0.93, w * 0.92, h * 0.07),
        const Radius.circular(3),
      ),
      gold,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SpeedLines extends StatelessWidget {
  const _SpeedLines({required this.scale});

  final double scale;

  Widget _bar(double w) {
    return Container(
      width: w * scale,
      height: 3.4 * scale,
      margin: EdgeInsets.symmetric(vertical: 2.2 * scale),
      decoration: BoxDecoration(
        color: _Brand.gold,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[_bar(24), _bar(32), _bar(18)],
    );
  }
}

/// The TWINGA logo drawn in code, so no image file is needed.
class _TwingaLogo extends StatelessWidget {
  const _TwingaLogo({
    super.key,
    this.scale = 1.0,
    this.dark = false,
    this.tagline = true,
  });

  final double scale;
  final bool dark;
  final bool tagline;

  @override
  Widget build(BuildContext context) {
    final Color text = dark ? _Brand.royal : Colors.white;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 62 * scale,
          height: 34 * scale,
          child: const CustomPaint(painter: _ClochePainter()),
        ),
        SizedBox(height: 2 * scale),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            _SpeedLines(scale: scale),
            SizedBox(width: 6 * scale),
            Text(
              'TWINGA',
              style: TextStyle(
                fontSize: 42 * scale,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: -1.2,
                height: 1.0,
                color: text,
              ),
            ),
          ],
        ),
        if (tagline)
          Padding(
            padding: EdgeInsets.only(top: 4 * scale),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Good Food',
                  style: TextStyle(
                    fontSize: 14 * scale,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    color: text,
                  ),
                ),
                Text(
                  '  •  ',
                  style: TextStyle(fontSize: 14 * scale, color: _Brand.gold),
                ),
                Text(
                  'Faster',
                  style: TextStyle(
                    fontSize: 14 * scale,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    color: _Brand.gold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A row of simple city buildings, used at the bottom of screens.
class _SkylinePainter extends CustomPainter {
  const _SkylinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()..color = color;
    double x = 0;
    int i = 0;
    while (x < size.width) {
      final double w = 20.0 + ((i * 7) % 4) * 6;
      final double h = size.height * (0.25 + ((i * 5) % 5) * 0.08);
      final double top = size.height - h;
      final double bw = w - 2;
      canvas.drawRect(Rect.fromLTWH(x, top, bw, h), p);
      if (i % 3 == 0) {
        canvas.drawArc(
          Rect.fromLTWH(x, top - bw * 0.45, bw, bw * 0.9),
          math.pi,
          math.pi,
          true,
          p,
        );
        canvas.drawRect(
          Rect.fromLTWH(x + bw / 2 - 0.8, top - bw * 0.45 - 7, 1.6, 7),
          p,
        );
      } else if (i % 3 == 1) {
        final Path t = Path()
          ..moveTo(x + 2, top)
          ..lineTo(x + bw / 2, top - 12)
          ..lineTo(x + bw - 2, top)
          ..close();
        canvas.drawPath(t, p);
      }
      x += w;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _SkylinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Round white badge with a big icon, used in the login header.
class _HeroBadge extends StatelessWidget {
  const _HeroBadge({super.key, required this.icon, this.size = 104});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Center(
        child: Container(
          width: size * 0.72,
          height: size * 0.72,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: <Color>[Color(0xFFFFD25A), _Brand.goldDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: size * 0.4),
        ),
      ),
    );
  }
}

/// Rounded input box with an icon on the left.
class _BrandField extends StatelessWidget {
  const _BrandField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboard,
    this.obscure = false,
    this.trailing,
    this.formatters,
    this.capitalization = TextCapitalization.none,
    this.onSubmitted,
    this.center = false,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboard;
  final bool obscure;
  final Widget? trailing;
  final List<TextInputFormatter>? formatters;
  final TextCapitalization capitalization;
  final VoidCallback? onSubmitted;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: EdgeInsets.only(left: 16, right: trailing == null ? 16 : 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _Brand.royal.withValues(alpha: 0.14)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _Brand.royal.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: _Brand.royal, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboard,
              obscureText: obscure,
              inputFormatters: formatters,
              textCapitalization: capitalization,
              textAlign: center ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                fontSize: center ? 20 : 16,
                fontWeight: FontWeight.w700,
                letterSpacing: center ? 6 : 0,
                color: _Brand.ink,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Colors.black38,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  fontSize: 16,
                ),
              ),
              onSubmitted: (_) {
                if (onSubmitted != null) {
                  onSubmitted!();
                }
              },
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Blue gradient pill button.
class _BrandButton extends StatelessWidget {
  const _BrandButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.small = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool small;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final double radius = small ? 22 : 30;
    return Opacity(
      opacity: (onPressed == null && !loading) ? 0.55 : 1,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: _Brand.action,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _Brand.royal.withValues(alpha: 0.30),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: loading ? null : onPressed,
            child: Container(
              height: small ? 42 : 56,
              padding: EdgeInsets.symmetric(horizontal: small ? 16 : 0),
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          label,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: small ? 14 : 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (icon != null) ...<Widget>[
                          const SizedBox(width: 8),
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, size: 16, color: _Brand.royal),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
