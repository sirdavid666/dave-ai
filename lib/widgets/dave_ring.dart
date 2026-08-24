import 'dart:math';

import 'package:flutter/material.dart';

class DaveRing extends StatefulWidget {
  const DaveRing({
    super.key,
    this.size = 220,
  });

  final double size;

  @override
  State<DaveRing> createState() =>
      _DaveRingState();
}

class _DaveRingState
    extends State<DaveRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController
      controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(
        seconds: 6,
      ),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size(
              widget.size,
              widget.size,
            ),
            painter: _RingPainter(
              progress:
                  controller.value,
            ),
            child: const Center(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Text(
                    'DAVE',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight:
                          FontWeight
                              .bold,
                      letterSpacing: 3,
                      color: Colors
                          .white,
                    ),
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  Text(
                    '• ONLINE •',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 2,
                      color: Color(
                        0xFF00E08A,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter
    extends CustomPainter {
  _RingPainter({
    required this.progress,
  });

  final double progress;

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final maxRadius =
        size.width / 2;

    void drawDashedRing(
      double radius,
      double rotation,
      int dashCount,
      double dashFraction,
      Color color,
      double strokeWidth,
    ) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepPerDash =
          (2 * pi / dashCount) *
              dashFraction;

      final gapPerDash =
          (2 * pi / dashCount) -
              sweepPerDash;

      for (var i = 0;
          i < dashCount;
          i++) {
        final start = rotation +
            i *
                (sweepPerDash +
                    gapPerDash);

        canvas.drawArc(
          Rect.fromCircle(
            center: center,
            radius: radius,
          ),
          start,
          sweepPerDash,
          false,
          paint,
        );
      }
    }

    drawDashedRing(
      maxRadius * 0.95,
      progress * 2 * pi,
      3,
      0.5,
      const Color(0xFF00BFFF)
          .withOpacity(0.85),
      3,
    );

    drawDashedRing(
      maxRadius * 0.78,
      -progress * 2 * pi * 1.4,
      6,
      0.35,
      const Color(0xFF4A00E0)
          .withOpacity(0.8),
      2.5,
    );

    drawDashedRing(
      maxRadius * 0.6,
      progress * 2 * pi * 0.8,
      10,
      0.25,
      const Color(0xFF00BFFF)
          .withOpacity(0.5),
      1.5,
    );

    final glowPaint = Paint()
      ..color = const Color(
        0xFF00BFFF,
      ).withOpacity(0.08)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      center,
      maxRadius * 0.5,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _RingPainter
        oldDelegate,
  ) {
    return oldDelegate.progress !=
        progress;
  }
}
