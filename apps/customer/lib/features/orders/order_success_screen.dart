import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'order_status_screen.dart';

double _seg(double t, double a, double b) {
  final double x = (t - a) / (b - a);
  if (x < 0) {
    return 0;
  }
  if (x > 1) {
    return 1;
  }
  return x;
}

/// Shown for about 4 seconds right after an order is placed:
/// the badge spins in and draws a tick, then the rest opens,
/// then the live order screen opens.
class OrderSuccessScreen extends StatefulWidget {
  const OrderSuccessScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with SingleTickerProviderStateMixin {
  static const double _totalSec = 4.2;
  static const Color _cyan = Color(0xFF32A8FF);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );
  Timer? _timer;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(const Duration(milliseconds: 4200), _go);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _go() {
    if (_gone || !mounted) {
      return;
    }
    _gone = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => OrderStatusScreen(orderId: widget.orderId),
      ),
    );
  }

  Widget _trust(IconData icon, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: _cyan, size: 26),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF020B2E),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _go,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF020B2E),
                  Color(0xFF05185A),
                  Color(0xFF0A2A8F),
                ],
              ),
            ),
            child: SafeArea(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final double t = _c.value * _totalSec;
                  final double pop =
                      Curves.easeOutBack.transform(_seg(t, 0, 0.6));
                  final double spin =
                      Curves.easeOutCubic.transform(_seg(t, 0, 1.4));
                  final double check =
                      Curves.easeInOut.transform(_seg(t, 0.6, 1.3));
                  final double reveal =
                      Curves.easeOut.transform(_seg(t, 1.2, 1.9));
                  final double count = _seg(t, 1.2, 4.2);
                  final double burst = _seg(t, 1.2, 2.8);
                  final int secs = (3 - count * 3).ceil().clamp(1, 3).toInt();
                  return Center(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: _seg(t, 0, 0.5),
                            child: const Column(
                              children: [
                                Text(
                                  'Twinga',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 46,
                                    fontWeight: FontWeight.w800,
                                    fontStyle: FontStyle.italic,
                                    letterSpacing: -1,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Food  •  Fast  •  Fresh',
                                  style: TextStyle(
                                    color: Color(0xFFB8C7F0),
                                    fontSize: 14,
                                    letterSpacing: 3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 260,
                            height: 220,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CustomPaint(
                                  size: const Size(260, 220),
                                  painter: _ConfettiPainter(burst),
                                ),
                                CustomPaint(
                                  size: const Size(260, 220),
                                  painter: _BadgePainter(pop, spin, check),
                                ),
                              ],
                            ),
                          ),
                          Opacity(
                            opacity: reveal,
                            child: Transform.translate(
                              offset: Offset(0, (1 - reveal) * 24),
                              child: Column(
                                children: [
                                  const Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: 'Order ',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        TextSpan(
                                          text: 'Placed!',
                                          style: TextStyle(color: _cyan),
                                        ),
                                      ],
                                    ),
                                    style: TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Your order has been sent to the restaurant.\nYou can track it live on the next screen.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFFC9D6F7),
                                      fontSize: 15,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: 78,
                                    height: 78,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SizedBox(
                                          width: 78,
                                          height: 78,
                                          child: CircularProgressIndicator(
                                            value: 1 - count,
                                            strokeWidth: 4,
                                            backgroundColor: Colors.white24,
                                            color: _cyan,
                                          ),
                                        ),
                                        Text(
                                          '${secs}s',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Redirecting...',
                                    style: TextStyle(
                                      color: Color(0xFFB8C7F0),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(20),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: Colors.white.withAlpha(40),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        _trust(Icons.bolt, 'Fast\nDelivery'),
                                        _trust(
                                          Icons.verified_user_outlined,
                                          'Safe &\nSecure',
                                        ),
                                        _trust(
                                          Icons.room_service_outlined,
                                          'Delicious\nAlways',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Row(
                                    children: [
                                      Expanded(
                                        child: Divider(color: Colors.white24),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Icon(
                                          Icons.favorite_border,
                                          color: _cyan,
                                          size: 18,
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(color: Colors.white24),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Thank you for choosing Twinga',
                                    style: TextStyle(
                                      color: Color(0xFFC9D6F7),
                                      fontSize: 14,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  _BadgePainter(this.scale, this.spin, this.check);

  final double scale;
  final double spin;
  final double check;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double r = 62 * scale;
    if (r <= 0) {
      return;
    }
    canvas.drawCircle(
      c,
      r + 14,
      Paint()
        ..color = const Color(0x5532A8FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    // orbit ring: spins in first, then rests slightly tilted
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.3 + (1 - spin) * math.pi * 3);
    final Rect oval = Rect.fromCenter(
      center: Offset.zero,
      width: 250 * scale,
      height: 84 * scale,
    );
    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..shader = const SweepGradient(
          colors: [
            Color(0x0032A8FF),
            Color(0xFF32A8FF),
            Color(0xFFFFFFFF),
            Color(0x0032A8FF),
          ],
          stops: [0, 0.5, 0.75, 1],
        ).createShader(oval),
    );
    canvas.restore();
    // badge
    final Rect box = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF2B7BFF), Color(0xFF0A2E9E)],
        ).createShader(box),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF5BC0FF),
    );
    // tick
    final Offset p0 = Offset(c.dx - r * 0.40, c.dy + r * 0.02);
    final Offset p1 = Offset(c.dx - r * 0.10, c.dy + r * 0.32);
    final Offset p2 = Offset(c.dx + r * 0.42, c.dy - r * 0.28);
    final Path path = Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy);
    final Paint tick = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * check), tick);
    }
  }

  @override
  bool shouldRepaint(_BadgePainter old) =>
      old.scale != scale || old.spin != spin || old.check != check;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) {
      return;
    }
    final Offset c = Offset(size.width / 2, size.height / 2);
    final math.Random rnd = math.Random(7);
    const List<int> colors = <int>[0xFFFFFFFF, 0xFF5BC0FF, 0xFFFFC83D];
    final double move = Curves.easeOut.transform(progress);
    final int alpha = ((1 - progress) * 255).round().clamp(0, 255).toInt();
    for (int i = 0; i < 16; i++) {
      final double a = rnd.nextDouble() * math.pi * 2;
      final double speed = 90 + rnd.nextDouble() * 110;
      final double rot = rnd.nextDouble() * math.pi;
      final Color col = Color(colors[i % 3]).withAlpha(alpha);
      final Offset pos = Offset(
        c.dx + math.cos(a) * speed * move,
        c.dy + math.sin(a) * speed * move + 40 * progress * progress,
      );
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(rot + progress * 4);
      canvas.drawRect(
        const Rect.fromLTWH(-5, -2.5, 10, 5),
        Paint()..color = col,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
