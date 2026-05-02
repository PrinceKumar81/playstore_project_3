import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/calorie_provider.dart';
import '../providers/user_provider.dart';
import '../models/food_log.dart';
import '../app_theme.dart';

class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final calories = context.watch<CalorieProvider>();
    final user = context.watch<UserProvider>();
    final goal = user.dailyGoal.toDouble();
    final remaining = (goal - calories.totalCalories).clamp(0, goal);
    final today = DateFormat('EEEE, d MMM').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Food Log'),
        // ✅ FIX: AppBar has no 'subtitle' param — use 'bottom' with PreferredSize
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              today,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ),
        ),
      ),
      body: calories.loading
          ? const Center(
          child: CircularProgressIndicator(color: AppTheme.primary))
          : calories.logs.isEmpty
          ? _EmptyLog()
          : CustomScrollView(
        slivers: [
          // ── Summary Header ──────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, Color(0xFF00695C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Today\'s Total',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          '${calories.totalCalories.round()} kcal',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins'),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${remaining.round()} kcal remaining',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Macros
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _MacroBadge(
                          'P',
                          '${calories.totalProtein.toStringAsFixed(1)}g',
                          const Color(0xFF90CAF9)),
                      const SizedBox(height: 6),
                      _MacroBadge(
                          'C',
                          '${calories.totalCarbs.toStringAsFixed(1)}g',
                          const Color(0xFFFFE082)),
                      const SizedBox(height: 6),
                      _MacroBadge(
                          'F',
                          '${calories.totalFat.toStringAsFixed(1)}g',
                          const Color(0xFFEF9A9A)),
                    ],
                  ),
                ]),
              ),
            ),
          ),

          // ── Meal Sections ───────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _MealSection(
                  title: '🌅 Breakfast',
                  logs: calories.breakfast,
                  color: const Color(0xFFFFB74D),
                ),
                _MealSection(
                  title: '☀️ Lunch',
                  logs: calories.lunch,
                  color: const Color(0xFF4CAF50),
                ),
                _MealSection(
                  title: '🌙 Dinner',
                  logs: calories.dinner,
                  color: const Color(0xFF7E57C2),
                ),
                _MealSection(
                  title: '🍎 Snacks',
                  logs: calories.snacks,
                  color: const Color(0xFFEF5350),
                ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Meal Section ──────────────────────────────────────────────────────────────

class _MealSection extends StatelessWidget {
  final String title;
  final List<FoodLog> logs;
  final Color color;

  const _MealSection({
    required this.title,
    required this.logs,
    required this.color,
  });

  double get _total => logs.fold(0.0, (s, l) => s + l.calories);

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${_total.round()} kcal',
                    style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),

          // Log Items
          ...logs.map((log) => _LogRow(log: log, accentColor: color)),
        ],
      ),
    );
  }
}

// ── Individual Log Row ────────────────────────────────────────────────────────

class _LogRow extends StatelessWidget {
  final FoodLog log;
  final Color accentColor;

  const _LogRow({required this.log, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final food = log.foodItem;
    final healthColor = AppTheme.healthColor(food.healthLabel);
    final time = DateFormat('h:mm a').format(log.loggedAt);

    return Dismissible(
      key: Key(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.danger.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_rounded, color: AppTheme.danger),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Remove Item?'),
            content: Text('Remove ${food.name} from your log?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove',
                    style: TextStyle(color: AppTheme.danger)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        context.read<CalorieProvider>().removeFood(log.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${food.name} removed'),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          // Food Icon
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child:
              Text(food.icon, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 12),

          // Name + Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(food.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  Text('${log.quantity.round()} ${food.servingUnit}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(width: 8),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: const BoxDecoration(
                      color: AppTheme.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(time,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMuted)),
                ]),
              ],
            ),
          ),

          // Calories + Health Label
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${log.calories.round()}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.primary,
                    fontFamily: 'Poppins')),
            const Text('kcal',
                style:
                TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            const SizedBox(height: 4),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: healthColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(food.healthLabel,
                  style: TextStyle(
                      fontSize: 10,
                      color: healthColor,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyLog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Text('🍽️', style: TextStyle(fontSize: 48)),
            ),
          ),
          const SizedBox(height: 20),
          const Text('No food logged yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text('Tap "+ Add Food" to start tracking',
              style:
              TextStyle(fontSize: 14, color: AppTheme.textMuted)),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

// ── Macro Badge ───────────────────────────────────────────────────────────────

class _MacroBadge extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MacroBadge(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
            color: color.withOpacity(0.25), shape: BoxShape.circle),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ),
      ),
      const SizedBox(width: 5),
      Text(value,
          style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ],
  );
}