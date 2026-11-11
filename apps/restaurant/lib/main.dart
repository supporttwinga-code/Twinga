import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'features/splash/splash_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? startupError;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
  } catch (e) {
    startupError = e.toString();
  }
  runApp(PartnerApp(startupError: startupError));
}

class PartnerApp extends StatelessWidget {
  const PartnerApp({super.key, this.startupError});

  final String? startupError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Twinga Partner',
      debugShowCheckedModeBanner: false,
      theme: TwingaTheme.light(),
      home: startupError == null
          ? const SplashScreen()
          : Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Startup error:\n$startupError'),
                ),
              ),
            ),
    );
  }
}
