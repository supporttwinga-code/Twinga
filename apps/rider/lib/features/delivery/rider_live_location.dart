import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Has no screen of its own. While this rider has an order that is accepted,
/// being prepared, ready or on the way, it sends the rider's position to that
/// order so the customer can watch the rider move on the map.
/// It only works while the Twinga Rider app is open on the phone.
class RiderLiveLocation extends StatefulWidget {
  const RiderLiveLocation({super.key, required this.uid});

  final String uid;

  @override
  State<RiderLiveLocation> createState() => _RiderLiveLocationState();
}

class _RiderLiveLocationState extends State<RiderLiveLocation> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ordersSub;
  StreamSubscription<Position>? _posSub;
  List<DocumentReference<Map<String, dynamic>>> _active =
      <DocumentReference<Map<String, dynamic>>>[];
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _ordersSub = FirebaseFirestore.instance
        .collection('orders')
        .where('riderUid', isEqualTo: widget.uid)
        .where('status', whereIn: <String>[
          'accepted',
          'preparing',
          'ready',
          'picked',
        ])
        .snapshots()
        .listen(_onOrders, onError: (Object e) {});
  }

  void _onOrders(QuerySnapshot<Map<String, dynamic>> snap) {
    _active = snap.docs
        .map((d) => d.reference)
        .toList();
    if (_active.isEmpty) {
      _stop();
    } else {
      _start();
    }
  }

  Future<void> _start() async {
    if (_posSub != null || _starting) {
      return;
    }
    _starting = true;
    try {
      final bool enabled = await Geolocator.isLocationServiceEnabled();
      final LocationPermission perm = await Geolocator.checkPermission();
      if (!enabled ||
          perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      if (!mounted || _active.isEmpty || _posSub != null) {
        return;
      }
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 20,
        ),
      ).listen(_send, onError: (Object e) {});
    } catch (e) {
      // Location is optional for the customer's map, so ignore errors here.
    } finally {
      _starting = false;
    }
  }

  void _stop() {
    _posSub?.cancel();
    _posSub = null;
  }

  Future<void> _send(Position p) async {
    final DateTime now = DateTime.now();
    if (now.difference(_lastSent).inSeconds < 12) {
      return;
    }
    _lastSent = now;
    for (final DocumentReference<Map<String, dynamic>> ref
        in List<DocumentReference<Map<String, dynamic>>>.of(_active)) {
      try {
        await ref.update(<String, dynamic>{
          'riderLat': p.latitude,
          'riderLng': p.longitude,
          'riderLocAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // The order may have just finished. Nothing to do.
      }
    }
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    _posSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
