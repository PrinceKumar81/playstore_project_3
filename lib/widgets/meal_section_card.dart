import 'package:flutter/material.dart';
import '../models/food_log.dart';
import '../providers/calorie_provider.dart';
import '../app_theme.dart';
import 'package:provider/provider.dart';

class MealSectionCard extends StatelessWidget {
  final String title;
  final List<FoodLog> logs;
  const MealSectionCard({super.key, required this.title, required this.logs});

  @override
  Widget build(BuildContext context) {
    final totalCal = logs.fold(0.0, (s, l) => s + l.calories);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Row(children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const Spacer(),
            if (totalCal > 0) Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${totalCal.round()} kcal',
                  style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
            ),
          ]),
          children: logs.isEmpty
              ? [const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No items logged', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          )]
              : logs.map((log) => _LogItem(log: log)).toList(),
        ),
      ),
    );
  }
}

class _LogItem extends StatelessWidget {
  final FoodLog log;
  const _LogItem({required this.log});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    leading: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(child: Text(log.foodItem.icon, style: const TextStyle(fontSize: 22))),
    ),
    title: Text(log.foodItem.name,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    subtitle: Text('${log.quantity.round()}g · ${log.calories.round()} kcal',
        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
    trailing: IconButton(
      icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
      onPressed: () => context.read<CalorieProvider>().removeFood(log.id),
    ),
  );
}