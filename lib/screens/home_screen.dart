import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/calorie_provider.dart';
import '../providers/user_provider.dart';
import '../app_theme.dart';
import '../widgets/animated_calorie_counter.dart';
import '../widgets/meal_section_card.dart';
import 'search_screen.dart';
import 'food_scanner_screen.dart';
import 'tracker_screen.dart';
import 'profile_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  ROOT SHELL
// ═══════════════════════════════════════════════════════════════
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
          _DashboardTab(), // ← Placeholder for Meals tab (create MealsScreen later)
          ProfileScreen(),
        ],
      ),
      extendBody: true, // ← Allows content behind navbar
      // ── Bottom Nav ─────────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BottomAppBar(
            color: AppTheme.surface,
            elevation: 0,
            height: 70,
            padding: EdgeInsets.zero,
            notchMargin: 8,
            shape: const CircularNotchedRectangle(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  active: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                _NavItem(
                  icon: Icons.trending_up_outlined,
                  activeIcon: Icons.trending_up_rounded,
                  label: 'Tracker',
                  active: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
                const SizedBox(width: 70), // ← Space for FAB
                _NavItem(
                  icon: Icons.restaurant_menu_outlined,
                  activeIcon: Icons.restaurant_menu_rounded,
                  label: 'Meals',
                  active: _tab == 2,
                  onTap: () => setState(() => _tab = 2),
                ),
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profile',
                  active: _tab == 3,
                  onTap: () => setState(() => _tab = 3),
                ),
              ],
            ),
          ),
        ),
      ),
      // ── Center FAB (Scan) ──────────────────────────────────────
      floatingActionButton: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primary, Color(0xFF26C6DA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.4),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FoodScannerScreen()),
            ),
            borderRadius: BorderRadius.circular(20),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

// ── Custom nav item ────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(active ? 8 : 6),
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.primary.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                active ? activeIcon : icon,
                color: active ? AppTheme.primary : AppTheme.textMuted,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? AppTheme.primary : AppTheme.textMuted,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
//  DASHBOARD TAB
// ═══════════════════════════════════════════════════════════════
class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    final calories = context.watch<CalorieProvider>();
    final user = context.watch<UserProvider>();
    final goal = user.dailyGoal.toDouble();
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Hero Header ─────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          stretch: true,
          backgroundColor: AppTheme.primary,
          flexibleSpace: FlexibleSpaceBar(
            stretchModes: const [StretchMode.zoomBackground],
            background: _HeroHeader(
              greeting: greeting,
              name: user.profile.name,
              goal: user.profile.goal,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0),
            child: Container(
              height: 24,
              decoration: const BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
            ),
          ),
        ),

        // ── Body ────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Calorie Card
                _CalorieCard(
                  consumed: calories.totalCalories,
                  goal: goal,
                ),
                const SizedBox(height: 14),

                // Macro Strip
                _MacroStrip(
                  protein: calories.totalProtein,
                  carbs: calories.totalCarbs,
                  fat: calories.totalFat,
                ),
                const SizedBox(height: 20),

                // Section label
                _SectionLabel(
                  icon: Icons.bolt_rounded,
                  title: 'Quick Actions',
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 12),

                // Quick Actions — NOW 4 tiles
                _QuickActionsGrid(goal: user.profile.goal),
                const SizedBox(height: 22),

                // Today's tip banner
                _TipBanner(
                  consumed: calories.totalCalories,
                  goal: goal,
                ),
                const SizedBox(height: 20),

                // Section label
                _SectionLabel(
                  icon: Icons.restaurant_menu_rounded,
                  title: "Today's Meals",
                  color: const Color(0xFFFF7043),
                ),
                const SizedBox(height: 12),

                // Meals
                MealSectionCard(
                    title: '🌅 Breakfast', logs: calories.breakfast),
                MealSectionCard(title: '☀️  Lunch', logs: calories.lunch),
                MealSectionCard(title: '🌙 Dinner', logs: calories.dinner),
                MealSectionCard(title: '🍎 Snacks', logs: calories.snacks),

                const SizedBox(height: 110),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Hero Header widget ─────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  final String greeting, name, goal;
  const _HeroHeader(
      {required this.greeting, required this.name, required this.goal});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00897B), Color(0xFF004D40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -30,
            right: -20,
            child: _Circle(size: 160, opacity: 0.07),
          ),
          Positioned(
            top: 40,
            right: 60,
            child: _Circle(size: 80, opacity: 0.05),
          ),
          Positioned(
            bottom: 40,
            left: -30,
            child: _Circle(size: 120, opacity: 0.06),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Text('👋 ',
                                  style: TextStyle(fontSize: 16)),
                              Text(greeting,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  )),
                            ]),
                            const SizedBox(height: 3),
                            Text(name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Poppins',
                                  letterSpacing: -0.3,
                                )),
                            const SizedBox(height: 8),
                            _GoalPill(goal: goal),
                          ],
                        ),
                      ),
                      // Avatar
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.3), width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Date chip
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border:
                      Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.calendar_today_rounded,
                          color: Colors.white70, size: 13),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(DateTime.now()),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _Circle extends StatelessWidget {
  final double size, opacity;
  const _Circle({required this.size, required this.opacity});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );
}

class _GoalPill extends StatelessWidget {
  final String goal;
  const _GoalPill({required this.goal});

  @override
  Widget build(BuildContext context) {
    final label = goal == 'loss'
        ? '🎯 Weight Loss'
        : goal == 'gain'
        ? '💪 Weight Gain'
        : '⚖️ Maintain';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}

// ── Calorie Card ───────────────────────────────────────────────
class _CalorieCard extends StatelessWidget {
  final double consumed, goal;
  const _CalorieCard({required this.consumed, required this.goal});

  @override
  Widget build(BuildContext context) {
    final ratio = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    final remaining = (goal - consumed).clamp(0, goal);
    final overLimit = consumed > goal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_fire_department_rounded,
                  color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text("Today's Intake",
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const Spacer(),
            if (overLimit)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Over limit',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.danger,
                        fontWeight: FontWeight.w600)),
              ),
          ]),
          const SizedBox(height: 18),
          AnimatedCalorieCounter(consumed: consumed, goal: goal),
          const SizedBox(height: 16),
          // Remaining chip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: overLimit
                  ? AppTheme.danger.withOpacity(0.07)
                  : AppTheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: overLimit
                    ? AppTheme.danger.withOpacity(0.2)
                    : AppTheme.primary.withOpacity(0.15),
              ),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(
                overLimit
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline_rounded,
                size: 16,
                color: overLimit ? AppTheme.danger : AppTheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                overLimit
                    ? '${(consumed - goal).round()} kcal over your goal'
                    : '${remaining.round()} kcal remaining today',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: overLimit ? AppTheme.danger : AppTheme.primary,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Macro Strip ────────────────────────────────────────────────
class _MacroStrip extends StatelessWidget {
  final double protein, carbs, fat;
  const _MacroStrip(
      {required this.protein, required this.carbs, required this.fat});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _MacroTile(
          label: 'Protein',
          value: protein,
          max: 50,
          unit: 'g',
          color: const Color(0xFF42A5F5),
          icon: '💪'),
      const SizedBox(width: 10),
      _MacroTile(
          label: 'Carbs',
          value: carbs,
          max: 250,
          unit: 'g',
          color: const Color(0xFFFFCA28),
          icon: '🌾'),
      const SizedBox(width: 10),
      _MacroTile(
          label: 'Fat',
          value: fat,
          max: 65,
          unit: 'g',
          color: const Color(0xFFEF5350),
          icon: '🥑'),
    ]);
  }
}

class _MacroTile extends StatelessWidget {
  final String label, unit, icon;
  final double value, max;
  final Color color;
  const _MacroTile({
    required this.label,
    required this.value,
    required this.max,
    required this.unit,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18), width: 1.2),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const Spacer(),
              Text(
                '${(value / max * 100).clamp(0, 100).round()}%',
                style: TextStyle(
                    fontSize: 10,
                    color: color.withOpacity(0.7),
                    fontWeight: FontWeight.w500),
              ),
            ]),
            const SizedBox(height: 8),
            Text('${value.toStringAsFixed(1)}$unit',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFamily: 'Poppins',
                )),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color.withOpacity(0.75),
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
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

// ── Quick Actions Grid ─────────────────────────────────────────
class _QuickActionsGrid extends StatelessWidget {
  final String goal;
  const _QuickActionsGrid({required this.goal});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Row 1 — Primary actions
      Row(children: [
        _ActionTile(
          icon: Icons.document_scanner_rounded,
          emoji: '📸',
          label: 'AI Scan',
          subtitle: 'Camera detect',
          gradient: const [Color(0xFF00897B), Color(0xFF26C6DA)],
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const FoodScannerScreen())),
        ),
        const SizedBox(width: 12),
        _ActionTile(
          icon: Icons.qr_code_scanner_rounded,
          emoji: '📦',
          label: 'Barcode Scan',
          subtitle: 'Packaged food',
          gradient: const [Color(0xFF7C4DFF), Color(0xFFB388FF)],
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const FoodScannerScreen(
                      initialMode: ScannerMode.barcode))),
        ),
      ]),
      const SizedBox(height: 12),
      // Row 2 — Secondary actions
      Row(children: [
        _ActionTile(
          icon: Icons.search_rounded,
          emoji: '🔍',
          label: 'Search Food',
          subtitle: 'By name',
          gradient: const [Color(0xFF0288D1), Color(0xFF4FC3F7)],
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SearchScreen())),
        ),
        const SizedBox(width: 12),
        _ActionTile(
          icon: Icons.restaurant_menu_rounded,
          emoji: '🇮🇳',
          label: 'Indian Foods',
          subtitle: 'Offline database',
          gradient: const [Color(0xFFFF7043), Color(0xFFFFCC80)],
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SearchScreen(indiaOnly: true))),
        ),
      ]),
    ]);
  }
}

class _ActionTile extends StatefulWidget {
  final IconData icon;
  final String emoji, label, subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          height: 90,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.first.withOpacity(0.30),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                  child: Text(widget.emoji,
                      style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          fontFamily: 'Poppins',
                        )),
                    const SizedBox(height: 2),
                    Text(widget.subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        )),
                  ],
                )),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white54, size: 14),
          ]),
        ),
      ),
    ),
  );
}

// ── Tip Banner ─────────────────────────────────────────────────
class _TipBanner extends StatelessWidget {
  final double consumed, goal;
  const _TipBanner({required this.consumed, required this.goal});

  @override
  Widget build(BuildContext context) {
    final ratio = goal > 0 ? consumed / goal : 0.0;
    String tip, emoji;
    Color color;

    if (ratio == 0) {
      tip = 'Start logging your meals to track nutrition.';
      emoji = '📝';
      color = AppTheme.info;
    } else if (ratio < 0.3) {
      tip = 'You\'ve only had ${consumed.round()} kcal. Don\'t skip meals!';
      emoji = '⚡';
      color = AppTheme.moderate;
    } else if (ratio < 0.85) {
      tip = 'Great progress! Stay hydrated between meals.';
      emoji = '💧';
      color = AppTheme.healthy;
    } else if (ratio <= 1.0) {
      tip = 'Almost at your goal. Choose light snacks if hungry.';
      emoji = '🎯';
      color = AppTheme.moderate;
    } else {
      tip = 'You\'ve exceeded your goal. Try lighter options next meal.';
      emoji = '⚠️';
      color = AppTheme.danger;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.22), width: 1.2),
      ),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(tip,
                style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.w500,
                    height: 1.4))),
      ]),
    );
  }
}

// ── Section label ──────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _SectionLabel(
      {required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 16),
    ),
    const SizedBox(width: 8),
    Text(title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
          fontFamily: 'Poppins',
        )),
  ]);
}