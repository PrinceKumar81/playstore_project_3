import 'dart:async';
import 'package:flutter/material.dart';
import '../services/usda_food_service.dart';        // ← CHANGED from nutritionix_service
import '../services/indian_food_service.dart';
import '../models/food_item.dart';
import '../app_theme.dart';
import 'food_detail_screen.dart';

class ScannerSearchScreen extends StatefulWidget {
  const ScannerSearchScreen({super.key});

  @override
  State<ScannerSearchScreen> createState() => _ScannerSearchScreenState();
}

class _ScannerSearchScreenState extends State<ScannerSearchScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  late TabController _tabCtrl;

  List<FoodItem> _indianResults  = [];
  List<FoodItem> _usdaResults    = [];      // ← renamed from _packagedResults
  bool _loadingIndian = false;
  bool _loadingUSDA   = false;
  String _selectedCategory = 'All';
  bool _sortByCalories = false;
  Timer? _debounce;

  static const _categories = [
    'All', 'Breakfast', 'Dal', 'Rice',
    'Snack', 'Sweets', 'Drink', 'Bread', 'Curry',
  ];

  // ── Lifecycle ──────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(_onTabChanged);
    _loadIndian('');
    WidgetsBinding.instance.addPostFrameCallback(
          (_) => _focus.requestFocus(),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _tabCtrl.removeListener(_onTabChanged);
    _tabCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabCtrl.indexIsChanging) return;
    if (_tabCtrl.index == 1 && _ctrl.text.trim().isNotEmpty) {
      _searchUSDA(_ctrl.text.trim());
    }
  }

  // ── Search Logic ───────────────────────────────────────────────

  void _onChanged(String q) {
    setState(() {}); // re-render suffix clear icon
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadIndian(q);
      if (_tabCtrl.index == 1) _searchUSDA(q);
    });
  }

  Future<void> _loadIndian(String q) async {
    if (mounted) setState(() => _loadingIndian = true);
    List<FoodItem> r = q.isEmpty
        ? await IndianFoodService.getAll()
        : await IndianFoodService.search(q);

    // Category filter
    if (_selectedCategory != 'All') {
      r = r.where((f) =>
          f.category.toLowerCase().contains(_selectedCategory.toLowerCase())
      ).toList();
    }

    // Sort
    if (_sortByCalories) {
      r.sort((a, b) => b.caloriesPer100g.compareTo(a.caloriesPer100g));
    } else {
      r.sort((a, b) => a.name.compareTo(b.name));
    }

    if (mounted) setState(() { _indianResults = r; _loadingIndian = false; });
  }

  Future<void> _searchUSDA(String q) async {
    if (q.trim().isEmpty) return;
    if (mounted) setState(() => _loadingUSDA = true);
    final r = await USDAFoodService.searchByName(q.trim());  // ← USDA call
    if (mounted) setState(() { _usdaResults = r; _loadingUSDA = false; });
  }

  void _clearSearch() {
    _ctrl.clear();
    setState(() { _usdaResults = []; });
    _loadIndian('');
    _focus.requestFocus();
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────
          _Header(
            ctrl: _ctrl,
            focus: _focus,
            tabCtrl: _tabCtrl,
            onChanged: _onChanged,
            onClear: _clearSearch,
            onTabTap: (i) {
              if (i == 1 && _ctrl.text.trim().isNotEmpty) {
                _searchUSDA(_ctrl.text.trim());
              }
            },
          ),

          // ── Category Chips (Indian tab only) ────────────────────
          AnimatedBuilder(
            animation: _tabCtrl,
            builder: (_, __) => _tabCtrl.index == 0
                ? _CategoryChips(
              selected: _selectedCategory,
              categories: _categories,
              onSelect: (cat) {
                setState(() => _selectedCategory = cat);
                _loadIndian(_ctrl.text);
              },
            )
                : const SizedBox.shrink(),
          ),

          // ── Sort bar (Indian tab only) ───────────────────────────
          AnimatedBuilder(
            animation: _tabCtrl,
            builder: (_, __) => _tabCtrl.index == 0
                ? _SortBar(
              sortByCalories: _sortByCalories,
              resultCount: _indianResults.length,
              onToggle: () {
                setState(() => _sortByCalories = !_sortByCalories);
                _loadIndian(_ctrl.text);
              },
            )
                : const SizedBox.shrink(),
          ),

          // ── Results ─────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // Indian tab
                _loadingIndian
                    ? const _SkeletonList()
                    : _indianResults.isEmpty
                    ? _EmptyState(
                  icon: '🍛',
                  title: _ctrl.text.isEmpty
                      ? 'No Indian foods loaded'
                      : 'No results for "${_ctrl.text}"',
                  subtitle: 'Try "dal", "roti", "paneer", "rice"',
                )
                    : _FoodList(items: _indianResults),

                // USDA tab
                _loadingUSDA
                    ? const _USDALoading()
                    : _ctrl.text.trim().isEmpty
                    ? const _EmptyState(
                  icon: '🇺🇸',
                  title: 'Search USDA Database',
                  subtitle:
                  'Access 300,000+ foods with full\nnutrition data from USDA FoodData Central',
                )
                    : _usdaResults.isEmpty
                    ? _EmptyState(
                  icon: '🔍',
                  title: 'No results for "${_ctrl.text}"',
                  subtitle:
                  'Try a simpler term or check the spelling',
                )
                    : _USDAResultList(items: _usdaResults),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final TabController tabCtrl;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<int> onTabTap;

  const _Header({
    required this.ctrl,
    required this.focus,
    required this.tabCtrl,
    required this.onChanged,
    required this.onClear,
    required this.onTabTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A2535),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(children: [
            // Top row
            Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Search Food',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 14),

            // Search field
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withAlpha(25)),
              ),
              child: TextField(
                controller: ctrl,
                focusNode: focus,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search e.g. "paneer", "banana", "oats"',
                  hintStyle: const TextStyle(
                      color: Colors.white38, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Colors.white38, size: 20),
                  suffixIcon: ctrl.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.cancel_rounded,
                        color: Colors.white38, size: 18),
                    onPressed: onClear,
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: onChanged,
              ),
            ),
            const SizedBox(height: 12),

            // Tabs
            TabBar(
              controller: tabCtrl,
              labelColor: AppTheme.primary,
              unselectedLabelColor: Colors.white38,
              indicatorColor: AppTheme.primary,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  fontFamily: 'Poppins'),
              tabs: const [
                Tab(text: '🇮🇳 Indian Foods'),
                Tab(text: '🇺🇸 USDA Database'),  // ← updated label
              ],
              onTap: onTabTap,
            ),
            const SizedBox(height: 4),
          ]),
        ),
      ),
    );
  }
}

// ── Category Chips ────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  final String selected;
  final List<String> categories;
  final ValueChanged<String> onSelect;

  const _CategoryChips({
    required this.selected,
    required this.categories,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final isSel = cat == selected;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isSel
                    ? AppTheme.primary
                    : Colors.white.withAlpha(12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSel
                      ? AppTheme.primary
                      : Colors.white.withAlpha(25),
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSel ? Colors.white : Colors.white54,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Sort Bar ──────────────────────────────────────────────────────

class _SortBar extends StatelessWidget {
  final bool sortByCalories;
  final int resultCount;
  final VoidCallback onToggle;

  const _SortBar({
    required this.sortByCalories,
    required this.resultCount,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Row(children: [
        Text(
          '$resultCount items',
          style: const TextStyle(
              fontSize: 11, color: Colors.white38, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primary.withAlpha(60)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                sortByCalories
                    ? Icons.local_fire_department_rounded
                    : Icons.sort_by_alpha_rounded,
                size: 13,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                sortByCalories ? 'By Calories' : 'A–Z',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Food List (Indian) ────────────────────────────────────────────

class _FoodList extends StatelessWidget {
  final List<FoodItem> items;
  const _FoodList({required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: items.length,
      itemBuilder: (_, i) => _SearchResultTile(food: items[i]),
    );
  }
}

// ── USDA Result List ──────────────────────────────────────────────

class _USDAResultList extends StatelessWidget {
  final List<FoodItem> items;
  const _USDAResultList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // USDA source badge
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF002868).withAlpha(60),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF3A5BC7).withAlpha(80)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('🇺🇸', style: TextStyle(fontSize: 11)),
              SizedBox(width: 5),
              Text(
                'USDA FoodData Central',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7EA4F4)),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Text(
            '${items.length} results',
            style: const TextStyle(fontSize: 11, color: Colors.white38),
          ),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          itemCount: items.length,
          itemBuilder: (_, i) => _SearchResultTile(food: items[i]),
        ),
      ),
    ]);
  }
}

// ── Search Result Tile ────────────────────────────────────────────

class _SearchResultTile extends StatelessWidget {
  final FoodItem food;
  const _SearchResultTile({required this.food});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.healthColor(food.healthLabel);

    return Hero(
      tag: 'food_${food.id}',
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => FoodDetailScreen(food: food)),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2535),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(18)),
          ),
          child: Row(children: [
            // Icon
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: color.withAlpha(50)),
              ),
              child: Center(
                child: Text(food.icon,
                    style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 12),

            // Name + category + brand
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins'),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    food.brand != null && food.brand!.isNotEmpty
                        ? '${food.category} · ${food.brand}'
                        : food.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  // Macro pills
                  Row(children: [
                    _MacroPill(
                        '🔥 ${food.caloriesPer100g.round()}', AppTheme.primary),
                    const SizedBox(width: 5),
                    _MacroPill(
                        '🥩 ${food.protein.toStringAsFixed(1)}g',
                        const Color(0xFF42A5F5)),
                    const SizedBox(width: 5),
                    _MacroPill(
                        '🌾 ${food.carbs.toStringAsFixed(1)}g',
                        const Color(0xFFFFCA28)),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Right side: kcal + badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${food.caloriesPer100g.round()}',
                  style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins'),
                ),
                const Text('kcal/100g',
                    style: TextStyle(
                        color: Colors.white38, fontSize: 9)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withAlpha(35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withAlpha(60)),
                  ),
                  child: Text(
                    food.healthLabel,
                    style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withAlpha(40), size: 18),
          ]),
        ),
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final String text;
  final Color color;
  const _MacroPill(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withAlpha(25),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(text,
        style: TextStyle(
            fontSize: 9, color: color, fontWeight: FontWeight.w600)),
  );
}

// ── USDA Loading ──────────────────────────────────────────────────

class _USDALoading extends StatelessWidget {
  const _USDALoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(
            color: AppTheme.primary, strokeWidth: 2.5),
        SizedBox(height: 14),
        Text(
          'Searching USDA Database...',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        SizedBox(height: 4),
        Text(
          '300,000+ foods available',
          style: TextStyle(color: Colors.white24, fontSize: 11),
        ),
      ]),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String icon, title, subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(icon, style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins')),
          const SizedBox(height: 8),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 12, height: 1.5)),
        ]),
      ),
    );
  }
}

// ── Skeleton List ─────────────────────────────────────────────────

class _SkeletonList extends StatefulWidget {
  const _SkeletonList();

  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = Tween<double>(begin: -1, end: 2)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Widget _bone(double h, double w, {double radius = 6}) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        height: h, width: w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            stops: [
              (_anim.value - 0.3).clamp(0.0, 1.0),
              _anim.value.clamp(0.0, 1.0),
              (_anim.value + 0.3).clamp(0.0, 1.0),
            ],
            colors: const [
              Color(0xFF1E2D3D),
              Color(0xFF26384A),
              Color(0xFF1E2D3D),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: 7,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2535),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(15)),
        ),
        child: Row(children: [
          _bone(50, 50, radius: 13),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bone(13, 140),
              const SizedBox(height: 6),
              _bone(10, 80),
              const SizedBox(height: 8),
              _bone(9, 170),
            ],
          )),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _bone(18, 45),
            const SizedBox(height: 6),
            _bone(10, 60, radius: 10),
          ]),
        ]),
      ),
    );
  }
}