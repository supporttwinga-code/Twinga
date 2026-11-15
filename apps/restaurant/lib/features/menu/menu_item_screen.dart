import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/photo.dart';
import '../../core/theme.dart';

class MenuItemScreen extends StatefulWidget {
  const MenuItemScreen({super.key, required this.restaurantId, this.existing});

  final String restaurantId;
  final DocumentSnapshot<Map<String, dynamic>>? existing;

  @override
  State<MenuItemScreen> createState() => _MenuItemScreenState();
}

class _MenuItemScreenState extends State<MenuItemScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _category = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _description = TextEditingController();
  bool _isVeg = true;
  bool _available = true;
  bool _saving = false;
  String? _error;
  String? _image;

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore
      .instance
      .collection('restaurants')
      .doc(widget.restaurantId)
      .collection('menu');

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic>? d = widget.existing?.data();
    if (d != null) {
      _name.text = (d['name'] ?? '').toString();
      _category.text = (d['category'] ?? '').toString();
      _description.text = (d['description'] ?? '').toString();
      final dynamic p = d['pricePaise'];
      if (p is num) {
        final int paise = p.round();
        _price.text = paise % 100 == 0
            ? '${paise ~/ 100}'
            : (paise / 100).toStringAsFixed(2);
      }
      _isVeg = d['isVeg'] is bool ? d['isVeg'] as bool : true;
      _available = d['isAvailable'] is bool ? d['isAvailable'] as bool : false;
      final dynamic img = d['imageData'];
      _image = img is String && img.isNotEmpty ? img : null;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _name.text.trim();
    final String category = _category.text.trim();
    final String description = _description.text.trim();
    final double? price = double.tryParse(_price.text.trim());

    String? problem;
    if (name.isEmpty) {
      problem = 'Please enter the item name.';
    } else if (category.isEmpty) {
      problem = 'Please enter a category (for example: Pizza, Drinks).';
    } else if (price == null || price < 1 || price > 10000) {
      problem = 'Please enter a price between 1 and 10000 rupees.';
    }
    if (problem != null) {
      setState(() {
        _error = problem;
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final Map<String, dynamic> data = <String, dynamic>{
        'name': name,
        'category': category,
        'description': description,
        'pricePaise': (price! * 100).round(),
        'isVeg': _isVeg,
        'isAvailable': _available,
        'imageData': _image ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final DocumentSnapshot<Map<String, dynamic>>? old = widget.existing;
      if (old == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await _col.add(data);
      } else {
        await _col.doc(old.id).update(data);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not save (${e.code}). Please try again.';
        _saving = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not save. Please try again.';
        _saving = false;
      });
    }
  }

  Future<void> _delete() async {
    final DocumentSnapshot<Map<String, dynamic>>? old = widget.existing;
    if (old == null) {
      return;
    }
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this item?'),
        content: const Text('This item will be removed from your menu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) {
      return;
    }
    try {
      await _col.doc(old.id).delete();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not delete. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit item' : 'Add item'),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PhotoField(
            label: 'Food photo',
            hint: 'Tap to add a photo of this dish',
            value: _image,
            height: 170,
            maxSide: 600,
            quality: 65,
            onChanged: (String? v) {
              setState(() {
                _image = v;
              });
            },
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Item name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _category,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Category (for example: Pizza, Drinks)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Price (in rupees)',
              prefixText: '₹ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Short description (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Food type',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: TwingaColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Veg'),
                selected: _isVeg,
                onSelected: (_) {
                  setState(() {
                    _isVeg = true;
                  });
                },
              ),
              ChoiceChip(
                label: const Text('Non-veg'),
                selected: !_isVeg,
                onSelected: (_) {
                  setState(() {
                    _isVeg = false;
                  });
                },
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Available to order'),
            value: _available,
            onChanged: (bool v) {
              setState(() {
                _available = v;
              });
            },
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: TwingaColors.error),
              ),
            ),
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
                : Text(editing ? 'Save changes' : 'Add to menu'),
          ),
        ],
      ),
    );
  }
}
