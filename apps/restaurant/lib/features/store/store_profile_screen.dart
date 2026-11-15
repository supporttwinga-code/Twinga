import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/photo.dart';
import '../../core/theme.dart';

/// Restaurant wala yahan apni store photo, logo aur heading set karta hai.
class StoreProfileScreen extends StatefulWidget {
  const StoreProfileScreen({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  State<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends State<StoreProfileScreen> {
  final TextEditingController _tagline = TextEditingController();
  String? _cover;
  String? _logo;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  DocumentReference<Map<String, dynamic>> get _ref => FirebaseFirestore
      .instance
      .collection('restaurants')
      .doc(widget.restaurantId);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tagline.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> s = await _ref.get();
      final Map<String, dynamic> d = s.data() ?? <String, dynamic>{};
      _tagline.text = (d['tagline'] ?? '').toString();
      final dynamic c = d['imageData'];
      final dynamic l = d['logoData'];
      _cover = c is String && c.isNotEmpty ? c : null;
      _logo = l is String && l.isNotEmpty ? l : null;
    } catch (_) {
      _error = 'Could not load your store details.';
    }
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _ref.update(<String, dynamic>{
        'tagline': _tagline.text.trim(),
        'imageData': _cover ?? '',
        'logoData': _logo ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store details saved.')),
      );
      Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not save (${e.code}). Please try again.';
        _saving = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not save. Please try again.';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Store photos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Customers see these on the home screen and on your menu. Good photos get more orders.',
                  style: TextStyle(color: Colors.black54, height: 1.35),
                ),
                const SizedBox(height: 18),
                PhotoField(
                  label: 'Store photo (cover)',
                  hint: 'Tap to add a wide photo of your restaurant or best dish',
                  value: _cover,
                  height: 180,
                  maxSide: 900,
                  quality: 60,
                  onChanged: (String? v) {
                    setState(() {
                      _cover = v;
                    });
                  },
                ),
                const SizedBox(height: 22),
                PhotoField(
                  label: 'Profile photo (logo)',
                  hint: '',
                  value: _logo,
                  circle: true,
                  height: 110,
                  maxSide: 400,
                  quality: 65,
                  onChanged: (String? v) {
                    setState(() {
                      _logo = v;
                    });
                  },
                ),
                const SizedBox(height: 22),
                const Text(
                  'Heading',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: TwingaColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tagline,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'For example: Wood-fired pizza, made fresh',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: TwingaColors.error),
                    ),
                  ),
                const SizedBox(height: 6),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
    );
  }
}
