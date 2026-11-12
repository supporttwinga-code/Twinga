import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

class RegisterRiderScreen extends StatefulWidget {
  const RegisterRiderScreen({super.key, required this.name});

  final String name;

  @override
  State<RegisterRiderScreen> createState() => _RegisterRiderScreenState();
}

class _RegisterRiderScreenState extends State<RegisterRiderScreen> {
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _vehicleNumber = TextEditingController();
  final TextEditingController _city = TextEditingController();
  String _vehicleType = 'Bike';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _vehicleNumber.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String phone = _phone.text.trim();
    final String number = _vehicleNumber.text.trim().toUpperCase();
    final String city = _city.text.trim();
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      setState(() {
        _error = 'Please enter a valid 10 digit mobile number.';
      });
      return;
    }
    if (_vehicleType != 'Cycle' && number.length < 6) {
      setState(() {
        _error = 'Please enter your vehicle number.';
      });
      return;
    }
    if (city.isEmpty) {
      setState(() {
        _error = 'Please enter your city.';
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
      await FirebaseFirestore.instance
          .collection('riders')
          .doc(user.uid)
          .set(<String, dynamic>{
        'uid': user.uid,
        'name': widget.name,
        'phone': phone,
        'vehicleType': _vehicleType,
        'vehicleNumber': _vehicleType == 'Cycle' ? '' : number,
        'city': city,
        'status': 'pending',
        'isOnline': false,
        'cashInHandPaise': 0,
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
        _saving = false;
        _error = 'Could not save (${e.code}). Please try again.';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = 'Could not save. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rider registration')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              labelText: 'Mobile number',
              counterText: '',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Vehicle type',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: TwingaColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final String v in <String>['Bike', 'Scooter', 'Cycle'])
                ChoiceChip(
                  label: Text(v),
                  selected: _vehicleType == v,
                  onSelected: (_) {
                    setState(() {
                      _vehicleType = v;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_vehicleType != 'Cycle') ...[
            TextField(
              controller: _vehicleNumber,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Vehicle number (e.g. BR22 AB 1234)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _city,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'City you will deliver in',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: TwingaColors.error)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit for approval'),
            ),
          ),
        ],
      ),
    );
  }
}
