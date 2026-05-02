import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/food_item.dart';
import '../services/indian_food_service.dart';
import '../services/open_food_facts_service.dart';
import '../app_theme.dart';
import 'food_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final bool indiaOnly;
  const SearchScreen({super.key, this.indiaOnly = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  late TabController _tabCtrl;
  List<FoodItem> _indianResults = [], _packagedResults = [];
  bool _loadingPackaged = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this, initialIndex: widget.indiaOnly ? 0 : 0);
    _loadIndian('');
  }

  @override
  void dispose() { _ctrl.dispose(); _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadIndian(String q) async {
    final r = q.isEmpty
        ? await IndianFoodService.getAll()
        : await IndianFoodService.search(q);
    if (mounted) setState(() => _indianResults = r);
  }

  Future<void> _searchPackaged(String q) async {
    if (q.isEmpty) return;
    setState(() => _loadingPackaged = true);
    final r = await OpenFoodFactsService.searchByName(q);
    if (mounted) setState(() { _packagedResults = r; _loadingPackaged = false; });
  }

  void _onSearch(String q) {
    _lastQuery = q;
    _loadIndian(q);
    if (!widget.indiaOnly && _tabCtrl.index == 1) _searchPackaged(q);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Search Food'),
        bottom: widget.indiaOnly ? null : TabBar(
          controller: _tabCtrl,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.primary,
          tabs: const [Tab(text: '🇮🇳 Indian Foods'), Tab(text: '📦 Packaged')],
          onTap: (i) {
            if (i == 1 && _lastQuery.isNotEmpty) _searchPackaged(_lastQuery);
          },
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search food items...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                  _ctrl.clear(); _onSearch('');
                })
                    : null,
              ),
              onChanged: _onSearch,
            ),
          ),
          Expanded(
            child: widget.indiaOnly
                ? _IndianList(items: _indianResults)
                : TabBarView(
              controller: _tabCtrl,
              children: [
                _IndianList(items: _indianResults),
                _PackagedList(items: _packagedResults, loading: _loadingPackaged, query: _lastQuery),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IndianList extends StatelessWidget {
  final List<FoodItem> items;
  const _IndianList({required this.items});

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    itemCount: items.length,
    itemBuilder: (_, i) => _FoodTile(food: items[i]),
  );
}

class _PackagedList extends StatelessWidget {
  final List<FoodItem> items;
  final bool loading;
  final String query;
  const _PackagedList({required this.items, required this.loading, required this.query});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (query.isEmpty) return const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('🔍', style: TextStyle(fontSize: 48)),
        SizedBox(height: 12),
        Text('Search for packaged food', style: TextStyle(color: AppTheme.textMuted)),
      ]),
    );
    if (items.isEmpty) return const Center(
      child: Text('No packaged food found', style: TextStyle(color: AppTheme.textMuted)),
    );
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (_, i) => _FoodTile(food: items[i]),
    );
  }
}

class _FoodTile extends StatelessWidget {
  final FoodItem food;
  const _FoodTile({required this.food});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.healthColor(food.healthLabel);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: AppTheme.bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(food.icon, style: const TextStyle(fontSize: 26))),
        ),
        title: Text(food.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(food.category, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 3),
            Row(children: [
              Text('${food.caloriesPer100g.round()} kcal/100g',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.primary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(food.healthLabel,
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
              ),
            ]),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FoodDetailScreen(food: food)),
        ),
      ),
    );
  }
}