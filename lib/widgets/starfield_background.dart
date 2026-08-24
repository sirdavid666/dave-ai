import 'dart:math';

import 'package:flutter/material.dart';

class StarfieldBackground extends StatefulWidget {
  const StarfieldBackground({
    super.key,
    this.starCount = 90,
  });

  final int starCount;

  @override
  State<StarfieldBackground> createState() =>
      _StarfieldBackgroundState();
}

class _Star {
  _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.phase,
  });

  final double x;
  final double y;
  final double radius;
  final double speed;
  final double phase;
}

class _StarfieldBackgroundState
    extends State<StarfieldBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController
      controller;

  final Random random = Random();

  List<_Star> stars = [];

  bool initialized = false;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(
        seconds: 60,
      ),
    )..repeat();
  }

  void _ensureStars(Size size) {
    if (initialized) {
      return;
    }

    stars = List.generate(
      widget.starCount,
      (index) {
        return _Star(
          x: random.nextDouble() *
              size.width,
          y: random.nextDouble() *
              size.height,
          radius:
              random.nextDouble() *
                      1.6 +
                  0.4,
          speed: random.nextDouble() *
                  12 +
              4,
          phase: random.nextDouble() *
              pi *
              2,
        );
      },
    );

    initialized = true;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );

        _ensureStars(size);

        return Container(
          decoration:
              const BoxDecoration(
            gradient: LinearGradient(
              begin:
                  Alignment.topLeft,
              end: Alignment
                  .bottomRight,
              colors: [
                Color(0xFF0B1026),
                Color(0xFF141033),
                Color(0xFF0B1026),
              ],
            ),
          ),
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              return CustomPaint(
                size: size,
                painter: _StarPainter(
                  stars: stars,
                  progress:
                      controller.value,
                  size: size,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _StarPainter
    extends CustomPainter {
  _StarPainter({
    required this.stars,
    required this.progress,
    required this.size,
  });

  final List<_Star> stars;
  final double progress;
  final Size size;

  @override
  void paint(
    Canvas canvas,
    Size canvasSize,
  ) {
    final paint = Paint();

    final elapsedSeconds =
        progress * 60;

    for (final star in stars) {
      var y = star.y +
          star.speed * elapsedSeconds;

      y = y % (size.height + 20);

      final twinkle =
          (sin(
                    elapsedSeconds *
                            2 +
                        star.phase,
                  ) +
                  1) /
              2;

      paint.color = Colors.white
          .withOpacity(
        0.25 + twinkle * 0.6,
      );

      canvas.drawCircle(
        Offset(star.x, y),
        star.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _StarPainter
        oldDelegate,
  ) {
    return oldDelegate.progress !=
        progress;
  }
}
