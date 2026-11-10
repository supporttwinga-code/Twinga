import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'features/splash/splash_screen.dart';

void main() {
  runApp(const TwingaApp());
}

class TwingaApp extends StatelessWidget {
  const TwingaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Twinga',
      debugShowCheckedModeBanner: false,
      theme: TwingaTheme.light(),
      home: const SplashScreen(),
    );
  }
}
