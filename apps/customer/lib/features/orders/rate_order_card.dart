import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Shown on a delivered order. The customer rates the restaurant once.
/// The review is saved as reviews/{orderId} and the restaurant's
/// average (rating, ratingSum, ratingCount) is updated in the same step.
class RateOrderCard extends StatefulWidget {
  const RateOrderCard({super.key, required this.orderId, required this.order});

  final String orderId;
  final Map<String, dynamic> order;

  @override
  State<RateOrderCard> createState() => _RateOrderCardState();
}

class _RateOrderCardState extends State<RateOrderCard> {
  int _stars = 0;
  final TextEditingController _note = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    if (_stars < 1) {
      setState(() {
        _error = 'Please tap a star to rate.';
      });
      return;
    }
    final String restaurantId = (widget.order['restaurantId'] ?? '').toString();
    if (restaurantId.isEmpty) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final FirebaseFirestore db = FirebaseFirestore.instance;
      final DocumentReference<Map<String, dynamic>> reviewRef =
          db.collection('reviews').doc(widget.orderId);
      final DocumentReference<Map<String, dynamic>> restRef =
          db.collection('restaurants').doc(restaurantId);
      final int stars = _stars;
      final String note = _note.text.trim();
      await db.runTransaction((tx) async {
        final DocumentSnapshot<Map<String, dynamic>> existing =
            await tx.get(reviewRef);
        if (existing.exists) {
          throw 'You have already rated this order.';
        }
        final DocumentSnapshot<Map<String, dynamic>> rest = await tx.get(restRef);
        final Map<String, dynamic> rd = rest.data() ?? <String, dynamic>{};
        final int oldSum = rd['ratingSum'] is num ? (rd['ratingSum'] as num).round() : 0;
        final int oldCount =
            rd['ratingCount'] is num ? (rd['ratingCount'] as num).round() : 0;
        final int count = oldCount + 1;
        final int sum = oldSum + stars;
        final double avg = (sum / count * 10).round() / 10;
        tx.set(reviewRef, <String, dynamic>{
          'orderId': widget.orderId,
          'customerUid': user.uid,
          'customerName': (widget.order['customerName'] ?? '').toString(),
          'restaurantId': restaurantId,
          'restaurantName': (widget.order['restaurantName'] ?? '').toString(),
          'rating': stars,
          'comment': note,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(restRef, <String, dynamic>{
          'ratingSum': sum,
          'ratingCount': count,
          'rating': avg,
        });
      });
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = e is String ? e : 'Could not save your rating. Please try again.';
      });
    }
  }

  Widget _stars5(int value, {bool tappable = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= 5; i++)
          GestureDetector(
            onTap: tappable
                ? () {
                    setState(() {
                      _stars = i;
                      _error = null;
                    });
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Icon(
                i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                size: tappable ? 40 : 26,
                color: TwingaColors.orange,
              ),
            ),
          ),
      ],
    );
  }

  BoxDecoration _box() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE3EAF7)),
      boxShadow: const [
        BoxShadow(color: Color(0x140A2A8F), blurRadius: 16, offset: Offset(0, 6)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String name = (widget.order['restaurantName'] ?? '').toString();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .doc(widget.orderId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox.shrink();
        }
        final Map<String, dynamic>? mine = snap.data!.data();
        if (mine != null) {
          final int given = mine['rating'] is num ? (mine['rating'] as num).round() : 0;
          final String comment = (mine['comment'] ?? '').toString();
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: _box(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thanks for rating',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: TwingaColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                _stars5(given),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(comment, style: const TextStyle(color: Colors.black54)),
                ],
              ],
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: _box(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Rate your order' : 'How was $name?',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: TwingaColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your rating helps other customers.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Center(child: _stars5(_stars, tappable: true)),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLength: 300,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Write a few words (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: TwingaColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Submit rating'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
