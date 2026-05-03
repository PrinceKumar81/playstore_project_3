import 'dart:async';
import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../services/indian_food_service.dart';
import '../services/open_food_facts_service.dart';
import '../app_theme.dart';
import 'food_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final bool indiaOnly;
  final String? initialQuery; // ← ADDED: accepts pre-filled query
  const SearchScreen({
    super.key,
    this.indiaOnly = false,
    this.initialQuery,       // ← ADDED
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  late TabController _tabCtrl;

  List<FoodItem> _indianResults = [];
  List<FoodItem> _packagedResults = [];
  bool _loadingIndian = false;
  bool _loadingPackaged = false;
  String _lastQuery = '';
  String _selectedCategory = 'All';
  bool _sortByCalories = false;

  Timer? _debounce;
  List<String> _searchHistory = [];
  static const _historyMax = 5;

  static const _categories = [
    'All', 'Breakfast', 'Dal', 'Rice', 'Snack',
    'Sweets', 'Drink', 'Bread', 'Curry',
  ];

  // ── Lifecycle ─────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(_onTabChanged);

    // Pre-fill initialQuery if provided
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _ctrl.text = widget.initialQuery!;
      _lastQuery = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadIndian(widget.initialQuery!);
        _searchPackaged(widget.initialQuery!);
      });
    } else {
      _loadIndian('');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    _tabCtrl.removeListener(_onTabChanged);
    _tabCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabCtrl.indexIsChanging) return;
    if (_tabCtrl.index == 1 && _lastQuery.isNotEmpty) {
      _searchPackaged(_lastQuery);
    }
  }

  // ── Search Logic ───────────────────────────────────────────────

  void _onChanged(String q) {
    setState(() => _lastQuery = q);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadIndian(q);
      if (!widget.indiaOnly && _tabCtrl.index == 1) _searchPackaged(q);
    });
  }

  void _submitSearch(String q) {
    if (q.trim().isEmpty) return;
    _addHistory(q.trim());
    _loadIndian(q);
    if (!widget.indiaOnly) _searchPackaged(q);
  }

  Future<void> _loadIndian(String q) async {
    if (mounted) setState(() => _loadingIndian = true);
    List<FoodItem> r = q.isEmpty
        ? await IndianFoodService.getAll()
        : await IndianFoodService.search(q);

    if (_selectedCategory != 'All') {
      r = r.where((f) =>
          f.category.toLowerCase().contains(_selectedCategory.toLowerCase())
      ).toList();
    }

    if (_sortByCalories) {
      r.sort((a, b) => b.caloriesPer100g.compareTo(a.caloriesPer100g));
    } else {
      r.sort((a, b) => a.name.compareTo(b.name));
    }

    if (mounted) setState(() { _indianResults = r; _loadingIndian = false; });
  }

  Future<void> _searchPackaged(String q) async {
    if (q.isEmpty) return;
    if (mounted) setState(() => _loadingPackaged = true);
    final r = await OpenFoodFactsService.searchByName(q);
    if (mounted) setState(() { _packagedResults = r; _loadingPackaged = false; });
  }

  void _addHistory(String q) {
    _searchHistory.remove(q);
    _searchHistory.insert(0, q);
    if (_searchHistory.length > _historyMax) {
      _searchHistory = _searchHistory.sublist(0, _historyMax);
    }
  }

  void _useHistory(String q) {
    _ctrl.text = q;
    _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: q.length));
    _onChanged(q);
    _submitSearch(q);
  }

  void _clearSearch() {
    _ctrl.clear();
    setState(() { _lastQuery = ''; _packagedResults = []; });
    _loadIndian('');
    _focusNode.requestFocus();
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(widget.indiaOnly ? '🇮🇳 Indian Foods' : 'Search Food'),
        actions: [
          // Sort toggle shown only on Indian tab
          if (!widget.indiaOnly)
            AnimatedBuilder(
              animation: _tabCtrl,
              builder: (_, __) => _tabCtrl.index == 0
                  ? _SortButton(
                sortByCalories: _sortByCalories,
                onToggle: () {
                  setState(() => _sortByCalories = !_sortByCalories);
                  _loadIndian(_lastQuery);
                },
              )
                  : const SizedBox.shrink(),
            )
          else
            _SortButton(
              sortByCalories: _sortByCalories,
              onToggle: () {
                setState(() => _sortByCalories = !_sortByCalories);
                _loadIndian(_lastQuery);
              },
            ),
        ],
        bottom: widget.indiaOnly
            ? null
            : TabBar(
          controller: _tabCtrl,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              fontFamily: 'Poppins'),
          tabs: const [
            Tab(text: '🇮🇳 Indian Foods'),
            Tab(text: '📦 Packaged'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Search Bar ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _ctrl,
              focusNode: _focusNode,
              autofocus: widget.initialQuery == null,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: widget.indiaOnly
                    ? 'Search Indian foods...'
                    : 'Search food items...',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppTheme.textMuted),
                suffixIcon: _lastQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.cancel_rounded,
                      color: AppTheme.textMuted, size: 20),
                  onPressed: _clearSearch,
                )
                    : null,
              ),
              onChanged: _onChanged,
              onSubmitted: _submitSearch,
            ),
          ),

          // ── Search History ────────────────────────────────────
          if (_lastQuery.isEmpty && _searchHistory.isNotEmpty)
            _SearchHistory(
              history: _searchHistory,
              onTap: _useHistory,
              onRemove: (q) => setState(() => _searchHistory.remove(q)),
            ),

          // ── Category Chips ────────────────────────────────────
          AnimatedBuilder(
            animation: _tabCtrl,
            builder: (_, __) {
              final showChips = widget.indiaOnly || _tabCtrl.index == 0;
              return showChips
                  ? _CategoryChips(
                selected: _selectedCategory,
                categories: _categories,
                onSelect: (cat) {
                  setState(() => _selectedCategory = cat);
                  _loadIndian(_lastQuery);
                },
              )
                  : const SizedBox.shrink();
            },
          ),

          const SizedBox(height: 4),

          // ── Results ───────────────────────────────────────────
          Expanded(
            child: widget.indiaOnly
                ? _IndianList(
              items: _indianResults,
              loading: _loadingIndian,
              query: _lastQuery,
            )
                : TabBarView(
              controller: _tabCtrl,
              children: [
                _IndianList(
                  items: _indianResults,
                  loading: _loadingIndian,
                  query: _lastQuery,
                ),
                _PackagedList(
                  items: _packagedResults,
                  loading: _loadingPackaged,
                  query: _lastQuery,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search History ────────────────────────────────────────────────

class _SearchHistory extends StatelessWidget {
  final List<String> history;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onRemove;
  const _SearchHistory({
    required this.history,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(children: [
            const Icon(Icons.history_rounded, size: 15, color: AppTheme.textMuted),
            const SizedBox(width: 6),
            const Text('Recent Searches',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
        ...history.map((q) => ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: const Icon(Icons.access_time_rounded,
              size: 16, color: AppTheme.textMuted),
          title: Text(q,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textPrimary)),
          trailing: IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 15, color: AppTheme.textMuted),
            onPressed: () => onRemove(q),
          ),
          onTap: () => onTap(q),
        )),
        const Divider(height: 1, color: AppTheme.divider),
      ],
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
          final isSelected = cat == selected;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.divider,
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textMuted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Sort Button ───────────────────────────────────────────────────

class _SortButton extends StatelessWidget {
  final bool sortByCalories;
  final VoidCallback onToggle;
  const _SortButton({required this.sortByCalories, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.primary.withAlpha(25),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              sortByCalories
                  ? Icons.local_fire_department_rounded
                  : Icons.sort_by_alpha_rounded,
              size: 14,
              color: AppTheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              sortByCalories ? 'Calories' : 'A–Z',
              style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Indian List ───────────────────────────────────────────────────

class _IndianList extends StatelessWidget {
  final List<FoodItem> items;
  final bool loading;
  final String query;
  const _IndianList({
    required this.items,
    required this.loading,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _SkeletonList();
    if (items.isEmpty) {
      return _EmptyState(
        icon: '🍛',
        title: query.isEmpty
            ? 'No Indian foods loaded'
            : 'No results for "$query"',
        subtitle: query.isEmpty
            ? 'Check your assets/data/indian_foods.json'
            : 'Try keywords like "dal", "roti", "rice"',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (_, i) => _FoodTile(food: items[i]),
    );
  }
}

// ── Packaged List ─────────────────────────────────────────────────

class _PackagedList extends StatelessWidget {
  final List<FoodItem> items;
  final bool loading;
  final String query;
  const _PackagedList({
    required this.items,
    required this.loading,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5),
          SizedBox(height: 12),
          Text('Searching Open Food Facts...',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        ]),
      );
    }
    if (query.isEmpty) {
      return const _EmptyState(
        icon: '🔍',
        title: 'Search packaged foods',
        subtitle: 'Type a product name to fetch from\nOpen Food Facts database',
      );
    }
    if (items.isEmpty) {
      return _EmptyState(
        icon: '📦',
        title: 'No products found',
        subtitle: 'Try a different term or scan the barcode instead',
        action: TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.qr_code_scanner_rounded,
              color: AppTheme.primary, size: 18),
          label: const Text('Try Barcode Scan',
              style: TextStyle(color: AppTheme.primary)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (_, i) => _FoodTile(food: items[i]),
    );
  }
}

// ── Food Tile ─────────────────────────────────────────────────────

class _FoodTile extends StatelessWidget {
  final FoodItem food;
  const _FoodTile({required this.food});

  @override
  Widget build(BuildContext context) {
    final healthColor = AppTheme.healthColor(food.healthLabel);

    return Hero(
      tag: 'food_${food.id}',
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FoodDetailScreen(food: food),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              // Icon badge
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: healthColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: healthColor.withAlpha(40), width: 1),
                ),
                child: Center(
                  child: Text(food.icon,
                      style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(food.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(food.category,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMuted)),
                    const SizedBox(height: 6),
                    Row(children: [
                      _NutrientPill(
                          '🔥 ${food.caloriesPer100g.round()} kcal',
                          AppTheme.primary),
                      const SizedBox(width: 6),
                      _NutrientPill(
                          '🥩 ${food.protein.toStringAsFixed(1)}g',
                          const Color(0xFF42A5F5)),
                      const Spacer(),
                      _HealthBadge(food.healthLabel, healthColor),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textMuted.withAlpha(120), size: 20),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NutrientPill extends StatelessWidget {
  final String text;
  final Color color;
  const _NutrientPill(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text,
        style: TextStyle(
            fontSize: 10, color: color, fontWeight: FontWeight.w600)),
  );
}

class _HealthBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _HealthBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withAlpha(50), width: 1),
    ),
    child: Text(label,
        style: TextStyle(
            fontSize: 10, color: color, fontWeight: FontWeight.w700)),
  );
}

// ── Empty State ───────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String icon, title, subtitle;
  final Widget? action;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(icon, style: const TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
                height: 1.5)),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ]),
    ),
  );
}

// ── Skeleton Loader ───────────────────────────────────────────────

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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 7,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            _shimmerBox(52, 52, radius: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerBox(14, 120),
                  const SizedBox(height: 6),
                  _shimmerBox(11, 70),
                  const SizedBox(height: 8),
                  _shimmerBox(10, 160),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _shimmerBox(double h, double w, {double radius = 6}) {
    return Container(
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
            Color(0xFFE8E8E8),
            Color(0xFFF5F5F5),
            Color(0xFFE8E8E8),
          ],
        ),
      ),
    );
  }
}