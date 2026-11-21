import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../earnings/rider_earnings_screen.dart';
import '../withdraw/withdraw_screen.dart';

const String _kSite = 'https://twinga.support-twinga.workers.dev';
const String _kSupportEmail = 'support.twinga@gmail.com';
const String _kRoleLabel = 'DELIVERY PARTNER';
const String _kAppName = 'Twinga Rider';
const String _kVersion = '1.0.0';

const Color _navy = Color(0xFF061A66);
const Color _royal = Color(0xFF0A3FB5);
const Color _blue = Color(0xFF0B57E0);
const Color _sky = Color(0xFF3AA4FF);
const Color _gold = Color(0xFFFFB400);
const Color _ink = Color(0xFF14213D);
const Color _bg = Color(0xFFF3F7FF);
const Color _red = Color(0xFFD93025);
const Color _green = Color(0xFF1E9E4A);

/// Profile / account page: edit name, help, legal pages, about, delete
/// account and log out.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final String uid = user.uid;
    final String email = user.email ?? '';
    final String phone = uid.length == 14 ? '+91 ${uid.substring(4)}' : '';
    return Scaffold(
      backgroundColor: _bg,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          final Map<String, dynamic>? data = snapshot.data?.data();
          final String name = (data?['name'] ?? '').toString().trim();
          final String contact = phone.isNotEmpty ? phone : email;
          return ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              _Header(
                name: name,
                contact: contact,
                onEdit: () => _editName(context, uid, name),
              ),
              const SizedBox(height: 18),
              _Section(
                title: 'ACCOUNT',
                children: <Widget>[
                  _Tile(
                    icon: Icons.person_rounded,
                    title: 'Edit profile',
                    subtitle: name.isEmpty ? 'Add your name' : name,
                    onTap: () => _editName(context, uid, name),
                  ),
                  if (phone.isNotEmpty)
                    _Tile(
                      icon: Icons.phone_android_rounded,
                      title: 'Mobile number',
                      subtitle: phone,
                      trailing: const Icon(Icons.copy_rounded,
                          size: 18, color: Colors.black38),
                      onTap: () => _copy(context, phone, 'Number copied'),
                    ),
                  if (email.isNotEmpty)
                    _Tile(
                      icon: Icons.mail_rounded,
                      title: 'Email',
                      subtitle: email,
                      trailing: const Icon(Icons.copy_rounded,
                          size: 18, color: Colors.black38),
                      onTap: () => _copy(context, email, 'Email copied'),
                    ),
                  _Tile(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'My earnings',
                    subtitle: 'See what you have earned',
                    color: _green,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => RiderEarningsScreen(uid: uid),
                        ),
                      );
                    },
                  ),
                  _Tile(
                    icon: Icons.payments_rounded,
                    title: 'Withdraw money',
                    subtitle: 'Send earnings to your bank or UPI',
                    color: _green,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) =>
                              WithdrawScreen(uid: uid, role: 'rider'),
                        ),
                      );
                    },
                  ),
                ],
              ),
              _Section(
                title: 'HELP',
                children: <Widget>[
                  _Tile(
                    icon: Icons.support_agent_rounded,
                    title: 'Help and support',
                    subtitle: 'We reply on email',
                    onTap: () => _showHelp(context),
                  ),
                  _Tile(
                    icon: Icons.flag_rounded,
                    title: 'Report a problem',
                    subtitle: 'Tell us what went wrong',
                    color: const Color(0xFFF08A00),
                    onTap: () => _mail(
                      context,
                      'Problem report - $_kAppName',
                      'App: $_kAppName $_kVersion\nUser: $uid\n\nPlease describe the problem:\n',
                    ),
                  ),
                  _Tile(
                    icon: Icons.lightbulb_rounded,
                    title: 'Send feedback',
                    subtitle: 'Ideas to make Twinga better',
                    color: const Color(0xFF7A3CFF),
                    onTap: () => _mail(
                      context,
                      'Feedback - $_kAppName',
                      'App: $_kAppName $_kVersion\n\nYour feedback:\n',
                    ),
                  ),
                ],
              ),
              _Section(
                title: 'LEGAL',
                children: <Widget>[
                  _Tile(
                    icon: Icons.privacy_tip_rounded,
                    title: 'Privacy Policy',
                    onTap: () => _openUrl(context, '$_kSite/privacy.html'),
                  ),
                  _Tile(
                    icon: Icons.description_rounded,
                    title: 'Terms and Conditions',
                    onTap: () => _openUrl(context, '$_kSite/terms.html'),
                  ),
                ],
              ),
              _Section(
                title: 'ABOUT',
                children: <Widget>[
                  _Tile(
                    icon: Icons.info_rounded,
                    title: 'About Twinga',
                    subtitle: 'Version $_kVersion',
                    onTap: () => _showAbout(context),
                  ),
                  _Tile(
                    icon: Icons.language_rounded,
                    title: 'Visit our website',
                    subtitle: 'twinga.support-twinga.workers.dev',
                    onTap: () => _openUrl(context, _kSite),
                  ),
                ],
              ),
              _Section(
                title: 'ACCOUNT ACTIONS',
                children: <Widget>[
                  _Tile(
                    icon: Icons.delete_forever_rounded,
                    title: 'Delete my account',
                    subtitle: 'Remove your account and data',
                    color: _red,
                    onTap: () => _confirmDelete(context),
                  ),
                  _Tile(
                    icon: Icons.logout_rounded,
                    title: 'Log out',
                    color: _red,
                    onTap: () => _confirmLogout(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'TWINGA  |  v$_kVersion',
                  style: TextStyle(
                    color: Colors.black45,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- actions

void _toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );
}

Future<void> _copy(BuildContext context, String text, String done) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    _toast(context, done);
  }
}

Future<void> _openUrl(BuildContext context, String url) async {
  bool ok = false;
  try {
    ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (e) {
    ok = false;
  }
  if (!ok && context.mounted) {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      _toast(context, 'Could not open the link. It was copied instead.');
    }
  }
}

Future<void> _mail(BuildContext context, String subject, String body) async {
  final Uri uri = Uri.parse(
    'mailto:$_kSupportEmail?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
  );
  bool ok = false;
  try {
    ok = await launchUrl(uri);
  } catch (e) {
    ok = false;
  }
  if (!ok && context.mounted) {
    await Clipboard.setData(const ClipboardData(text: _kSupportEmail));
    if (context.mounted) {
      _toast(context, 'No email app found. Address copied: $_kSupportEmail');
    }
  }
}

Future<void> _editName(BuildContext context, String uid, String current) async {
  final TextEditingController c = TextEditingController(text: current);
  final String? v = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Edit your name'),
      content: TextField(
        controller: c,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Full name',
          border: OutlineInputBorder(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(c.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (v == null || !context.mounted) {
    return;
  }
  if (v.length < 2) {
    _toast(context, 'Please enter your name.');
    return;
  }
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update(<String, dynamic>{'name': v});
    if (context.mounted) {
      _toast(context, 'Name updated.');
    }
  } catch (e) {
    if (context.mounted) {
      _toast(context, 'Could not save. Please try again.');
    }
  }
}

void _showHelp(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Help and support',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Write to us and we will get back to you. If it is about an order, please add the order number.',
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const SelectableText(
                _kSupportEmail,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _blue,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _mail(context, 'Help - $_kAppName', 'Hello Twinga,\n\n');
                    },
                    icon: const Icon(Icons.mail_rounded),
                    label: const Text('Write to us'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _copy(context, _kSupportEmail, 'Email copied');
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy email'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

void _showAbout(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('About Twinga'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'TWINGA',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _royal,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 4),
          Text('Food delivery from restaurants near you.'),
          SizedBox(height: 10),
          Text('$_kAppName  |  Version $_kVersion'),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> _confirmDelete(BuildContext context) async {
  final bool? yes = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Delete your account?'),
      content: const Text(
        'This opens the account deletion page on our website, where you can request removal of your account and data.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Continue', style: TextStyle(color: _red)),
        ),
      ],
    ),
  );
  if (yes == true && context.mounted) {
    await _openUrl(context, '$_kSite/delete-account.html');
  }
}

Future<void> _confirmLogout(BuildContext context) async {
  final bool? yes = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Log out?'),
      content: const Text('You will need to sign in again.'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Stay'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Log out', style: TextStyle(color: _red)),
        ),
      ],
    ),
  );
  if (yes == true) {
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
    }
    await FirebaseAuth.instance.signOut();
  }
}

// ---------------------------------------------------------------- widgets

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.contact,
    required this.onEdit,
  });

  final String name;
  final String contact;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final bool canPop = Navigator.of(context).canPop();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[_navy, _royal, Color(0xFF1B6FE8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                if (canPop)
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                  )
                else
                  const SizedBox(height: 48),
                const Spacer(),
                IconButton(
                  tooltip: 'Edit name',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, color: Colors.white),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                Container(
                  width: 74,
                  height: 74,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: _gold, width: 3),
                  ),
                  child: Text(
                    name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: _royal,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name.isEmpty ? 'Welcome!' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (contact.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            contact,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _gold,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          _kRoleLabel,
                          style: TextStyle(
                            color: _navy,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(const Divider(height: 1, indent: 70, endIndent: 16));
      }
      rows.add(children[i]);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 0, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: Colors.black45,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF0A2A8F).withValues(alpha: 0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: Column(children: rows),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.color = _royal,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: color == _royal ? _ink : color,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: trailing ??
          const Icon(Icons.chevron_right_rounded, color: Colors.black38),
    );
  }
}
