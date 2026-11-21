import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';

class PromoBanner {
  const PromoBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.imageBytes,
    required this.sortOrder,
  });

  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final Uint8List? imageBytes;
  final int sortOrder;

  bool get hasPhoto => imageBytes != null;

  bool get hasImage => hasPhoto || imageUrl.startsWith('https://');

  /// Photos the admin picks from the gallery are saved as base64 text.
  static Uint8List? _decode(dynamic v) {
    if (v is! String) {
      return null;
    }
    String t = v.trim();
    if (t.isEmpty) {
      return null;
    }
    final int comma = t.indexOf(',');
    if (t.startsWith('data:') && comma >= 0) {
      t = t.substring(comma + 1);
    }
    try {
      final Uint8List bytes = base64Decode(t);
      return bytes.isEmpty ? null : bytes;
    } catch (e) {
      return null;
    }
  }

  factory PromoBanner.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> d = doc.data();
    String s(dynamic v) => v is String ? v.trim() : '';
    final dynamic order = d['sortOrder'];
    return PromoBanner(
      id: doc.id,
      title: s(d['title']),
      subtitle: s(d['subtitle']),
      imageUrl: s(d['imageUrl']),
      imageBytes: _decode(d['imageData']),
      sortOrder: order is num ? order.toInt() : 999,
    );
  }
}

/// Shows the banners the admin has switched on. With no active banner it
/// shows nothing at all, so there is never a fake promotion on screen.
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.92);
  final Stream<QuerySnapshot<Map<String, dynamic>>> _stream = FirebaseFirestore
      .instance
      .collection('banners')
      .where('active', isEqualTo: true)
      .snapshots();
  Timer? _timer;
  int _page = 0;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_count < 2 || !_controller.hasClients) {
        return;
      }
      final int next = (_page + 1) % _count;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        final QuerySnapshot<Map<String, dynamic>>? data = snap.data;
        if (snap.hasError || data == null) {
          return const SizedBox.shrink();
        }
        final List<PromoBanner> banners = data.docs
            .map(PromoBanner.fromDoc)
            .where((b) => b.title.isNotEmpty)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        _count = banners.length;
        if (banners.isEmpty) {
          return const SizedBox.shrink();
        }
        if (_page >= banners.length) {
          _page = 0;
        }
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(
            children: [
              SizedBox(
                height: 172,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: banners.length,
                  onPageChanged: (i) {
                    setState(() {
                      _page = i;
                    });
                  },
                  itemBuilder: (context, i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: _BannerCard(
                        banner: banners[i],
                        index: i,
                        onTap: widget.onTap,
                      ),
                    );
                  },
                ),
              ),
              if (banners.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < banners.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: 7,
                          width: i == _page ? 22 : 7,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? TwingaColors.blue
                                : TwingaColors.blue.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

const List<List<Color>> _fallbacks = <List<Color>>[
  <Color>[Color(0xFF0077F7), Color(0xFF0A3FB5)],
  <Color>[Color(0xFFFFB347), Color(0xFFE65100)],
  <Color>[Color(0xFF3AA4FF), Color(0xFF0A3FB5)],
];

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.banner,
    required this.index,
    required this.onTap,
  });

  final PromoBanner banner;
  final int index;
  final VoidCallback? onTap;

  Widget _gradient() {
    final List<Color> c = _fallbacks[index % _fallbacks.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: c,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -50,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (banner.imageBytes != null)
                Image.memory(
                  banner.imageBytes!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stack) => _gradient(),
                )
              else if (banner.hasImage)
                Image.network(
                  banner.imageUrl,
                  fit: BoxFit.cover,
                  frameBuilder: (context, child, frame, sync) {
                    return AnimatedOpacity(
                      opacity: frame == null && !sync ? 0 : 1,
                      duration: const Duration(milliseconds: 350),
                      child: child,
                    );
                  },
                  errorBuilder: (context, error, stack) => _gradient(),
                )
              else
                _gradient(),
              if (banner.hasImage)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.72),
                        Colors.black.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 90, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      banner.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (banner.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        banner.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Order now',
                        style: TextStyle(
                          color: TwingaColors.blue,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
