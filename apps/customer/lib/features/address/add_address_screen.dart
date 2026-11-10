import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme.dart';

class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final TextEditingController _line = TextEditingController();
  final TextEditingController _landmark = TextEditingController();
  String _label = 'Home';
  double? _lat;
  double? _lng;
  bool _locating = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _line.dispose();
    _landmark.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
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
        throw 'Location permission is needed to find restaurants near you.';
      }
      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e is String ? e : 'Could not get your location. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _locating = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final String line = _line.text.trim();
    if (line.length < 8) {
      setState(() {
        _error = 'Please enter your full address (house/flat, street, area).';
      });
      return;
    }
    if (_lat == null || _lng == null) {
      setState(() {
        _error = 'Please tap "Use my current location" while you are at this address.';
      });
      return;
    }
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final DocumentReference<Map<String, dynamic>> userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final DocumentReference<Map<String, dynamic>> ref =
          await userRef.collection('addresses').add(<String, dynamic>{
        'label': _label,
        'addressLine': line,
        'landmark': _landmark.text.trim(),
        'lat': _lat!,
        'lng': _lng!,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await userRef.update(<String, dynamic>{'defaultAddressId': ref.id});
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not save address (${e.code}). Please try again.';
        _saving = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not save address. Please try again.';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add address')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Save address as',
            style: TextStyle(fontWeight: FontWeight.w700, color: TwingaColors.ink),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final String l in <String>['Home', 'Work', 'Other'])
                ChoiceChip(
                  label: Text(l),
                  selected: _label == l,
                  onSelected: (_) {
                    setState(() {
                      _label = l;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _line,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Full address (house/flat, street, area)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _landmark,
            decoration: const InputDecoration(
              labelText: 'Landmark (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _locating || _saving ? null : _useCurrentLocation,
            icon: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: Text(_lat == null ? 'Use my current location' : 'Update location'),
          ),
          if (_lat != null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Location captured',
                style: TextStyle(
                  color: TwingaColors.veg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: TwingaColors.error)),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving || _locating ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save address'),
          ),
        ],
      ),
    );
  }
}
