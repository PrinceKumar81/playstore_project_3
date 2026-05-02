import 'package:flutter/material.dart';
import '../app_theme.dart';

class AnimatedCalorieCounter extends StatefulWidget {
  final double consumed;
  final double goal;
  const AnimatedCalorieCounter({super.key, required this.consumed, required this.goal});

  @override
  State<AnimatedCalorieCounter> createState() => _AnimatedCalorieCounterState();
}

class _AnimatedCalorieCounterState extends State<AnimatedCalorieCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progressAnim;
  late Animation<double> _numberAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    final progress = (widget.consumed / widget.goal).clamp(0.0, 1.0);
    _progressAnim = Tween<double>(begin: 0, end: progress)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _numberAnim = Tween<double>(begin: 0, end: widget.consumed)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(AnimatedCalorieCounter old) {
    super.didUpdateWidget(old);
    if (old.consumed != widget.consumed) {
      final progress = (widget.consumed / widget.goal).clamp(0.0, 1.0);
      _progressAnim = Tween<double>(begin: _progressAnim.value, end: progress)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _numberAnim = Tween<double>(begin: _numberAnim.value, end: widget.consumed)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Color get _trackColor {
    final ratio = widget.consumed / widget.goal;
    if (ratio > 1.0) return AppTheme.danger;
    if (ratio > 0.85) return AppTheme.moderate;
    return AppTheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (widget.goal - widget.consumed).clamp(0, widget.goal);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CalStat(
                label: 'Consumed',
                value: '${_numberAnim.value.round()}',
                unit: 'kcal',
                color: _trackColor,
              ),
              _CalStat(
                label: 'Goal',
                value: '${widget.goal.round()}',
                unit: 'kcal',
                color: AppTheme.textMuted,
              ),
              _CalStat(
                label: 'Remaining',
                value: '${remaining.round()}',
                unit: 'kcal',
                color: remaining == 0 ? AppTheme.danger : AppTheme.healthy,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progressAnim.value,
              minHeight: 12,
              backgroundColor: _trackColor.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(_trackColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_progressAnim.value * 100).round()}% of daily goal',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _CalStat extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  const _CalStat({required this.label, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      const SizedBox(height: 2),
      RichText(text: TextSpan(
        children: [
          TextSpan(text: value, style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w700,
            color: color, fontFamily: 'Poppins',
          )),
          TextSpan(text: ' $unit', style: TextStyle(
            fontSize: 11, color: color.withOpacity(0.7), fontFamily: 'Poppins',
          )),
        ],
      )),
    ],
  );
}