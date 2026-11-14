import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

// Minimum amount a user can withdraw, in paise (Rs 100).
const int kMinWithdrawPaise = 10000;

String _rs(int paise) {
  final int whole = paise ~/ 100;
  final int rem = paise % 100;
  if (rem == 0) {
    return '₹$whole';
  }
  return '₹$whole.${rem.toString().padLeft(2, '0')}';
}

int _i(dynamic v) {
  if (v is num) {
    return v.round();
  }
  return 0;
}

String _date(dynamic t) {
  if (t is! Timestamp) {
    return '';
  }
  final DateTime d = t.toDate();
  const List<String> m = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

bool _hasPayout(Map<String, dynamic>? p) {
  if (p == null) {
    return false;
  }
  final String m = (p['method'] ?? 'upi').toString();
  if (m == 'bank') {
    return (p['accountNumber'] ?? '').toString().isNotEmpty &&
        (p['ifsc'] ?? '').toString().isNotEmpty;
  }
  return (p['upiId'] ?? '').toString().isNotEmpty;
}

String _dest(Map<String, dynamic>? p) {
  if (!_hasPayout(p)) {
    return '';
  }
  if ((p!['method'] ?? 'upi').toString() == 'bank') {
    final String acc = (p['accountNumber'] ?? '').toString();
    final String last = acc.length > 4 ? acc.substring(acc.length - 4) : acc;
    return '${(p['bankName'] ?? 'Bank').toString()}  A/c ••$last';
  }
  return (p['upiId'] ?? '').toString();
}

BoxDecoration _box() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: const Color(0xFFE3EAF7)),
    boxShadow: const [
      BoxShadow(color: Color(0x140A2A8F), blurRadius: 16, offset: Offset(0, 6)),
    ],
  );
}

DocumentReference<Map<String, dynamic>> _profileRef(String uid) {
  return FirebaseFirestore.instance.collection('payoutProfiles').doc(uid);
}

/// role: 'restaurant' or 'rider'
class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key, required this.uid, required this.role});

  final String uid;
  final String role;

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final TextEditingController _amount = TextEditingController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _orders;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _payouts;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _profile;
  bool _busy = false;
  String? _error;
  String? _ok;

  bool get _isRider => widget.role == 'rider';

  @override
  void initState() {
    super.initState();
    final FirebaseFirestore db = FirebaseFirestore.instance;
    _orders = db
        .collection('orders')
        .where(_isRider ? 'riderUid' : 'restaurantOwnerUid',
            isEqualTo: widget.uid)
        .snapshots();
    _payouts = db
        .collection('payouts')
        .where('uid', isEqualTo: widget.uid)
        .snapshots();
    _profile = _profileRef(widget.uid).snapshots();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int _earned(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int sum = 0;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> d in docs) {
      final Map<String, dynamic> m = d.data();
      if ((m['status'] ?? '').toString() != 'delivered') {
        continue;
      }
      if (_isRider) {
        sum += _i(m['riderPayPaise']);
      } else {
        sum += _i(m['foodSubtotalPaise']) - _i(m['commissionPaise']);
      }
    }
    return sum;
  }

  Future<void> _submit({
    required int available,
    required Map<String, dynamic>? profile,
  }) async {
    final String holder = (profile?['holderName'] ?? '').toString();
    if (!_hasPayout(profile)) {
      setState(() {
        _error = 'Please add your UPI ID or bank account first.';
        _ok = null;
      });
      return;
    }
    final int? rupees = int.tryParse(_amount.text.trim());
    if (rupees == null || rupees <= 0) {
      setState(() {
        _error = 'Enter the amount in rupees.';
        _ok = null;
      });
      return;
    }
    final int paise = rupees * 100;
    if (paise < kMinWithdrawPaise) {
      setState(() {
        _error = 'Minimum withdrawal is ${_rs(kMinWithdrawPaise)}.';
        _ok = null;
      });
      return;
    }
    if (paise > available) {
      setState(() {
        _error = 'You can withdraw up to ${_rs(available)} right now.';
        _ok = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _ok = null;
    });
    try {
      await FirebaseFirestore.instance.collection('payouts').add(<String, dynamic>{
        'uid': widget.uid,
        'role': widget.role,
        'amountPaise': paise,
        'method': (profile?['method'] ?? 'upi').toString(),
        'upiId': (profile?['upiId'] ?? '').toString(),
        'bankName': (profile?['bankName'] ?? '').toString(),
        'accountNumber': (profile?['accountNumber'] ?? '').toString(),
        'ifsc': (profile?['ifsc'] ?? '').toString(),
        'destination': _dest(profile),
        'holderName': holder,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _amount.clear();
      _ok = 'Request sent. Twinga will pay it to your account and mark it Paid.';
    } catch (e) {
      _error = 'Could not send the request. Check your internet and try again.';
    }
    if (mounted) {
      setState(() {
        _busy = false;
      });
    }
  }

  Widget _chip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(36),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            FittedBox(
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: Colors.white.withAlpha(215), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    Color c = TwingaColors.orange;
    String t = 'Pending';
    if (status == 'paid') {
      c = TwingaColors.veg;
      t = 'Paid';
    } else if (status == 'rejected') {
      c = TwingaColors.error;
      t = 'Rejected';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        t,
        style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwingaColors.background,
      appBar: AppBar(
        title: const Text('Withdraw'),
        backgroundColor: TwingaColors.blue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _orders,
        builder: (context, os) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _payouts,
            builder: (context, ps) {
              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _profile,
                builder: (context, pf) {
                  if (os.hasError || ps.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Could not load your balance. Please try again.'),
                      ),
                    );
                  }
                  if (!os.hasData || !ps.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final int earned = _earned(os.data!.docs);
                  int paid = 0;
                  int pending = 0;
                  final List<QueryDocumentSnapshot<Map<String, dynamic>>> list =
                      ps.data!.docs.toList();
                  for (final QueryDocumentSnapshot<Map<String, dynamic>> d in list) {
                    final Map<String, dynamic> m = d.data();
                    final String s = (m['status'] ?? '').toString();
                    if (s == 'paid') {
                      paid += _i(m['amountPaise']);
                    } else if (s == 'pending') {
                      pending += _i(m['amountPaise']);
                    }
                  }
                  list.sort((a, b) {
                    final dynamic x = a.data()['createdAt'];
                    final dynamic y = b.data()['createdAt'];
                    if (x is Timestamp && y is Timestamp) {
                      return y.compareTo(x);
                    }
                    return 0;
                  });
                  int available = earned - paid - pending;
                  if (available < 0) {
                    available = 0;
                  }
                  final Map<String, dynamic>? profile = pf.data?.data();
                  final String upi = _dest(profile);
                  final String holder = (profile?['holderName'] ?? '').toString();
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF0A3FB5), TwingaColors.blue, Color(0xFF3AA4FF)],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x330A3FB5),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Available to withdraw',
                              style: TextStyle(color: Colors.white.withAlpha(220)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _rs(available),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 38,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                _chip('Total earned', _rs(earned), Colors.white),
                                const SizedBox(width: 8),
                                _chip('Pending', _rs(pending), Colors.white),
                                const SizedBox(width: 8),
                                _chip('Paid', _rs(paid), Colors.white),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: _box(),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3EEFF),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_outlined,
                                color: TwingaColors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Payout account',
                                    style: TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                  Text(
                                    upi.isEmpty ? 'Not added yet' : upi,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: TwingaColors.ink,
                                    ),
                                  ),
                                  if (holder.isNotEmpty)
                                    Text(holder, style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => PayoutDetailsScreen(
                                      uid: widget.uid,
                                      role: widget.role,
                                    ),
                                  ),
                                );
                              },
                              child: Text(upi.isEmpty ? 'Add' : 'Change'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: _box(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Request withdrawal',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: TwingaColors.ink,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _amount,
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              maxLength: 7,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                              decoration: InputDecoration(
                                prefixText: '₹ ',
                                labelText: 'Amount in rupees',
                                helperText:
                                    'Minimum ${_rs(kMinWithdrawPaise)}. Paid to your account by Twinga.',
                                counterText: '',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: ActionChip(
                                label: const Text('Withdraw all'),
                                onPressed: available >= kMinWithdrawPaise
                                    ? () {
                                        setState(() {
                                          _amount.text = '${available ~/ 100}';
                                        });
                                      }
                                    : null,
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                style: const TextStyle(color: TwingaColors.error),
                              ),
                            ],
                            if (_ok != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _ok!,
                                style: const TextStyle(
                                  color: TwingaColors.veg,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _submit(available: available, profile: profile),
                              icon: _busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                              label: const Text(
                                'Request withdrawal',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                            if (_isRider) ...[
                              const SizedBox(height: 10),
                              const Text(
                                'This is your delivery earning. Cash you collect from customers is settled separately with Twinga.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Withdrawal history',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: TwingaColors.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (list.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: _box(),
                          child: const Text('No withdrawal requests yet.'),
                        ),
                      for (final QueryDocumentSnapshot<Map<String, dynamic>> d in list)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: _box(),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _rs(_i(d.data()['amountPaise'])),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: TwingaColors.ink,
                                      ),
                                    ),
                                    Text(
                                      '${_date(d.data()['createdAt'])}  ·  ${(d.data()['destination'] ?? d.data()['upiId'] ?? '').toString()}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              _statusPill((d.data()['status'] ?? '').toString()),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class PayoutDetailsScreen extends StatefulWidget {
  const PayoutDetailsScreen({super.key, required this.uid, required this.role});

  final String uid;
  final String role;

  @override
  State<PayoutDetailsScreen> createState() => _PayoutDetailsScreenState();
}

class _PayoutDetailsScreenState extends State<PayoutDetailsScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _upi = TextEditingController();
  final TextEditingController _bank = TextEditingController();
  final TextEditingController _acc = TextEditingController();
  final TextEditingController _acc2 = TextEditingController();
  final TextEditingController _ifsc = TextEditingController();
  String _method = 'upi';
  bool _loaded = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _upi.dispose();
    _bank.dispose();
    _acc.dispose();
    _acc2.dispose();
    _ifsc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> s =
          await _profileRef(widget.uid).get();
      final Map<String, dynamic>? m = s.data();
      if (m != null) {
        _name.text = (m['holderName'] ?? '').toString();
        _upi.text = (m['upiId'] ?? '').toString();
        _bank.text = (m['bankName'] ?? '').toString();
        _acc.text = (m['accountNumber'] ?? '').toString();
        _acc2.text = (m['accountNumber'] ?? '').toString();
        _ifsc.text = (m['ifsc'] ?? '').toString();
        _method = (m['method'] ?? 'upi').toString() == 'bank' ? 'bank' : 'upi';
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _loaded = true;
      });
    }
  }

  Future<void> _save() async {
    final String name = _name.text.trim();
    final String upi = _upi.text.trim().toLowerCase();
    final String bank = _bank.text.trim();
    final String acc = _acc.text.trim();
    final String acc2 = _acc2.text.trim();
    final String ifsc = _ifsc.text.trim().toUpperCase();
    String? problem;
    if (name.length < 2) {
      problem = 'Enter the account holder name.';
    } else if (_method == 'upi') {
      if (!RegExp(r'^[a-z0-9.\-_]{2,}@[a-z][a-z0-9]{1,}$').hasMatch(upi)) {
        problem = 'Enter a valid UPI ID, for example name@okaxis';
      }
    } else {
      if (bank.length < 2) {
        problem = 'Enter your bank name.';
      } else if (!RegExp(r'^\d{9,18}$').hasMatch(acc)) {
        problem = 'Account number must be 9 to 18 digits.';
      } else if (acc != acc2) {
        problem = 'The two account numbers do not match.';
      } else if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(ifsc)) {
        problem = 'Enter a valid 11 character IFSC code, for example SBIN0001234.';
      }
    }
    if (problem != null) {
      setState(() {
        _error = problem;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _profileRef(widget.uid).set(<String, dynamic>{
        'uid': widget.uid,
        'role': widget.role,
        'method': _method,
        'holderName': name,
        'upiId': _method == 'upi' ? upi : '',
        'bankName': _method == 'bank' ? bank : '',
        'accountNumber': _method == 'bank' ? acc : '',
        'ifsc': _method == 'bank' ? ifsc : '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not save. Check your internet and try again.';
        });
      }
    }
  }

  InputDecoration _dec(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      counterText: '',
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Widget _gap() => const SizedBox(height: 12);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwingaColors.background,
      appBar: AppBar(
        title: const Text('Payout details'),
        backgroundColor: TwingaColors.blue,
        foregroundColor: Colors.white,
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Your earnings are paid to this account. Check it carefully, we cannot get money back from a wrong account.',
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: 'upi',
                      label: Text('UPI'),
                      icon: Icon(Icons.qr_code_2),
                    ),
                    ButtonSegment<String>(
                      value: 'bank',
                      label: Text('Bank account'),
                      icon: Icon(Icons.account_balance),
                    ),
                  ],
                  selected: <String>{_method},
                  onSelectionChanged: (Set<String> v) {
                    setState(() {
                      _method = v.first;
                      _error = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: _dec('Account holder name'),
                ),
                _gap(),
                if (_method == 'upi')
                  TextField(
                    controller: _upi,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: _dec('UPI ID', hint: 'name@okaxis'),
                  )
                else ...[
                  TextField(
                    controller: _bank,
                    textCapitalization: TextCapitalization.words,
                    decoration: _dec('Bank name'),
                  ),
                  _gap(),
                  TextField(
                    controller: _acc,
                    keyboardType: TextInputType.number,
                    maxLength: 18,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: _dec('Account number'),
                  ),
                  _gap(),
                  TextField(
                    controller: _acc2,
                    keyboardType: TextInputType.number,
                    maxLength: 18,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: _dec('Re-enter account number'),
                  ),
                  _gap(),
                  TextField(
                    controller: _ifsc,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 11,
                    autocorrect: false,
                    decoration: _dec('IFSC code', hint: 'SBIN0001234'),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: TwingaColors.error)),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save payout details',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ],
            ),
    );
  }
}
