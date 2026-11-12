import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

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

  @override
  Widget build(BuildContext context) {
    final Position? pos = _pos;
    final Map<String, dynamic>? cfg = _config;
    if (_configLoaded && (cfg == null || cfg['dispatchRadiusKm'] is! num)) {
      return const Text('Delivery settings are not available right now.');
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
          Card(
            color: Colors.white,
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (d['restaurantName'] ?? '').toString(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: TwingaColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pickup ${(toRestaurant / 1000).toStringAsFixed(1)} km from you  ·  Drop ${(_intOf(d['distanceMeters']) / 1000).toStringAsFixed(1)} km',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You earn ${_rupees(_intOf(d['riderPayPaise']))}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: TwingaColors.veg,
                    ),
                  ),
                  Text('Collect ${_rupees(_intOf(d['totalPaise']))} cash from the customer'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _accepting == null ? () => _accept(doc.id) : null,
                      child: _accepting == doc.id
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Accept delivery'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivery requests near you',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: TwingaColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        if (_locError != null)
          Text(_locError!, style: const TextStyle(color: TwingaColors.error))
        else if (pos == null)
          const Text('Finding your location...'),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: TwingaColors.error)),
        const SizedBox(height: 8),
        if (pos != null && cards.isEmpty)
          const Text('No delivery requests near you right now. Stay online.'),
        ...cards,
        const SizedBox(height: 8),
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
    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Active delivery',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: TwingaColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            _card([
              const Text('Pickup', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(
                (d['restaurantName'] ?? '').toString(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
                      if (phone.isNotEmpty) Text('Phone: $phone'),
                    ],
                  );
                },
              ),
            ]),
            _card([
              const Text('Drop', style: TextStyle(fontWeight: FontWeight.w700)),
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
                            fontSize: 16,
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
                Text(
                  status == 'accepted'
                      ? 'The restaurant accepted the order. Go to the restaurant.'
                      : 'The food is being prepared. Go to the restaurant.',
                ),
                const SizedBox(height: 4),
                const Text('You can pick it up once it is marked ready.'),
              ]),
            if (status == 'ready')
              _card([
                const Text('The food is ready for pickup.'),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _pickedUp,
                    child: const Text('Picked up from restaurant'),
                  ),
                ),
              ]),
            if (status == 'picked')
              _card([
                Text(
                  'Collect ${_rupees(total)} in cash',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: TwingaColors.veg,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: 'Customer OTP (4 digits)',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _deliver,
                    child: const Text('Confirm delivery'),
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
