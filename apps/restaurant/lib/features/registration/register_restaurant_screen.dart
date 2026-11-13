import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme.dart';

class RegisterRestaurantScreen extends StatefulWidget {
  const RegisterRestaurantScreen({super.key});

  @override
  State<RegisterRestaurantScreen> createState() =>
      _RegisterRestaurantScreenState();
}

class _RegisterRestaurantScreenState extends State<RegisterRestaurantScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _cuisines = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _fssai = TextEditingController();
  final TextEditingController _house = TextEditingController();
  final TextEditingController _area = TextEditingController();
  final TextEditingController _landmark = TextEditingController();
  final TextEditingController _pincode = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _district = TextEditingController();
  final TextEditingController _state = TextEditingController();
  final TextEditingController _packaging = TextEditingController(text: '0');
  final TextEditingController _prep = TextEditingController(text: '20');
  final List<TextInputFormatter> _digits = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
  ];

  double _radius = 5;
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
    _name.dispose();
    _cuisines.dispose();
    _phone.dispose();
    _fssai.dispose();
    _house.dispose();
    _area.dispose();
    _landmark.dispose();
    _pincode.dispose();
    _city.dispose();
    _district.dispose();
    _state.dispose();
    _packaging.dispose();
    _prep.dispose();
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
        throw 'Location permission is needed. Open phone Settings > Apps > Twinga Partner > Permissions > Location and allow it.';
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
    final String name = _name.text.trim();
    final String cuisines = _cuisines.text.trim();
    final String phone = _phone.text.trim();
    final String fssai = _fssai.text.trim();
    final String house = _house.text.trim();
    final String area = _area.text.trim();
    final String landmark = _landmark.text.trim();
    final String pin = _pincode.text.trim();
    final String city = _city.text.trim();
    final String district = _district.text.trim();
    final String stateName = _state.text.trim();
    final String pkgText = _packaging.text.trim();
    final int? pkg = pkgText.isEmpty ? 0 : int.tryParse(pkgText);
    final int? prep = int.tryParse(_prep.text.trim());

    String? problem;
    if (name.length < 2) {
      problem = 'Please enter your restaurant name.';
    } else if (cuisines.isEmpty) {
      problem = 'Please enter the cuisines you serve (for example: North Indian, Chinese).';
    } else if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      problem = 'Please enter a valid 10 digit mobile number.';
    } else if (!RegExp(r'^\d{14}$').hasMatch(fssai)) {
      problem = 'Please enter your 14 digit FSSAI licence number.';
    } else if (house.isEmpty) {
      problem = 'Please enter your shop / building number.';
    } else if (area.isEmpty) {
      problem = 'Please enter your street / area.';
    } else if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      problem = 'Please enter a valid 6 digit pincode.';
    } else if (city.isEmpty || district.isEmpty || stateName.isEmpty) {
      problem = 'Please enter your city, district and state.';
    } else if (pkg == null || pkg < 0 || pkg > 200) {
      problem = 'Packaging charge must be between 0 and 200 rupees.';
    } else if (prep == null || prep < 5 || prep > 120) {
      problem = 'Preparation time must be between 5 and 120 minutes.';
    }
    if (problem != null) {
      setState(() {
        _error = problem;
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
            'We could not find this address on the map. Check the area, city and pincode, or tap "Use my current location" while you are inside your restaurant.';
      });
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(user.uid)
          .set(<String, dynamic>{
        'ownerUid': user.uid,
        'status': 'pending',
        'name': name,
        'cuisines': cuisines,
        'phone': phone,
        'fssai': fssai,
        'house': house,
        'area': area,
        'landmark': landmark,
        'city': city,
        'district': district,
        'state': stateName,
        'pincode': pin,
        'addressLine': '$house, $area, $city, $district, $stateName - $pin',
        'lat': lat,
        'lng': lng,
        'deliveryRadiusKm': _radius.round(),
        'packagingChargePaise': pkg! * 100,
        'prepTimeMin': prep!,
        'isOpen': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not submit (${e.code}). Please try again.';
        _saving = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not submit. Please try again.';
        _saving = false;
      });
    }
  }

  Widget _title(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: TwingaColors.ink,
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? type,
    int? maxLength,
    List<TextInputFormatter>? formatters,
    String? helper,
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
          helperText: helper,
          counterText: '',
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register your restaurant')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _title('Restaurant details'),
          _field(_name, 'Restaurant name'),
          _field(_cuisines, 'Cuisines (for example: North Indian, Chinese)'),
          _field(
            _phone,
            'Restaurant mobile number',
            type: TextInputType.number,
            maxLength: 10,
            formatters: _digits,
          ),
          _field(
            _fssai,
            'FSSAI licence number',
            type: TextInputType.number,
            maxLength: 14,
            formatters: _digits,
            helper: '14 digits, required for food businesses',
          ),
          _title('Restaurant address'),
          _field(_house, 'Shop / building number'),
          _field(_area, 'Street / Area / Locality'),
          _field(_landmark, 'Landmark (optional)'),
          _field(
            _pincode,
            'Pincode',
            type: TextInputType.number,
            maxLength: 6,
            formatters: _digits,
          ),
          _field(_city, 'City'),
          _field(_district, 'District'),
          _field(_state, 'State'),
          _title('Restaurant location'),
          const Text(
            'Best: stand inside your restaurant and tap the button. It fills the address from your location. If you type the address yourself, we find its place on the map from what you typed.',
          ),
          const SizedBox(height: 10),
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
          _title('Delivery and charges'),
          Text('Delivery radius: ${_radius.round()} km'),
          Slider(
            value: _radius,
            min: 1,
            max: 10,
            divisions: 9,
            label: '${_radius.round()} km',
            onChanged: (double v) {
              setState(() {
                _radius = v;
              });
            },
          ),
          const SizedBox(height: 8),
          _field(
            _packaging,
            'Packaging charge per order (in rupees)',
            type: TextInputType.number,
            maxLength: 3,
            formatters: _digits,
            helper: '0 to 200. Shown to customers as a separate line.',
          ),
          _field(
            _prep,
            'Average preparation time (minutes)',
            type: TextInputType.number,
            maxLength: 3,
            formatters: _digits,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: TwingaColors.error),
              ),
            ),
          const SizedBox(height: 4),
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
                : const Text('Submit for approval'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
