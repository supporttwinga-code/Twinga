import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../delivery/delivery_area.dart';
import '../earnings/rider_earnings_screen.dart';
import '../registration/register_rider_screen.dart';
import '../support/support_screen.dart';

const Color _deep = Color(0xFF0A3FB5);
const Color _line = Color(0xFFE3EAF7);

BoxDecoration _cardBox() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: _line),
    boxShadow: const [
      BoxShadow(color: Color(0x140A2A8F), blurRadius: 18, offset: Offset(0, 8)),
    ],
  );
}

Widget _message(String text) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + index * 130),
      curve: Curves.easeOutCubic,
      builder: (context, v, w) {
        return Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, (1 - v) * 22), child: w),
        );
      },
      child: child,
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.on});

  final bool on;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.on ? const Color(0xFF3DDC84) : Colors.white54;
    return SizedBox(
      width: 26,
      height: 26,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.on)
                Container(
                  width: 10 + 16 * _c.value,
                  height: 10 + 16 * _c.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withAlpha((90 * (1 - _c.value)).round()),
                  ),
                ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            ],
          );
        },
      ),
    );
  }
}

class RiderHome extends StatelessWidget {
  const RiderHome({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: TwingaColors.background,
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
                  return SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _message(
                          'This account is not a delivery partner account. '
                          'Please log out and sign up here with a different email.',
                        ),
                        OutlinedButton(
                          onPressed: () => FirebaseAuth.instance.signOut(),
                          child: const Text('Log out'),
                        ),
                      ],
                    ),
                  );
                }
                final String name = (data['name'] ?? '').toString();
                return _RiderStatus(uid: user.uid, name: name);
              },
            ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(38),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withAlpha(60)),
            ),
            child: Icon(icon, color: Colors.white, size: 21),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.caption, this.child});

  final String name;
  final String caption;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final String initial = name.trim().isEmpty ? 'R' : name.trim()[0].toUpperCase();
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 14,
        20,
        22,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_deep, TwingaColors.blue, Color(0xFF3AA4FF)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Color(0x330A3FB5), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFC15E), TwingaColors.orange],
                  ),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Hello!' : 'Hi, $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      caption,
                      style: TextStyle(color: Colors.white.withAlpha(210)),
                    ),
                  ],
                ),
              ),
              _GlassButton(
                icon: Icons.support_agent,
                tooltip: 'Support',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const SupportScreen()),
                  );
                },
              ),
              _GlassButton(
                icon: Icons.logout,
                tooltip: 'Log out',
                onTap: () => FirebaseAuth.instance.signOut(),
              ),
            ],
          ),
          if (child != null) ...[const SizedBox(height: 18), child!],
        ],
      ),
    );
  }
}

class _OnlineCard extends StatelessWidget {
  const _OnlineCard({required this.online, required this.onChanged});

  final bool online;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(online ? 52 : 34),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(online ? 110 : 60)),
      ),
      child: Row(
        children: [
          _PulseDot(on: online),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  online ? 'You are Online' : 'You are Offline',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  online
                      ? 'Receiving delivery requests'
                      : 'Go online to get delivery requests',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withAlpha(215),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: online,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF28C76F),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white30,
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: TwingaColors.ink,
              ),
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: _cardBox(),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: TwingaColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: TwingaColors.blue),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.black54)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: TwingaColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiderStatus extends StatelessWidget {
  const _RiderStatus({required this.uid, required this.name});

  final String uid;
  final String name;

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Widget _statusCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
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
          Text(body),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => _push(context, const SupportScreen()),
            icon: const Icon(Icons.support_agent),
            label: const Text('Contact support'),
          ),
        ],
      ),
    );
  }

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
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(name: name, caption: 'Welcome to Twinga Rider'),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: _cardBox(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.two_wheeler, size: 38, color: TwingaColors.blue),
                      const SizedBox(height: 10),
                      const Text(
                        'Complete your registration',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: TwingaColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Add your phone number and vehicle details. Twinga will approve you after checking them.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () =>
                            _push(context, RegisterRiderScreen(name: name)),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Register as delivery partner'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        final Map<String, dynamic> d = doc.data() ?? <String, dynamic>{};
        final String status = (d['status'] ?? '').toString();
        final bool online = d['isOnline'] is bool ? d['isOnline'] as bool : false;
        final String vehicle = (d['vehicleType'] ?? '').toString();
        final String number = (d['vehicleNumber'] ?? '').toString();
        final String phone = (d['phone'] ?? '').toString();
        final String city = (d['city'] ?? '').toString();

        if (status != 'approved') {
          final bool rejected = status == 'rejected';
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(
                name: name,
                caption: rejected ? 'Registration not approved' : 'Under review',
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _statusCard(
                      context,
                      icon: rejected ? Icons.error_outline : Icons.hourglass_top,
                      color: rejected ? TwingaColors.error : TwingaColors.orange,
                      title: rejected
                          ? 'Your registration was not approved'
                          : 'Your registration is under review',
                      body: rejected
                          ? 'Please contact Twinga support to know the reason.'
                          : 'We will approve it after checking your details. This screen updates by itself.',
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _cardBox(),
                      child: Column(
                        children: [
                          _InfoRow(Icons.phone_outlined, 'Phone', phone),
                          if (vehicle.isNotEmpty)
                            _InfoRow(Icons.two_wheeler, 'Vehicle', vehicle),
                          if (number.isNotEmpty)
                            _InfoRow(Icons.pin_outlined, 'Number', number),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('riderUid', isEqualTo: uid)
              .snapshots(),
          builder: (context, os) {
            final RiderStats stats = RiderStats.from(
              os.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[],
            );
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                _Header(
                  name: name,
                  caption: city.isEmpty ? 'Delivery partner' : 'Delivery partner · $city',
                  child: _OnlineCard(
                    online: online,
                    onChanged: (bool v) {
                      ref.update(<String, dynamic>{'isOnline': v});
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Reveal(
                        index: 0,
                        child: Row(
                          children: [
                            Expanded(
                              child: _StatTile(
                                icon: Icons.currency_rupee,
                                color: TwingaColors.veg,
                                value: rupeesText(stats.todayPaise),
                                label: 'Earned today',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatTile(
                                icon: Icons.two_wheeler,
                                color: TwingaColors.blue,
                                value: '${stats.todayTrips}',
                                label: 'Trips today',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatTile(
                                icon: Icons.emoji_events_outlined,
                                color: TwingaColors.orange,
                                value: '${stats.deliveredCount}',
                                label: 'Total trips',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _Reveal(
                        index: 1,
                        child: Row(
                          children: [
                            Expanded(
                              child: _ActionTile(
                                icon: Icons.account_balance_wallet_outlined,
                                label: 'Earnings',
                                colors: const [Color(0xFF28C76F), Color(0xFF1E9E4A)],
                                onTap: () =>
                                    _push(context, RiderEarningsScreen(uid: uid)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ActionTile(
                                icon: Icons.history,
                                label: 'History',
                                colors: const [Color(0xFF3AA4FF), TwingaColors.blue],
                                onTap: () =>
                                    _push(context, DeliveryHistoryScreen(uid: uid)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ActionTile(
                                icon: Icons.support_agent,
                                label: 'Support',
                                colors: const [Color(0xFFFFC15E), TwingaColors.orange],
                                onTap: () => _push(context, const SupportScreen()),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _Reveal(
                        index: 2,
                        child: online
                            ? DeliveryArea(
                                uid: uid,
                                riderName: name,
                                riderPhone: phone,
                              )
                            : Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: _cardBox(),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.nights_stay_outlined,
                                      size: 42,
                                      color: TwingaColors.blue,
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'You are offline',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: TwingaColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Turn on Online to see delivery requests near you. Finish any active delivery before going offline.',
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 14),
                                    FilledButton.icon(
                                      onPressed: () {
                                        ref.update(<String, dynamic>{'isOnline': true});
                                      },
                                      icon: const Icon(Icons.power_settings_new),
                                      label: const Text(
                                        'Go online',
                                        style: TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: TwingaColors.veg,
                                        minimumSize: const Size.fromHeight(50),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 20),
                      _Reveal(
                        index: 3,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: _cardBox(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your details',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: TwingaColors.ink,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _InfoRow(Icons.phone_outlined, 'Phone', phone),
                              if (vehicle.isNotEmpty)
                                _InfoRow(Icons.two_wheeler, 'Vehicle', vehicle),
                              if (number.isNotEmpty)
                                _InfoRow(Icons.pin_outlined, 'Number', number),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
