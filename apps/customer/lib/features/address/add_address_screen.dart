import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme.dart';

class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final TextEditingController _house = TextEditingController();
  final TextEditingController _area = TextEditingController();
  final TextEditingController _landmark = TextEditingController();
  final TextEditingController _pincode = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _district = TextEditingController();
  final TextEditingController _state = TextEditingController();

  String _label = 'Home';
  double? _lat;
  double? _lng;
  double? _accuracy;
  bool _locating = false;
  bool _saving = false;
  String? _error;
  String? _note;
  String _gpsSig = '';

  @override
  void dispose() {
    _house.dispose();
    _area.dispose();
    _landmark.dispose();
    _pincode.dispose();
    _city.dispose();
    _district.dispose();
    _state.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _error = null;
      _note = null;
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
        throw 'Location permission is needed. Open phone Settings > Apps > Twinga > Permissions > Location and allow it.';
      }
      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _accuracy = pos.accuracy;
      });
      await _fillFromPlacemark(pos.latitude, pos.longitude);
    } catch (e) {
      if (!mounted) {
        return;
      }
      final String text = e.toString();
      setState(() {
        if (e is String) {
          _error = e;
        } else if (text.contains('TimeoutException')) {
          _error = 'GPS signal not found in time. Go near a window or outside and try again.';
        } else {
          _error = 'Could not get your location: $text';
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _locating = false;
        });
      }
    }
  }

  Future<void> _fillFromPlacemark(double lat, double lng) async {
    try {
      final List<Placemark> list = await placemarkFromCoordinates(lat, lng);
      if (!mounted || list.isEmpty) {
        return;
      }
      final Placemark p = list.first;
      String pick(String? v) => (v ?? '').trim();
      final String area =
          pick(p.subLocality).isNotEmpty ? pick(p.subLocality) : pick(p.street);
      setState(() {
        if (area.isNotEmpty) {
          _area.text = area;
        }
        if (pick(p.locality).isNotEmpty) {
          _city.text = pick(p.locality);
        }
        if (pick(p.subAdministrativeArea).isNotEmpty) {
          _district.text = pick(p.subAdministrativeArea);
        }
        if (pick(p.administrativeArea).isNotEmpty) {
          _state.text = pick(p.administrativeArea);
        }
        if (pick(p.postalCode).isNotEmpty) {
          _pincode.text = pick(p.postalCode);
        }
        _gpsSig = '${_area.text.trim()}|${_city.text.trim()}|${_pincode.text.trim()}';
        _note = 'Address filled from your location. Please check it and correct anything wrong.';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _note = 'Location captured, but the address could not be filled automatically. Please type it.';
      });
    }
  }

  Future<void> _save() async {
    final String house = _house.text.trim();
    final String area = _area.text.trim();
    final String landmark = _landmark.text.trim();
    final String pin = _pincode.text.trim();
    final String city = _city.text.trim();
    final String district = _district.text.trim();
    final String stateName = _state.text.trim();

    if (house.isEmpty) {
      setState(() {
        _error = 'Please enter your flat / house number and building name.';
      });
      return;
    }
    if (area.isEmpty) {
      setState(() {
        _error = 'Please enter your street / area.';
      });
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      setState(() {
        _error = 'Please enter a valid 6 digit pincode.';
      });
      return;
    }
    if (city.isEmpty || district.isEmpty || stateName.isEmpty) {
      setState(() {
        _error = 'Please enter your city, district and state.';
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
    final String addressLine =
        '$house, $area, $city, $district, $stateName - $pin';
    // GPS is used only if the address was filled from GPS and not edited.
    // Otherwise the TYPED address is looked up on the map.
    double? lat;
    double? lng;
    final bool gpsMatches =
        _lat != null && _lng != null && _gpsSig == '$area|$city|$pin';
    if (gpsMatches) {
      lat = _lat;
      lng = _lng;
    } else {
      try {
        final List<Location> found = await locationFromAddress(
          '$area, $city, $district, $stateName, $pin, India',
        );
        if (found.isNotEmpty) {
          lat = found.first.latitude;
          lng = found.first.longitude;
        }
      } catch (_) {}
    }
    if (lat == null || lng == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error =
            'We could not find this address on the map. Check the area, city and pincode, or tap "Use my current location" while you are at this address.';
      });
      return;
    }
    try {
      final DocumentReference<Map<String, dynamic>> userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final DocumentReference<Map<String, dynamic>> ref =
          await userRef.collection('addresses').add(<String, dynamic>{
        'label': _label,
        'house': house,
        'area': area,
        'landmark': landmark,
        'city': city,
        'district': district,
        'state': stateName,
        'pincode': pin,
        'addressLine': addressLine,
        'lat': lat,
        'lng': lng,
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

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? type,
    int? maxLength,
    List<TextInputFormatter>? formatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: type,
        maxLength: maxLength,
        inputFormatters: formatters,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add address')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: _locating || _saving ? null : _useCurrentLocation,
            icon: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: Text(
              _lat == null ? 'Use my current location' : 'Update my location',
            ),
          ),
          if (_lat != null && _lng != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Location captured: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
                '${_accuracy == null ? '' : ' (±${_accuracy!.round()} m)'}',
                style: const TextStyle(
                  color: TwingaColors.veg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (_note != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_note!),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: TwingaColors.error),
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            'Save address as',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: TwingaColors.ink,
            ),
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
          _field(_house, 'Flat / House no. and building name'),
          _field(_area, 'Street / Area / Locality'),
          _field(_landmark, 'Landmark (optional)'),
          _field(
            _pincode,
            'Pincode',
            type: TextInputType.number,
            maxLength: 6,
            formatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
          ),
          _field(_city, 'City'),
          _field(_district, 'District'),
          _field(_state, 'State'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving || _locating ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save address'),
          ),
        ],
      ),
    );
  }
}
