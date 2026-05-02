import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/calorie_provider.dart';
import '../providers/user_provider.dart';
import '../app_theme.dart';
import '../widgets/animated_calorie_counter.dart';
import '../widgets/meal_section_card.dart';
import 'search_screen.dart';
import 'scanner_screen.dart';
import 'tracker_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: IndexedStack(
        index: _tab,
        children: const [
          _DashboardTab(),
          TrackerScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.primary.withOpacity(0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Tracker'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Food', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    final calories = context.watch<CalorieProvider>();
    final user = context.watch<UserProvider>();
    final goal = user.dailyGoal.toDouble();
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Good Morning' : now.hour < 17 ? 'Good Afternoon' : 'Good Evening';

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: AppTheme.primary,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, Color(0xFF00695C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$greeting 👋',
                                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
                              Text(user.profile.name,
                                  style: const TextStyle(color: Colors.white,
                                      fontSize: 22, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const ScannerScreen())),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 26),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _GoalChip(goal: user.profile.goal),
                    ],
                  ),
                ),
              ),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0),
            child: Container(
              height: 20,
              decoration: const BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Calorie Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: AppTheme.primary.withOpacity(0.08),
                          blurRadius: 20, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Today's Intake",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 16),
                      AnimatedCalorieCounter(
                        consumed: calories.totalCalories,
                        goal: goal,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Macro Cards
                Row(children: [
                  _MacroCard('Protein', calories.totalProtein, 50, 'g', const Color(0xFF42A5F5)),
                  const SizedBox(width: 10),
                  _MacroCard('Carbs', calories.totalCarbs, 250, 'g', const Color(0xFFFFCA28)),
                  const SizedBox(width: 10),
                  _MacroCard('Fat', calories.totalFat, 65, 'g', const Color(0xFFEF5350)),
                ]),
                const SizedBox(height: 20),

                // Quick Actions
                Row(children: [
                  _QuickAction(
                    icon: Icons.search_rounded,
                    label: 'Search\nFood',
                    color: AppTheme.primary,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SearchScreen())),
                  ),
                  const SizedBox(width: 12),
                  _QuickAction(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Scan\nBarcode',
                    color: const Color(0xFF7C4DFF),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ScannerScreen())),
                  ),
                  const SizedBox(width: 12),
                  _QuickAction(
                    icon: Icons.restaurant_menu_rounded,
                    label: 'Indian\nFoods',
                    color: const Color(0xFFFF7043),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SearchScreen(indiaOnly: true))),
                  ),
                ]),
                const SizedBox(height: 20),

                // Meals
                MealSectionCard(title: '🌅 Breakfast', logs: calories.breakfast),
                MealSectionCard(title: '☀️ Lunch',     logs: calories.lunch),
                MealSectionCard(title: '🌙 Dinner',    logs: calories.dinner),
                MealSectionCard(title: '🍎 Snacks',    logs: calories.snacks),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GoalChip extends StatelessWidget {
  final String goal;
  const _GoalChip({required this.goal});

  @override
  Widget build(BuildContext context) {
    final label = goal == 'loss' ? '🎯 Weight Loss' : goal == 'gain' ? '💪 Weight Gain' : '⚖️ Maintain';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String label;
  final double value, max;
  final String unit;
  final Color color;
  const _MacroCard(this.label, this.value, this.max, this.unit, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('${value.toStringAsFixed(1)}$unit',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color, fontFamily: 'Poppins')),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (value / max).clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ]),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600, height: 1.3)),
        ]),
      ),
    ),
  );
}