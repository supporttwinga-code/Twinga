import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/brand.dart';
import '../auth/auth_gate.dart';

const String kSplashLine1 = 'Grow Your Restaurant';
const String kSplashLine2 = 'with TWINGA';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(const Duration(milliseconds: 2300), () {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (context) => const AuthGate()),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.navy,
      body: Container(
        decoration: const BoxDecoration(gradient: Brand.backdrop),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 96,
              child: CustomPaint(
                painter: SkylinePainter(Brand.gold.withValues(alpha: 0.35)),
              ),
            ),
            Center(
              child: FadeTransition(
                opacity: _c,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.88, end: 1.0).animate(
                    CurvedAnimation(parent: _c, curve: Curves.easeOutBack),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const TwingaLogo(scale: 1.35),
                      const SizedBox(height: 30),
                      Text(
                        kSplashLine1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      Text(
                        kSplashLine2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Brand.gold,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 118,
              child: Column(
                children: <Widget>[
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Brand.gold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('Loading...', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
