import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'address_model.dart';
import 'address_screen.dart';

class AddressBar extends StatelessWidget {
  const AddressBar({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final DocumentReference<Map<String, dynamic>> userRef =
        FirebaseFirestore.instance.collection('users').doc(uid);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userRef.snapshots(),
      builder: (context, userSnap) {
        final dynamic raw = userSnap.data?.data()?['defaultAddressId'];
        if (raw is! String || raw.isEmpty) {
          return _bar(context, 'Add your delivery address', null);
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userRef.collection('addresses').doc(raw).snapshots(),
          builder: (context, addrSnap) {
            final DocumentSnapshot<Map<String, dynamic>>? doc = addrSnap.data;
            if (doc == null || !doc.exists) {
              return _bar(context, 'Add your delivery address', null);
            }
            final SavedAddress a = SavedAddress.fromDoc(doc);
            return _bar(context, 'Deliver to ${a.label}', a.addressLine);
          },
        );
      },
    );
  }

  Widget _bar(BuildContext context, String title, String? subtitle) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (context) => const AddressScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: TwingaColors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: TwingaColors.ink,
                      ),
                    ),
                    if (subtitle != null)
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.expand_more),
            ],
          ),
        ),
      ),
    );
  }
}
