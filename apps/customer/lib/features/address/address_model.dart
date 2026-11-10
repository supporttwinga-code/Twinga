import 'package:cloud_firestore/cloud_firestore.dart';

String _str(dynamic v, String fallback) {
  if (v is String && v.trim().isNotEmpty) {
    return v.trim();
  }
  return fallback;
}

double _num(dynamic v) {
  if (v is num) {
    return v.toDouble();
  }
  return 0;
}

class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.addressLine,
    required this.landmark,
    required this.lat,
    required this.lng,
  });

  final String id;
  final String label;
  final String addressLine;
  final String landmark;
  final double lat;
  final double lng;

  factory SavedAddress.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> d = doc.data() ?? <String, dynamic>{};
    return SavedAddress(
      id: doc.id,
      label: _str(d['label'], 'Other'),
      addressLine: _str(d['addressLine'], ''),
      landmark: _str(d['landmark'], ''),
      lat: _num(d['lat']),
      lng: _num(d['lng']),
    );
  }
}
