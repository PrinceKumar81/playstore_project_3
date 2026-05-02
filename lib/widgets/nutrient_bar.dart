import 'package:flutter/material.dart';
import '../app_theme.dart';

class NutrientBar extends StatefulWidget {
  final String label;
  final double value;
  final double max;
  final String unit;
  final Color color;
  const NutrientBar({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.unit,
    required this.color,
  });

  @override
  State<NutrientBar> createState() => _NutrientBarState();
}

class _NutrientBarState extends State<NutrientBar> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _anim = Tween<double>(begin: 0, end: (widget.value / widget.max).clamp(0.0, 1.0))
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textMuted)),
              Text('${widget.value.toStringAsFixed(1)}${widget.unit}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: widget.color)),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _anim.value,
                minHeight: 7,
                backgroundColor: widget.color.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation(widget.color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}