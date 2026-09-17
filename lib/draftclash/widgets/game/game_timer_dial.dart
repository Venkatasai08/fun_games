// lib/draftclash/widgets/game/game_timer_dial.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

const _green = Color(0xFF3ADE80);
const _amber = Color(0xFFF4A11D);
const _red   = Color(0xFFE8445A);
const _bdr   = Color(0xFF1E1B38);

class GameTimerDial extends StatelessWidget {
  final int seconds;
  const GameTimerDial({super.key, required this.seconds});

  Color get _color {
    if (seconds > 9) return _green;
    if (seconds > 4) return _amber;
    return _red;
  }

  @override
  Widget build(BuildContext context) {
    final progress = (seconds / 15).clamp(0.0, 1.0);
    return SizedBox(
      width: 68, height: 68,
      child: Stack(fit: StackFit.expand, children: [
        const CustomPaint(painter: ArcPainter(1.0, _bdr, 5)),
        CustomPaint(painter: ArcPainter(progress, _color, 5)),
        Center(child: Text('$seconds', style: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w900,
          color: _color, height: 1,
        ))),
      ]),
    );
  }
}

class ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double sw;
  const ArcPainter(this.progress, this.color, this.sw);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color ..strokeWidth = sw
      ..style = PaintingStyle.stroke ..strokeCap = StrokeCap.round;
    final c = Offset(size.width / 2, size.height / 2);
    final r = (size.width - sw) / 2;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2, 2 * math.pi * progress, false, paint,
    );
  }

  @override
  bool shouldRepaint(ArcPainter o) =>
      o.progress != progress || o.color != color;
}
