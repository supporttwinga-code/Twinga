import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/photo.dart';
import '../../core/theme.dart';

/// Home ke upar ka gol avatar. Photo ho to photo, warna naam ka pehla akshar.
/// Dabane par profile screen khulti hai.
class RiderAvatar extends StatelessWidget {
  const RiderAvatar({super.key, required this.name, this.size = 48});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final String initial =
        name.trim().isEmpty ? 'R' : name.trim()[0].toUpperCase();
    if (user == null) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('riders')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snap) {
        final bytes = decodePhoto(snap.data?.data()?['photoData']);
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RiderProfileScreen(uid: user.uid),
              ),
            );
          },
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFC15E), TwingaColors.orange],
                      ),
                    ),
                    child: ClipOval(
                      child: bytes != null
                          ? Image.memory(
                              bytes,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            )
                          : Center(
                              child: Text(
                                initial,
                                style: TextStyle(
                                  fontSize: size * 0.46,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.photo_camera,
                      size: size * 0.24,
                      color: TwingaColors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class RiderProfileScreen extends StatefulWidget {
  const RiderProfileScreen({super.key, required this.uid});

  final String uid;

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  Map<String, dynamic> _doc = <String, dynamic>{};
  String? _photo;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection('riders').doc(widget.uid);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> s = await _ref.get();
      _doc = s.data() ?? <String, dynamic>{};
      final dynamic p = _doc['photoData'];
      _photo = p is String && p.isNotEmpty ? p : null;
    } catch (_) {
      _error = 'Could not load your profile.';
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
      await _ref.update(<String, dynamic>{'photoData': _photo ?? ''});
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo saved.')),
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

  Widget _row(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: TwingaColors.blue),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String name = (_doc['name'] ?? '').toString();
    final String phone = (_doc['phone'] ?? '').toString();
    final String vehicle =
        '${(_doc['vehicleType'] ?? '').toString()} ${(_doc['vehicleNumber'] ?? '').toString()}'
            .trim();
    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PhotoField(
                  label: 'Profile photo',
                  hint: '',
                  value: _photo,
                  circle: true,
                  height: 140,
                  maxSide: 400,
                  quality: 65,
                  onChanged: (String? v) {
                    setState(() {
                      _photo = v;
                    });
                  },
                ),
                const SizedBox(height: 22),
                if (name.isNotEmpty)
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: TwingaColors.ink,
                    ),
                  ),
                const SizedBox(height: 6),
                if (phone.isNotEmpty) _row(Icons.call_outlined, phone),
                if (vehicle.isNotEmpty) _row(Icons.two_wheeler, vehicle),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: TwingaColors.error),
                    ),
                  ),
                const SizedBox(height: 18),
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
