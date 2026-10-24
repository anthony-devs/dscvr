import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Small reading-progress indicator shown in the corner of material cards.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 16,
    required this.color,
    required this.track,
  });

  final double value;
  final double size;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
    return Semantics(
      label: value >= 1 ? 'Finished' : '$pct percent read',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _RingPainter(value.clamp(0, 1), color, track)),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color, this.track);
  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.2;
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(r, 0, math.pi * 2, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = track);
    if (value <= 0) return;
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * value, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = value >= 1 ? StrokeCap.butt : StrokeCap.round
          ..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}
