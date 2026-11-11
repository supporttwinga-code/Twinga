import 'package:cloud_firestore/cloud_firestore.dart';

String _asString(dynamic v, String fallback) {
  if (v is String && v.trim().isNotEmpty) {
    return v.trim();
  }
  return fallback;
}

int _asInt(dynamic v, int fallback) {
  if (v is num) {
    return v.round();
  }
  return fallback;
}

double _asDouble(dynamic v, double fallback) {
  if (v is num) {
    return v.toDouble();
  }
  return fallback;
}

bool _asBool(dynamic v, bool fallback) {
  if (v is bool) {
    return v;
  }
  return fallback;
}

class Restaurant {
  const Restaurant({
    required this.id,
    required this.ownerUid,
    required this.name,
    required this.cuisines,
    required this.isOpen,
    required this.rating,
    required this.prepTimeMin,
    required this.packagingChargePaise,
    required this.imageUrl,
    required this.lat,
    required this.lng,
    required this.radiusKm,
  });

  final String id;
  final String ownerUid;
  final String name;
  final String cuisines;
  final bool isOpen;
  final double rating;
  final int prepTimeMin;
  final int packagingChargePaise;
  final String imageUrl;
  final double lat;
  final double lng;
  final double radiusKm;

  bool get hasLocation => lat != 0 || lng != 0;

  factory Restaurant.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> d = doc.data() ?? <String, dynamic>{};
    return Restaurant(
      id: doc.id,
      ownerUid: _asString(d['ownerUid'], ''),
      name: _asString(d['name'], 'Restaurant'),
      cuisines: _asString(d['cuisines'], ''),
      isOpen: _asBool(d['isOpen'], false),
      rating: _asDouble(d['rating'], 0),
      prepTimeMin: _asInt(d['prepTimeMin'], 20),
      packagingChargePaise: _asInt(d['packagingChargePaise'], 0),
      imageUrl: _asString(d['imageUrl'], ''),
      lat: _asDouble(d['lat'], 0),
      lng: _asDouble(d['lng'], 0),
      radiusKm: _asDouble(d['deliveryRadiusKm'], 0),
    );
  }
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.pricePaise,
    required this.isVeg,
    required this.isAvailable,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final int pricePaise;
  final bool isVeg;
  final bool isAvailable;

  factory MenuItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> d = doc.data() ?? <String, dynamic>{};
    return MenuItem(
      id: doc.id,
      name: _asString(d['name'], 'Item'),
      category: _asString(d['category'], 'Menu'),
      description: _asString(d['description'], ''),
      pricePaise: _asInt(d['pricePaise'], 0),
      isVeg: _asBool(d['isVeg'], true),
      isAvailable: _asBool(d['isAvailable'], false),
    );
  }
}
