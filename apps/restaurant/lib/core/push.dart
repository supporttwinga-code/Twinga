import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

/// Wrap the signed-in home screen with this. It asks for notification
/// permission, subscribes the app to its topic, and shows messages that
/// arrive while the app is open.
class PushStarter extends StatefulWidget {
  const PushStarter({super.key, required this.topic, required this.child});

  final String topic;
  final Widget child;

  @override
  State<PushStarter> createState() => _PushStarterState();
}

class _PushStarterState extends State<PushStarter> {
  StreamSubscription<RemoteMessage>? _sub;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final FirebaseMessaging m = FirebaseMessaging.instance;
      await m.requestPermission();
      await m.subscribeToTopic(widget.topic);
      _sub = FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
        final RemoteNotification? n = msg.notification;
        if (n == null || !mounted) {
          return;
        }
        final String title = n.title ?? '';
        final String body = n.body ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                if (body.isNotEmpty) Text(body),
              ],
            ),
          ),
        );
      });
    } catch (e) {
      // Notifications are optional. The app works without them.
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    try {
      FirebaseMessaging.instance.unsubscribeFromTopic(widget.topic);
    } catch (e) {
      // ignore
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
