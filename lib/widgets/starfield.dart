import 'dart:math' as math;

import 'package:fl_clash/common/app_theme.dart';
import 'package:flutter/material.dart';

/// The landing page's starfield, app-wide: sparse lime/white/cyan stars that
/// twinkle and drift slowly across the whole background.
///
/// One repeating controller drives a single painter; the parent wraps it in a
/// RepaintBoundary so the twinkle never repaints the rest of the tree.
class Starfield extends StatefulWidget {
  const Starfield({super.key});

  @override
  State<Starfield> createState() => _StarfieldState();
}

class _StarfieldState extends State<Starfield>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Static sky when the platform asks for reduced motion.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StarfieldPainter(_controller),
      isComplex: false,
      willChange: true,
      size: Size.infinite,
    );
  }
}

class _Star {
  final double x; // fractions of the canvas size
  final double y;
  final double radius;
  final Color color;
  final bool glows;
  final double phase; // twinkle offset, 0..1
  final int twinkles; // full twinkle cycles per drift loop (integer => seamless)
  final double drift; // horizontal wraps per loop

  const _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.color,
    required this.glows,
    required this.phase,
    required this.twinkles,
    required this.drift,
  });
}

final List<_Star> _stars = _generateStars();

List<_Star> _generateStars() {
  // Deterministic: the sky looks the same on every launch.
  final random = math.Random(0xD11C);
  const colors = [
    // The lime accents carry the look; white fills in; cyan seasons it.
    (AppTheme.lime, true),
    (AppTheme.lime, true),
    (AppTheme.text, false),
    (AppTheme.text, false),
    (AppTheme.cyan, false),
  ];
  return List.generate(36, (index) {
    final (color, glows) = colors[index % colors.length];
    return _Star(
      x: random.nextDouble(),
      y: random.nextDouble(),
      // A touch larger than the landing's 1-1.3px dots, per the brief.
      radius: 1.5 + random.nextDouble() * 1.5,
      color: color,
      glows: glows,
      phase: random.nextDouble(),
      twinkles: 6 + random.nextInt(7),
      drift: random.nextBool() ? 1 : 2,
    );
  });
}

class _StarfieldPainter extends CustomPainter {
  final Animation<double> animation;

  _StarfieldPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final paint = Paint();
    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    for (final star in _stars) {
      final x = ((star.x + t * star.drift) % 1) * size.width;
      final y = star.y * size.height;
      final twinkle =
          0.5 + 0.5 * math.sin(2 * math.pi * (t * star.twinkles + star.phase));
      final opacity = 0.25 + 0.6 * twinkle;
      final center = Offset(x, y);
      if (star.glows) {
        glowPaint.color = star.color.withValues(alpha: opacity * 0.45);
        canvas.drawCircle(center, star.radius * 2.6, glowPaint);
      }
      paint.color = star.color.withValues(alpha: opacity);
      canvas.drawCircle(center, star.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_StarfieldPainter oldDelegate) =>
      oldDelegate.animation != animation;
}
