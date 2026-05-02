import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/calorie_provider.dart';
import '../providers/user_provider.dart';
import '../models/food_log.dart';
import '../app_theme.dart';
import 'package:intl/intl.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  List<FoodLog> _weeklyLogs = [];

  @override
  void initState() {
    super.initState();
    _loadWeekly();
  }

  Future<void> _loadWeekly() async {
    final logs = await context.read<CalorieProvider>().getWeeklyLogs();
    if (mounted) setState(() => _weeklyLogs = logs);
  }

  Map<String, double> get _weeklyData {
    final data = <String, double>{};
    for (int i = 6; i >= 0; i--) {
      final day = DateTime.now().subtract(Duration(days: i));
      final key = DateFormat('EEE').format(day);
      data[key] = _weeklyLogs
          .where((l) =>
      l.loggedAt.year == day.year &&
          l.loggedAt.month == day.month &&
          l.loggedAt.day == day.day)
          .fold(0.0, (s, l) => s + l.calories);
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final calories = context.watch<CalorieProvider>();
    final user = context.watch<UserProvider>();
    final goal = user.dailyGoal.toDouble();
    final weekly = _weeklyData;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('Weekly Tracker')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bar Chart
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('7-Day Calorie History',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Goal: ${goal.round()} kcal/day',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 180,
                    child: BarChart(BarChartData(
                      maxY: (goal * 1.3),
                      barGroups: weekly.entries.toList().asMap().entries.map((e) {
                        final i = e.key;
                        final cal = e.value.value;
                        final color = cal > goal ? AppTheme.danger
                            : cal > goal * 0.85 ? AppTheme.moderate
                            : AppTheme.primary;
                        return BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: cal,
                            color: color,
                            width: 20,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true, toY: goal * 1.3,
                              color: AppTheme.bg,
                            ),
                          ),
                        ]);
                      }).toList(),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) => Text(
                            weekly.keys.toList()[v.toInt()],
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        )),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        drawHorizontalLine: true,
                        drawVerticalLine: false,
                        horizontalInterval: goal / 4,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: AppTheme.divider, strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      extraLinesData: ExtraLinesData(horizontalLines: [
                        HorizontalLine(y: goal, color: AppTheme.primary.withOpacity(0.4),
                            strokeWidth: 1.5, dashArray: [6, 4]),
                      ]),
                    )),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Today Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Today's Breakdown",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 16),
                  _MealRow('🌅 Breakfast', calories.breakfast.fold(0.0, (s, l) => s + l.calories)),
                  _MealRow('☀️ Lunch',     calories.lunch.fold(0.0, (s, l) => s + l.calories)),
                  _MealRow('🌙 Dinner',    calories.dinner.fold(0.0, (s, l) => s + l.calories)),
                  _MealRow('🍎 Snacks',    calories.snacks.fold(0.0, (s, l) => s + l.calories)),
                  const Divider(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('${calories.totalCalories.round()} / ${goal.round()} kcal',
                        style: const TextStyle(fontWeight: FontWeight.w700,
                            color: AppTheme.primary, fontSize: 14)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  final String label;
  final double cals;
  const _MealRow(this.label, this.cals);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 13)),
      const Spacer(),
      Text('${cals.round()} kcal',
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary, fontSize: 13)),
    ]),
  );
}