import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'add_address_screen.dart';
import 'address_model.dart';

class AddressScreen extends StatelessWidget {
  const AddressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final DocumentReference<Map<String, dynamic>> userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    return Scaffold(
      appBar: AppBar(title: const Text('My addresses')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userRef.snapshots(),
        builder: (context, userSnap) {
          final dynamic raw = userSnap.data?.data()?['defaultAddressId'];
          final String defaultId = raw is String ? raw : '';
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: userRef.collection('addresses').snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load addresses:\n${snap.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final List<SavedAddress> list =
                  snap.data!.docs.map((d) => SavedAddress.fromDoc(d)).toList();
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'You have no saved addresses yet.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final SavedAddress a in list)
                    Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: a.id == defaultId
                              ? TwingaColors.blue
                              : const Color(0xFFE3EEFF),
                          width: a.id == defaultId ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        onTap: () {
                          userRef.update(<String, dynamic>{
                            'defaultAddressId': a.id,
                          });
                        },
                        leading: const Icon(Icons.location_on,
                            color: TwingaColors.orange),
                        title: Text(
                          a.label,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          a.landmark.isEmpty
                              ? a.addressLine
                              : '${a.addressLine}\nLandmark: ${a.landmark}',
                        ),
                        isThreeLine: a.landmark.isNotEmpty,
                        trailing: IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await userRef
                                .collection('addresses')
                                .doc(a.id)
                                .delete();
                            if (a.id == defaultId) {
                              await userRef.update(<String, dynamic>{
                                'defaultAddressId': FieldValue.delete(),
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => const AddAddressScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add new address'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
