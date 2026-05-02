import 'package:flutter/material.dart';
import '../services/health_analyzer.dart';
import '../app_theme.dart';

class WarningCard extends StatelessWidget {
  final HealthWarning warning;
  const WarningCard({super.key, required this.warning});

  Color get _color {
    switch (warning.level) {
      case WarningLevel.high:     return AppTheme.danger;
      case WarningLevel.moderate: return AppTheme.moderate;
      case WarningLevel.info:     return AppTheme.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.3), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              warning.level == WarningLevel.high
                  ? Icons.warning_rounded
                  : warning.level == WarningLevel.moderate
                  ? Icons.info_rounded
                  : Icons.lightbulb_rounded,
              color: _color, size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(warning.title,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _color)),
                const SizedBox(height: 3),
                Text(warning.message,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}