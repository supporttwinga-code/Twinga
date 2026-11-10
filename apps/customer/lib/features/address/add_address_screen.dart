
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
  final _house = TextEditingController();
  final _area = TextEditingController();
  final _landmark = TextEditingController();
  final _pincode = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _state = TextEditingController();

  String _label = 'Home';
  double? _lat;
  double? _lng;
  double? _accuracy;

  bool _locating = false;
  bool _saving = false;
  String? _error;
  String? _note;

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

  String _clean(String? value) {
    return (value ?? '').trim();
  }

  Future<void> _useCurrentLocation() async {
    if (_locating || _saving) return;

    setState(() {
      _locating = true;
      _error = null;
      _note = null;
    });

    try {
      final bool enabled =
          await Geolocator.isLocationServiceEnabled();

      if (!enabled) {
        throw Exception('Please turn on GPS on your phone.');
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Please allow location permission in phone settings.',
        );
      }

      final Position position =
          await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );

      if (!mounted) return;

      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _accuracy = position.accuracy;
      });

      await _fillFromPlacemark(
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _locating = false;
        });
      }
    }
  }

  Future<void> _fillFromPlacemark(
    double lat,
    double lng,
  ) async {
    try {
      final List<Placemark> places =
          await placemarkFromCoordinates(lat, lng);

      if (!mounted || places.isEmpty) return;

      final Placemark place = places.first;

      final String area = _clean(place.subLocality).isNotEmpty
          ? _clean(place.subLocality)
          : _clean(place.street);

      final String city = _clean(place.locality);

      final String stateName =
          _clean(place.administrativeArea);

      final String pin = _clean(place.postalCode);

      setState(() {
        if (area.isNotEmpty) _area.text = area;

        if (city.isNotEmpty) _city.text = city;

        // Do not mistake a division or sub-administrative
        // region for a district.
        // Customer confirms the actual district manually.
        _district.clear();

        if (stateName.isNotEmpty) {
          _state.text = stateName;
        }

        if (RegExp(r'^\d{6}$').hasMatch(pin)) {
          _pincode.text = pin;
        }

        _note =
            'Location detected. Please verify your address and enter your district.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _note =
            'GPS captured. Please enter your address details manually.';
      });
    }
  }

  Future<void> _save() async {
    if (_saving || _locating) return;

    final String house = _house.text.trim();
    final String area = _area.text.trim();
    final String landmark = _landmark.text.trim();
    final String pin = _pincode.text.trim();
    final String city = _city.text.trim();
    final String district = _district.text.trim();
    final String stateName = _state.text.trim();

    if (house.isEmpty) {
      setState(() {
        _error = 'Please enter your house or building number.';
      });
      return;
    }

    if (area.isEmpty) {
      setState(() {
        _error = 'Please enter your street or area.';
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
        _error = 'Please enter city, district and state correctly.';
      });
      return;
    }

    if (_lat == null || _lng == null) {
      setState(() {
        _error = 'Please capture your current location first.';
      });
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        _error = 'Please sign in again before saving your address.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final String addressLine =
        '$house, $area, $city, $district, $stateName - $pin';

    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      final addressRef =
          await userRef.collection('addresses').add({
        'label': _label,
        'house': house,
        'area': area,
        'landmark': landmark,
        'city': city,
        'district': district,
        'state': stateName,
        'pincode': pin,
        'addressLine': addressLine,
        'lat': _lat!,
        'lng': _lng!,
        'accuracy': _accuracy,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await userRef.set({
        'defaultAddressId': addressRef.id,
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Address save failed (${e.code}). Please try again.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not save address. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
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
      appBar: AppBar(
        title: const Text('Add address'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed:
                _locating || _saving ? null : _useCurrentLocation,
            icon: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.my_location),
            label: Text(
              _lat == null
                  ? 'Use my current location'
                  : 'Update my location',
            ),
          ),

          if (_lat != null && _lng != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Location captured: '
                '${_lat!.toStringAsFixed(5)}, '
                '${_lng!.toStringAsFixed(5)}'
                '${_accuracy == null ? '' : ' (±${_accuracy!.round()} m)'}',
                style: const TextStyle(
                  color: TwingaColors.veg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

          if (_note != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_note!),
            ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: TwingaColors.error,
                ),
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
              for (final String label in ['Home', 'Work', 'Other'])
                ChoiceChip(
                  label: Text(label),
                  selected: _label == label,
                  onSelected: _saving
                      ? null
                      : (_) {
                          setState(() {
                            _label = label;
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
            formatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
          _field(_city, 'City'),
          _field(_district, 'District'),
          _field(_state, 'State'),

          const SizedBox(height: 12),

          FilledButton(
            onPressed:
                _saving || _locating ? null : _save,
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
