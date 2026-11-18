import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme.dart';
import '../cart/pricing.dart';

double? _num(dynamic v) => v is num ? v.toDouble() : null;

/// Live map for an order that has a rider. Shows the rider moving, the
/// restaurant and the customer's address, and how far the rider is.
class LiveTrackCard extends StatefulWidget {
  const LiveTrackCard({super.key, required this.orderId, required this.order});

  final String orderId;
  final Map<String, dynamic> order;

  @override
  State<LiveTrackCard> createState() => _LiveTrackCardState();
}

class _LiveTrackCardState extends State<LiveTrackCard> {
  final MapController _map = MapController();
  bool _ready = false;
  LatLng? _lastRider;
  LatLng? _drop;
  LatLng? _shop;

  LatLng? _rider() {
    final double? la = _num(widget.order['riderLat']);
    final double? ln = _num(widget.order['riderLng']);
    if (la == null || ln == null) {
      return null;
    }
    return LatLng(la, ln);
  }

  @override
  void initState() {
    super.initState();
    _lastRider = _rider();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    final FirebaseFirestore db = FirebaseFirestore.instance;
    try {
      final DocumentSnapshot<Map<String, dynamic>> s = await db
          .collection('orders')
          .doc(widget.orderId)
          .collection('secrets')
          .doc('drop')
          .get();
      final double? la = _num(s.data()?['lat']);
      final double? ln = _num(s.data()?['lng']);
      if (la != null && ln != null) {
        _drop = LatLng(la, ln);
      }
    } catch (e) {
      // The map still works without the address pin.
    }
    try {
      final String id = (widget.order['restaurantId'] ?? '').toString();
      if (id.isNotEmpty) {
        final DocumentSnapshot<Map<String, dynamic>> s =
            await db.collection('restaurants').doc(id).get();
        final double? la = _num(s.data()?['lat']);
        final double? ln = _num(s.data()?['lng']);
        if (la != null && ln != null) {
          _shop = LatLng(la, ln);
        }
      }
    } catch (e) {
      // The map still works without the restaurant pin.
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(LiveTrackCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final LatLng? p = _rider();
    final LatLng? prev = _lastRider;
    if (p == null || !_ready) {
      return;
    }
    if (prev != null &&
        prev.latitude == p.latitude &&
        prev.longitude == p.longitude) {
      return;
    }
    _lastRider = p;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      try {
        _map.move(p, _map.camera.zoom);
      } catch (e) {
        // The map is not ready yet. The next update will move it.
      }
    });
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  String _ago(dynamic t) {
    if (t is! Timestamp) {
      return '';
    }
    final int s = DateTime.now().difference(t.toDate()).inSeconds;
    if (s < 45) {
      return 'just now';
    }
    final int m = (s / 60).round();
    return m <= 1 ? '1 min ago' : '$m min ago';
  }

  Widget _marker(IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LatLng? rider = _rider();
    if (rider == null) {
      return const SizedBox.shrink();
    }
    final String status = (widget.order['status'] ?? '').toString();
    final bool picked = status == 'picked';
    final LatLng? target = picked ? _drop : _shop;
    String line = picked ? 'Your order is on the way' : 'Rider is heading to the restaurant';
    if (target != null) {
      final int m = distanceMeters(
        rider.latitude,
        rider.longitude,
        target.latitude,
        target.longitude,
      );
      int mins = (m / 1000 / 20 * 60).ceil();
      if (mins < 1) {
        mins = 1;
      }
      final String km = (m / 1000).toStringAsFixed(1);
      line = picked
          ? 'Rider is about $km km away, around $mins min'
          : 'Rider is about $km km from the restaurant';
    }
    final String ago = _ago(widget.order['riderLocAt']);
    final List<Marker> markers = <Marker>[
      if (_shop != null)
        Marker(
          point: _shop!,
          width: 34,
          height: 34,
          child: _marker(Icons.storefront_rounded, TwingaColors.blue),
        ),
      if (_drop != null)
        Marker(
          point: _drop!,
          width: 34,
          height: 34,
          child: _marker(Icons.home_rounded, TwingaColors.veg),
        ),
      Marker(
        point: rider,
        width: 40,
        height: 40,
        child: _marker(Icons.two_wheeler_rounded, TwingaColors.orange),
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3EAF7)),
        boxShadow: const [
          BoxShadow(color: Color(0x140A2A8F), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.my_location_rounded, color: TwingaColors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Live tracking',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: TwingaColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: rider,
                      initialZoom: 15,
                      onMapReady: () {
                        _ready = true;
                      },
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.twinga.customer',
                      ),
                      MarkerLayer(markers: markers),
                    ],
                  ),
                  Positioned(
                    right: 6,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      color: Colors.white.withAlpha(200),
                      child: const Text(
                        '© OpenStreetMap contributors',
                        style: TextStyle(fontSize: 9, color: Colors.black87),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            line,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: TwingaColors.ink,
            ),
          ),
          if (ago.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Rider location updated $ago',
                style: const TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }
}
