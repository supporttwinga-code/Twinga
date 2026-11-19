import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Twinga brand colours and small reusable widgets.
class Brand {
  Brand._();

  static const Color navy = Color(0xFF061A66);
  static const Color royal = Color(0xFF0A3FB5);
  static const Color blue = Color(0xFF0B57E0);
  static const Color sky = Color(0xFF3AA4FF);
  static const Color gold = Color(0xFFFFB400);
  static const Color goldDeep = Color(0xFFF08A00);
  static const Color ink = Color(0xFF14213D);
  static const Color mist = Color(0xFFF3F7FF);
  static const Color error = Color(0xFFD93025);
  static const Color ok = Color(0xFF1E9E4A);

  static const LinearGradient backdrop = LinearGradient(
    colors: <Color>[navy, royal, Color(0xFF1B6FE8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient action = LinearGradient(
    colors: <Color>[royal, blue],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

class _ClochePainter extends CustomPainter {
  const _ClochePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Paint gold = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[Color(0xFFFFD25A), Color(0xFFF08A00)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    final Path dome = Path()
      ..moveTo(0, h * 0.9)
      ..arcTo(Rect.fromLTRB(0, h * 0.2, w, h * 1.6), math.pi, math.pi, false)
      ..close();
    canvas.drawPath(dome, gold);
    canvas.drawCircle(Offset(w / 2, h * 0.12), h * 0.1, gold);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.04, h * 0.93, w * 0.92, h * 0.07),
        const Radius.circular(3),
      ),
      gold,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SpeedLines extends StatelessWidget {
  const _SpeedLines({required this.scale});

  final double scale;

  Widget _bar(double w) {
    return Container(
      width: w * scale,
      height: 3.4 * scale,
      margin: EdgeInsets.symmetric(vertical: 2.2 * scale),
      decoration: BoxDecoration(
        color: Brand.gold,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[_bar(24), _bar(32), _bar(18)],
    );
  }
}

/// The TWINGA logo drawn in code, so no image file is needed.
class TwingaLogo extends StatelessWidget {
  const TwingaLogo({
    super.key,
    this.scale = 1.0,
    this.dark = false,
    this.tagline = true,
  });

  final double scale;
  final bool dark;
  final bool tagline;

  @override
  Widget build(BuildContext context) {
    final Color text = dark ? Brand.royal : Colors.white;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 62 * scale,
          height: 34 * scale,
          child: const CustomPaint(painter: _ClochePainter()),
        ),
        SizedBox(height: 2 * scale),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            _SpeedLines(scale: scale),
            SizedBox(width: 6 * scale),
            Text(
              'TWINGA',
              style: TextStyle(
                fontSize: 42 * scale,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: -1.2,
                height: 1.0,
                color: text,
              ),
            ),
          ],
        ),
        if (tagline)
          Padding(
            padding: EdgeInsets.only(top: 4 * scale),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Good Food',
                  style: TextStyle(
                    fontSize: 14 * scale,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    color: text,
                  ),
                ),
                Text(
                  '  \u2022  ',
                  style: TextStyle(fontSize: 14 * scale, color: Brand.gold),
                ),
                Text(
                  'Faster',
                  style: TextStyle(
                    fontSize: 14 * scale,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    color: Brand.gold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A row of simple city buildings, used at the bottom of screens.
class SkylinePainter extends CustomPainter {
  const SkylinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()..color = color;
    double x = 0;
    int i = 0;
    while (x < size.width) {
      final double w = 20.0 + ((i * 7) % 4) * 6;
      final double h = size.height * (0.25 + ((i * 5) % 5) * 0.08);
      final double top = size.height - h;
      final double bw = w - 2;
      canvas.drawRect(Rect.fromLTWH(x, top, bw, h), p);
      if (i % 3 == 0) {
        canvas.drawArc(
          Rect.fromLTWH(x, top - bw * 0.45, bw, bw * 0.9),
          math.pi,
          math.pi,
          true,
          p,
        );
        canvas.drawRect(
          Rect.fromLTWH(x + bw / 2 - 0.8, top - bw * 0.45 - 7, 1.6, 7),
          p,
        );
      } else if (i % 3 == 1) {
        final Path t = Path()
          ..moveTo(x + 2, top)
          ..lineTo(x + bw / 2, top - 12)
          ..lineTo(x + bw - 2, top)
          ..close();
        canvas.drawPath(t, p);
      }
      x += w;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant SkylinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Round white badge with a big icon, used in the login header.
class HeroBadge extends StatelessWidget {
  const HeroBadge({super.key, required this.icon, this.size = 104});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Center(
        child: Container(
          width: size * 0.72,
          height: size * 0.72,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: <Color>[Color(0xFFFFD25A), Brand.goldDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: size * 0.4),
        ),
      ),
    );
  }
}

/// Rounded input box with an icon on the left.
class BrandField extends StatelessWidget {
  const BrandField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboard,
    this.obscure = false,
    this.trailing,
    this.formatters,
    this.capitalization = TextCapitalization.none,
    this.onSubmitted,
    this.center = false,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboard;
  final bool obscure;
  final Widget? trailing;
  final List<TextInputFormatter>? formatters;
  final TextCapitalization capitalization;
  final VoidCallback? onSubmitted;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: EdgeInsets.only(left: 16, right: trailing == null ? 16 : 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Brand.royal.withValues(alpha: 0.14)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Brand.royal.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: Brand.royal, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboard,
              obscureText: obscure,
              inputFormatters: formatters,
              textCapitalization: capitalization,
              textAlign: center ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                fontSize: center ? 20 : 16,
                fontWeight: FontWeight.w700,
                letterSpacing: center ? 6 : 0,
                color: Brand.ink,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Colors.black38,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  fontSize: 16,
                ),
              ),
              onSubmitted: (_) {
                if (onSubmitted != null) {
                  onSubmitted!();
                }
              },
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Blue gradient pill button.
class BrandButton extends StatelessWidget {
  const BrandButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.small = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool small;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final double radius = small ? 22 : 30;
    return Opacity(
      opacity: (onPressed == null && !loading) ? 0.55 : 1,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: Brand.action,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Brand.royal.withValues(alpha: 0.30),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: loading ? null : onPressed,
            child: Container(
              height: small ? 42 : 56,
              padding: EdgeInsets.symmetric(horizontal: small ? 16 : 0),
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          label,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: small ? 14 : 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (icon != null) ...<Widget>[
                          const SizedBox(width: 8),
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, size: 16, color: Brand.royal),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
