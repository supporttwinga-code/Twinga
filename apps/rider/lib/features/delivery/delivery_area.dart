import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/geo.dart';
import '../../core/theme.dart';

const List<String> _openStatuses = <String>['accepted', 'preparing', 'ready'];
const List<String> _activeStatuses = <String>[
  'accepted',
  'preparing',
  'ready',
  'picked',
];

String _rupees(int paise) {
  final int whole = paise ~/ 100;
  final int rem = paise % 100;
  if (rem == 0) {
    return '₹$whole';
  }
  return '₹$whole.${rem.toString().padLeft(2, '0')}';
}

int _intOf(dynamic v) {
  if (v is num) {
    return v.round();
  }
  return 0;
}

double _doubleOf(dynamic v) {
  if (v is num) {
    return v.toDouble();
  }
  return 0;
}

/// Shown on the rider home when the rider is online. Shows the rider's
/// active delivery if there is one, otherwise the orders waiting for a rider.
class DeliveryArea extends StatelessWidget {
  const DeliveryArea({
    super.key,
    required this.uid,
    required this.riderName,
    required this.riderPhone,
  });

  final String uid;
  final String riderName;
  final String riderPhone;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('riderUid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text('Could not load your deliveries:\n${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> active = snap
            .data!.docs
            .where((d) => _activeStatuses.contains((d.data()['status'] ?? '').toString()))
            .toList();
        if (active.isNotEmpty) {
          return _ActiveDelivery(key: ValueKey<String>(active.first.id), orderId: active.first.id);
        }
        return _AvailableOrders(
          uid: uid,
          riderName: riderName,
          riderPhone: riderPhone,
        );
      },
    );
  }
}

class _AvailableOrders extends StatefulWidget {
  const _AvailableOrders({
    required this.uid,
    required this.riderName,
    required this.riderPhone,
  });

  final String uid;
  final String riderName;
  final String riderPhone;

  @override
  State<_AvailableOrders> createState() => _AvailableOrdersState();
}

class _AvailableOrdersState extends State<_AvailableOrders> {
  final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> _byStatus =
      <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
  final Map<String, Map<String, dynamic>> _restaurants =
      <String, Map<String, dynamic>>{};
  final List<StreamSubscription<dynamic>> _subs = <StreamSubscription<dynamic>>[];
  Timer? _timer;
  Position? _pos;
  String? _locError;
  Map<String, dynamic>? _config;
  bool _configLoaded = false;
  String? _accepting;
  String? _error;

  @override
  void initState() {
    super.initState();
    final FirebaseFirestore db = FirebaseFirestore.instance;
    for (final String s in _openStatuses) {
      _subs.add(
        db
            .collection('orders')
            .where('riderUid', isNull: true)
            .where('status', isEqualTo: s)
            .snapshots()
            .listen((snap) {
          if (!mounted) {
            return;
          }
          setState(() {
            _byStatus[s] = snap.docs;
          });
          for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs) {
            _loadRestaurant((d.data()['restaurantId'] ?? '').toString());
          }
        }, onError: (Object e) {
          if (!mounted) {
            return;
          }
          setState(() {
            _error = 'Could not load orders: $e';
          });
        }),
      );
    }
    _subs.add(
      db.collection('config').doc('pricing').snapshots().listen((snap) {
        if (!mounted) {
          return;
        }
        setState(() {
          _config = snap.data();
          _configLoaded = true;
        });
      }, onError: (Object e) {
        if (!mounted) {
          return;
        }
        setState(() {
          _configLoaded = true;
        });
      }),
    );
    _locate();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      _locate();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final StreamSubscription<dynamic> s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _loadRestaurant(String id) async {
    if (id.isEmpty || _restaurants.containsKey(id)) {
      return;
    }
    _restaurants[id] = <String, dynamic>{};
    try {
      final DocumentSnapshot<Map<String, dynamic>> s = await FirebaseFirestore
          .instance
          .collection('restaurants')
          .doc(id)
          .get();
      _restaurants[id] = s.data() ?? <String, dynamic>{};
    } catch (_) {
      _restaurants.remove(id);
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _locate() async {
    try {
      final bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        throw 'Please turn on location (GPS) on your phone.';
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw 'Location permission is needed. Open phone Settings > Apps > Twinga Rider > Permissions > Location and allow it.';
      }
      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _pos = pos;
        _locError = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _locError = e is String
            ? e
            : 'Could not get your location. Check GPS and permission.';
      });
    }
  }

  Future<void> _accept(String orderId) async {
    setState(() {
      _accepting = orderId;
      _error = null;
    });
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update(
        <String, dynamic>{
          'riderUid': widget.uid,
          'riderName': widget.riderName,
          'riderPhone': widget.riderPhone,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not accept this order. Someone else may have taken it.';
        });
      }
    }
    if (mounted) {
      setState(() {
        _accepting = null;
      });
    }
  }

  Widget _info(IconData icon, String text, {Color color = TwingaColors.blue}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _requestCard({
    required String orderId,
    required String restaurant,
    required int toRestaurant,
    required int dropMeters,
    required int earnPaise,
    required int collectPaise,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3EAF7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140A2A8F),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFE3EEFF),
                child: Icon(Icons.storefront, color: TwingaColors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  restaurant,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: TwingaColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5FC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pickup', style: TextStyle(fontSize: 11)),
                      Text(
                        '${(toRestaurant / 1000).toStringAsFixed(1)} km away',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5FC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Drop', style: TextStyle(fontSize: 11)),
                      Text(
                        '${(dropMeters / 1000).toStringAsFixed(1)} km trip',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6EC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('You earn', style: TextStyle(fontSize: 12)),
                      Text(
                        _rupees(earnPaise),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: TwingaColors.veg,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Collect cash', style: TextStyle(fontSize: 12)),
                    Text(
                      _rupees(collectPaise),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: TwingaColors.ink,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _accepting == null ? () => _accept(orderId) : null,
              icon: _accepting == orderId
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: const Text(
                'Accept delivery',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: TwingaColors.veg,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Position? pos = _pos;
    final Map<String, dynamic>? cfg = _config;
    if (_configLoaded && (cfg == null || cfg['dispatchRadiusKm'] is! num)) {
      return _info(
        Icons.settings_suggest_outlined,
        'Delivery settings are not available right now.',
        color: TwingaColors.error,
      );
    }
    final List<Widget> cards = <Widget>[];
    if (pos != null && cfg != null) {
      final double radiusKm = _doubleOf(cfg['dispatchRadiusKm']);
      final double expandedKm = _doubleOf(cfg['dispatchExpandedRadiusKm']);
      final int expandAfterSec = _intOf(cfg['dispatchExpandAfterSec']);
      final DateTime now = DateTime.now();
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> all =
          <QueryDocumentSnapshot<Map<String, dynamic>>>[
        for (final String s in _openStatuses) ...?_byStatus[s],
      ];
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in all) {
        final Map<String, dynamic> d = doc.data();
        final Map<String, dynamic>? r =
            _restaurants[(d['restaurantId'] ?? '').toString()];
        if (r == null || r['lat'] is! num || r['lng'] is! num) {
          continue;
        }
        final int toRestaurant = distanceMeters(
          pos.latitude,
          pos.longitude,
          _doubleOf(r['lat']),
          _doubleOf(r['lng']),
        );
        final dynamic t = d['acceptedAt'] ?? d['createdAt'];
        final int ageSec = t is Timestamp
            ? now.difference(t.toDate()).inSeconds
            : 0;
        final double limitKm = ageSec >= expandAfterSec ? expandedKm : radiusKm;
        if (toRestaurant > limitKm * 1000) {
          continue;
        }
        cards.add(
          _requestCard(
            orderId: doc.id,
            restaurant: (d['restaurantName'] ?? '').toString(),
            toRestaurant: toRestaurant,
            dropMeters: _intOf(d['distanceMeters']),
            earnPaise: _intOf(d['riderPayPaise']),
            collectPaise: _intOf(d['totalPaise']),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Delivery requests near you',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: TwingaColors.ink,
                ),
              ),
            ),
            if (cards.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: TwingaColors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${cards.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_locError != null)
          _info(Icons.location_off, _locError!, color: TwingaColors.error)
        else if (pos == null)
          _info(Icons.my_location, 'Finding your location...'),
        if (_error != null)
          _info(Icons.error_outline, _error!, color: TwingaColors.error),
        if (pos != null && cards.isEmpty)
          _info(
            Icons.two_wheeler,
            'No delivery requests near you right now. Stay online, new requests appear here by themselves.',
          ),
        ...cards,
        const SizedBox(height: 4),
        const Text(
          'Keep this app open while you are online to receive requests.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class _ActiveDelivery extends StatefulWidget {
  const _ActiveDelivery({super.key, required this.orderId});

  final String orderId;

  @override
  State<_ActiveDelivery> createState() => _ActiveDeliveryState();
}

class _ActiveDeliveryState extends State<_ActiveDelivery> {
  late final DocumentReference<Map<String, dynamic>> _ref;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _orderStream;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _dropStream;
  final TextEditingController _otp = TextEditingController();
  Future<DocumentSnapshot<Map<String, dynamic>>>? _restFuture;
  String _restFutureId = '';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ref = FirebaseFirestore.instance.collection('orders').doc(widget.orderId);
    _orderStream = _ref.snapshots();
    _dropStream = _ref.collection('secrets').doc('drop').snapshots();
  }

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  Future<void> _call(String phone) async {
    bool ok = false;
    try {
      ok = await launchUrl(Uri(scheme: 'tel', path: phone));
    } catch (_) {}
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the dialer. Number: $phone')),
      );
    }
  }

  Future<void> _pickedUp() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _ref.update(<String, dynamic>{
        'status': 'picked',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _error = 'Could not update. Is the food marked ready by the restaurant?';
    }
    if (mounted) {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _deliver() async {
    final String code = _otp.text.trim();
    if (code.length != 4) {
      setState(() {
        _error = 'Enter the 4 digit OTP from the customer.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _ref.update(<String, dynamic>{
        'status': 'delivered',
        'otpEntered': code,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _error = 'Wrong OTP or no internet. Ask the customer again.';
    }
    if (mounted) {
      setState(() {
        _busy = false;
      });
    }
  }

  Widget _card(List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3EAF7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140A2A8F),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _progress(String status) {
    final int idx = status == 'picked' ? 2 : (status == 'ready' ? 1 : 0);
    const List<String> labels = <String>[
      'Accepted',
      'Ready',
      'Picked up',
      'Delivered',
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < 4; i++) ...[
          if (i > 0)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  height: 3,
                  color: i <= idx ? TwingaColors.blue : const Color(0xFFD5E3FA),
                ),
              ),
            ),
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= idx ? TwingaColors.blue : const Color(0xFFD5E3FA),
                ),
                child: i <= idx
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(labels[i], style: const TextStyle(fontSize: 10)),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _orderStream,
      builder: (context, snap) {
        final Map<String, dynamic>? d = snap.data?.data();
        if (d == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final String status = (d['status'] ?? '').toString();
        final String rid = (d['restaurantId'] ?? '').toString();
        if (_restFutureId != rid) {
          _restFutureId = rid;
          _restFuture = FirebaseFirestore.instance
              .collection('restaurants')
              .doc(rid)
              .get();
        }
        final int total = _intOf(d['totalPaise']);
        final int earn = _intOf(d['riderPayPaise']);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Active delivery',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: TwingaColors.ink,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F6EC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'You earn ${_rupees(earn)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: TwingaColors.veg,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _card([_progress(status)]),
            _card([
              const Row(
                children: [
                  Icon(Icons.storefront, color: TwingaColors.blue, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'PICKUP',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                (d['restaurantName'] ?? '').toString(),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: _restFuture,
                builder: (context, rs) {
                  final Map<String, dynamic>? r = rs.data?.data();
                  if (r == null) {
                    return const SizedBox.shrink();
                  }
                  final String addr = (r['addressLine'] ?? '').toString();
                  final String phone = (r['phone'] ?? '').toString();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (addr.isNotEmpty) Text(addr),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _call(phone),
                            icon: const Icon(Icons.call),
                            label: Text('Call restaurant  ·  $phone'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ]),
            _card([
              const Row(
                children: [
                  Icon(Icons.home_outlined, color: TwingaColors.veg, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'DROP',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _dropStream,
                builder: (context, ds) {
                  final Map<String, dynamic>? x = ds.data?.data();
                  if (x == null) {
                    return const Text('Loading address...');
                  }
                  final String name = (x['customerName'] ?? '').toString();
                  final String line = (x['addressLine'] ?? '').toString();
                  final String landmark = (x['landmark'] ?? '').toString();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (name.isNotEmpty)
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      Text(line),
                      if (landmark.isNotEmpty) Text('Landmark: $landmark'),
                    ],
                  );
                },
              ),
            ]),
            if (status == 'accepted' || status == 'preparing')
              _card([
                Row(
                  children: [
                    const Icon(Icons.soup_kitchen_outlined, color: TwingaColors.blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        status == 'accepted'
                            ? 'The restaurant accepted the order. Go to the restaurant.'
                            : 'The food is being prepared. Go to the restaurant.',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('You can pick it up once it is marked ready.'),
              ]),
            if (status == 'ready')
              _card([
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: TwingaColors.veg),
                    SizedBox(width: 10),
                    Text(
                      'The food is ready for pickup.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _pickedUp,
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text(
                      'Picked up from restaurant',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ]),
            if (status == 'picked')
              _card([
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      const Text('Collect cash from the customer'),
                      Text(
                        _rupees(total),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: TwingaColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 10,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Customer OTP (4 digits)',
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _deliver,
                    icon: const Icon(Icons.verified),
                    label: const Text(
                      'Confirm delivery',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: TwingaColors.veg,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ]),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: TwingaColors.error)),
          ],
        );
      },
    );
  }
}
