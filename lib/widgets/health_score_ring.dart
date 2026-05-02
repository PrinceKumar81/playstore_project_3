import 'package:flutter/material.dart';
import 'dart:math';
import '../app_theme.dart';

class HealthScoreRing extends StatefulWidget {
  final double score;
  final double size;
  final bool showLabel;
  const HealthScoreRing({super.key, required this.score, this.size = 120, this.showLabel = true});

  @override
  State<HealthScoreRing> createState() => _HealthScoreRingState();
}

class _HealthScoreRingState extends State<HealthScoreRing> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = Tween<double>(begin: 0, end: widget.score / 100)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Color get _color {
    if (widget.score >= 80) return AppTheme.healthy;
    if (widget.score >= 50) return AppTheme.moderate;
    return AppTheme.danger;
  }

  String get _label {
    if (widget.score >= 80) return 'Healthy';
    if (widget.score >= 50) return 'Moderate';
    return 'Avoid';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => SizedBox(
        width: widget.size, height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _RingPainter(progress: _anim.value, color: _color),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(widget.score * _anim.value / widget.score * widget.score).round()}',
                  style: TextStyle(
                    fontSize: widget.size * 0.22,
                    fontWeight: FontWeight.w700,
                    color: _color,
                    fontFamily: 'Poppins',
                  ),
                ),
                if (widget.showLabel)
                  Text(
                    _label,
                    style: TextStyle(
                      fontSize: widget.size * 0.10,
                      color: _color,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final radius = (size.width / 2) - 8;
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round;

    // Track
    paint.color = color.withOpacity(0.12);
    canvas.drawCircle(Offset(cx, cy), radius, paint);

    // Progress
    paint.color = color;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}