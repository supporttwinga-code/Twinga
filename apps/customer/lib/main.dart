import 'package:flutter/material.dart';

void main() => runApp(const TwingaApp());

class TwingaApp extends StatelessWidget {
  const TwingaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Twinga',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text(
            'Hello Twinga',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
