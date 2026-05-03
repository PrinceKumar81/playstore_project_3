import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';

/// USDA FoodData Central API Service
/// API Key: GjjV7n3X5ad4RqhXeVRHSUXaWX9B1ZY6qLDTthRc
/// Docs: https://fdc.nal.usda.gov/api-guide
/// Rate limit: 1,000 requests/hour (free tier)
class USDAFoodService {
  static const _baseUrl = 'https://api.nal.usda.gov/fdc/v1';
  static const _apiKey = 'GjjV7n3X5ad4RqhXeVRHSUXaWX9B1ZY6qLDTthRc';

  static const _headers = {
    'Content-Type': 'application/json',
    'User-Agent': 'SmartCalorieApp/1.0',
  };

  // ── Search foods by name ──────────────────────────────────────────
  /// Searches USDA FoodData Central for foods matching [query].
  /// Returns up to [pageSize] results from the branded + foundation data types.
  static Future<List<FoodItem>> searchByName(
      String query, {
        int pageSize = 15,
        int pageNumber = 1,
      }) async {
    if (query.trim().isEmpty) return [];

    try {
      final url = Uri.parse('$_baseUrl/foods/search?api_key=$_apiKey');
      final body = jsonEncode({
        'query': query,
        'dataType': ['Branded', 'Foundation', 'SR Legacy'],
        'pageSize': pageSize,
        'pageNumber': pageNumber,
        'sortBy': 'dataType.keyword',
        'sortOrder': 'asc',
      });

      final res = await http
          .post(url, headers: _headers, body: body)
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      final foods = (data['foods'] as List?) ?? [];
      return foods
          .map((f) => _parseSearchResult(f))
          .where((f) => f != null)
          .cast<FoodItem>()
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ── Fetch full details by FDC ID ──────────────────────────────────
  /// Fetches complete nutrient data for a food by its FDC ID.
  static Future<FoodItem?> fetchById(int fdcId) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/food/$fdcId?format=abridged&api_key=$_apiKey',
      );
      final res = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      return _parseDetailResult(data);
    } catch (e) {
      return null;
    }
  }

  // ── Parse search result item ──────────────────────────────────────
  static FoodItem? _parseSearchResult(Map<String, dynamic> f) {
    try {
      final name = (f['description'] ?? '').toString().trim();
      if (name.isEmpty) return null;

      final nutrients = (f['foodNutrients'] as List?) ?? [];

      double _n(int nutrientId) {
        try {
          final match = nutrients.firstWhere(
                (n) => n['nutrientId'] == nutrientId,
            orElse: () => null,
          );
          return match == null
              ? 0.0
              : (match['value'] as num?)?.toDouble() ?? 0.0;
        } catch (_) {
          return 0.0;
        }
      }

      // USDA nutrient IDs:
      // 1008 = Energy (kcal), 1003 = Protein, 1005 = Carbohydrates
      // 1004 = Total Fat, 1079 = Fiber, 2000 = Sugars
      // 1093 = Sodium (mg), 1258 = Saturated Fat
      final calories = _n(1008);
      final protein  = _n(1003);
      final carbs    = _n(1005);
      final fat      = _n(1004);
      final fiber    = _n(1079);
      final sugar    = _n(2000);
      final sodium   = _n(1093);

      final brand = f['brandOwner']?.toString() ??
          f['brandName']?.toString();
      final fdcId = f['fdcId'] as int?;

      return FoodItem(
        id: 'usda_${fdcId ?? name.hashCode}',
        name: _formatName(name),
        category: _inferCategory(f['foodCategory']?.toString() ?? name),
        caloriesPer100g: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        fiber: fiber,
        sugar: sugar,
        sodium: sodium,
        servingSize: _parseServing(f),
        servingUnit: 'g',
        servingLabel: f['servingSize'] != null
            ? '${f['servingSize']}${f['servingSizeUnit'] ?? 'g'}'
            : '100g',
        brand: brand,
        ingredients: _parseIngredients(f['ingredients']?.toString()),
        icon: _iconForCategory(f['foodCategory']?.toString() ?? name),
        barcode: f['gtinUpc']?.toString(),
        imageUrl: null,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Parse full detail result ──────────────────────────────────────
  static FoodItem? _parseDetailResult(Map<String, dynamic> f) {
    try {
      final name = (f['description'] ?? '').toString().trim();
      if (name.isEmpty) return null;

      final nutrients = (f['foodNutrients'] as List?) ?? [];

      double _n(int id) {
        try {
          final match = nutrients.firstWhere(
                (n) => (n['nutrient']?['id'] ?? n['nutrientId']) == id,
            orElse: () => null,
          );
          return match == null
              ? 0.0
              : ((match['amount'] ?? match['value']) as num?)?.toDouble() ?? 0.0;
        } catch (_) {
          return 0.0;
        }
      }

      final brand = f['brandOwner']?.toString() ??
          f['brandName']?.toString();
      final fdcId = f['fdcId'] as int?;

      return FoodItem(
        id: 'usda_${fdcId ?? name.hashCode}',
        name: _formatName(name),
        category: _inferCategory(
          f['foodCategory']?['description']?.toString() ?? name,
        ),
        caloriesPer100g: _n(1008),
        protein: _n(1003),
        carbs: _n(1005),
        fat: _n(1004),
        fiber: _n(1079),
        sugar: _n(2000),
        sodium: _n(1093),
        servingSize: _parseServing(f),
        servingUnit: 'g',
        servingLabel: f['servingSize'] != null
            ? '${f['servingSize']}${f['servingSizeUnit'] ?? 'g'}'
            : '100g',
        brand: brand,
        ingredients: _parseIngredients(
          f['ingredients']?.toString() ??
              f['inputFoods']?.toString(),
        ),
        icon: _iconForCategory(
          f['foodCategory']?['description']?.toString() ?? name,
        ),
        barcode: f['gtinUpc']?.toString(),
        imageUrl: null,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────

  static double _parseServing(Map<String, dynamic> f) {
    final s = f['servingSize'];
    if (s is num) return s.toDouble();
    return 100.0;
  }

  static List<String>? _parseIngredients(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return raw
        .split(RegExp(r'[,;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length > 1)
        .toList();
  }

  /// Capitalizes first letter of each word, lowercases rest.
  static String _formatName(String name) {
    return name
        .toLowerCase()
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static String _inferCategory(String raw) {
    final r = raw.toLowerCase();
    if (r.contains('cereal') || r.contains('grain') || r.contains('bread') ||
        r.contains('flour') || r.contains('pasta') || r.contains('rice'))
      return 'Grains & Cereals';
    if (r.contains('dairy') || r.contains('milk') || r.contains('cheese') ||
        r.contains('yogurt') || r.contains('butter'))
      return 'Dairy';
    if (r.contains('meat') || r.contains('chicken') || r.contains('beef') ||
        r.contains('pork') || r.contains('fish') || r.contains('seafood') ||
        r.contains('poultry'))
      return 'Meat & Seafood';
    if (r.contains('vegetable') || r.contains('veggie') || r.contains('salad') ||
        r.contains('spinach') || r.contains('broccoli'))
      return 'Vegetables';
    if (r.contains('fruit') || r.contains('apple') || r.contains('mango') ||
        r.contains('banana') || r.contains('berry'))
      return 'Fruits';
    if (r.contains('snack') || r.contains('chip') || r.contains('cookie') ||
        r.contains('cracker') || r.contains('candy'))
      return 'Snacks';
    if (r.contains('beverage') || r.contains('drink') || r.contains('juice') ||
        r.contains('soda') || r.contains('water') || r.contains('tea') ||
        r.contains('coffee'))
      return 'Beverages';
    if (r.contains('sauce') || r.contains('condiment') || r.contains('dressing') ||
        r.contains('oil') || r.contains('vinegar'))
      return 'Condiments';
    if (r.contains('spice') || r.contains('herb') || r.contains('seasoning'))
      return 'Spices';
    if (r.contains('nut') || r.contains('seed') || r.contains('legume') ||
        r.contains('bean') || r.contains('lentil'))
      return 'Nuts & Legumes';
    if (r.contains('sweet') || r.contains('dessert') || r.contains('cake') ||
        r.contains('chocolate') || r.contains('sugar'))
      return 'Sweets & Desserts';
    return 'Food';
  }

  static String _iconForCategory(String raw) {
    final r = raw.toLowerCase();
    if (r.contains('grain') || r.contains('bread') || r.contains('rice') ||
        r.contains('cereal') || r.contains('pasta'))
      return '🌾';
    if (r.contains('dairy') || r.contains('milk') || r.contains('cheese'))
      return '🥛';
    if (r.contains('meat') || r.contains('chicken') || r.contains('beef'))
      return '🥩';
    if (r.contains('fish') || r.contains('seafood'))
      return '🐟';
    if (r.contains('vegetable') || r.contains('veggie'))
      return '🥦';
    if (r.contains('fruit'))
      return '🍎';
    if (r.contains('snack') || r.contains('chip'))
      return '🍟';
    if (r.contains('beverage') || r.contains('drink') || r.contains('juice'))
      return '🥤';
    if (r.contains('sauce') || r.contains('condiment'))
      return '🫙';
    if (r.contains('nut') || r.contains('seed'))
      return '🥜';
    if (r.contains('sweet') || r.contains('dessert') || r.contains('candy'))
      return '🍬';
    if (r.contains('egg'))
      return '🥚';
    if (r.contains('oil') || r.contains('fat'))
      return '🫒';
    return '🍽️';
  }
}