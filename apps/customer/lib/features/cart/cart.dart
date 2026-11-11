import 'package:flutter/foundation.dart';

import '../restaurants/restaurant_models.dart';

class CartLine {
  CartLine({
    required this.itemId,
    required this.name,
    required this.pricePaise,
    required this.isVeg,
    required this.qty,
  });

  final String itemId;
  final String name;
  final int pricePaise;
  final bool isVeg;
  int qty;
}

class Cart extends ChangeNotifier {
  Restaurant? _restaurant;
  final Map<String, CartLine> _lines = <String, CartLine>{};

  Restaurant? get restaurant => _restaurant;
  List<CartLine> get lines => _lines.values.toList();
  bool get isEmpty => _lines.isEmpty;

  int get itemCount {
    int n = 0;
    for (final CartLine l in _lines.values) {
      n += l.qty;
    }
    return n;
  }

  int get foodPaise {
    int n = 0;
    for (final CartLine l in _lines.values) {
      n += l.qty * l.pricePaise;
    }
    return n;
  }

  int qtyOf(String itemId) {
    final CartLine? l = _lines[itemId];
    return l == null ? 0 : l.qty;
  }

  bool belongsToOther(Restaurant r) {
    final Restaurant? current = _restaurant;
    return current != null && _lines.isNotEmpty && current.id != r.id;
  }

  void add(Restaurant r, MenuItem item) {
    if (belongsToOther(r)) {
      _lines.clear();
    }
    _restaurant = r;
    final CartLine? line = _lines[item.id];
    if (line == null) {
      _lines[item.id] = CartLine(
        itemId: item.id,
        name: item.name,
        pricePaise: item.pricePaise,
        isVeg: item.isVeg,
        qty: 1,
      );
    } else if (line.qty < 20) {
      line.qty += 1;
    }
    notifyListeners();
  }

  void increase(String itemId) {
    final CartLine? line = _lines[itemId];
    if (line != null && line.qty < 20) {
      line.qty += 1;
      notifyListeners();
    }
  }

  void decrease(String itemId) {
    final CartLine? line = _lines[itemId];
    if (line == null) {
      return;
    }
    if (line.qty <= 1) {
      _lines.remove(itemId);
    } else {
      line.qty -= 1;
    }
    if (_lines.isEmpty) {
      _restaurant = null;
    }
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    _restaurant = null;
    notifyListeners();
  }
}

final Cart cart = Cart();
